#!/usr/bin/env bash
# Pruebas de semaforo.sh y pesado.sh. Sin dependencias: bash, flock y coreutils.
#   bash pesado/probar.sh
# Usan un PSI y un meminfo falsos, así que dan lo mismo en cualquier máquina (y en la CI).
set -u
aqui=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

export SEMAFORO_PSI_DIR="$tmp/psi" SEMAFORO_MEMINFO="$tmp/meminfo"
export PESADO_DIR="$tmp/locks" PESADO_PAUSA=1 PESADO_NICE=0
mkdir -p "$SEMAFORO_PSI_DIR"

# presion <cpu some avg60> <memoria full avg60> <MB disponibles>
presion() {
  printf 'some avg10=0.00 avg60=%s.00 avg300=0.00 total=0\nfull avg10=0.00 avg60=0.00 avg300=0.00 total=0\n' "$1" >"$SEMAFORO_PSI_DIR/cpu"
  printf 'some avg10=0.00 avg60=0.00 avg300=0.00 total=0\nfull avg10=0.00 avg60=%s.00 avg300=0.00 total=0\n' "$2" >"$SEMAFORO_PSI_DIR/memory"
  printf 'MemTotal:       16000000 kB\nMemAvailable:   %s kB\n' "$(($3 * 1024))" >"$SEMAFORO_MEMINFO"
}

fallos=0
prueba() {
  local nombre=$1; shift
  if "$@"; then echo "ok    $nombre"; else echo "FALLO $nombre"; fallos=$((fallos + 1)); fi
}

# --- semáforo -------------------------------------------------------------------------------
verde() { presion 5 0 8000; "$aqui/semaforo.sh"; }
rojo_cpu() { presion 55 0 8000; ! "$aqui/semaforo.sh" 2>/dev/null; }
rojo_memoria() { presion 5 25 8000; ! "$aqui/semaforo.sh" 2>/dev/null; }
rojo_disponible() { presion 5 0 900; ! "$aqui/semaforo.sh" 2>/dev/null; }
en_el_limite_es_verde() { presion 40 10 1536; "$aqui/semaforo.sh"; }
umbral_configurable() { presion 55 0 8000; SEMAFORO_CPU_MAX=60 "$aqui/semaforo.sh"; }
sin_psi_no_adivina() { SEMAFORO_PSI_DIR="$tmp/no-existe" "$aqui/semaforo.sh" 2>/dev/null; [ $? -eq 2 ]; }
prueba "semáforo en verde con la máquina libre" verde
prueba "semáforo en rojo por presión de CPU" rojo_cpu
prueba "semáforo en rojo por presión de memoria" rojo_memoria
prueba "semáforo en rojo con poca memoria disponible" rojo_disponible
prueba "en el umbral exacto sigue en verde" en_el_limite_es_verde
prueba "los umbrales se cambian por entorno" umbral_configurable
prueba "sin PSI sale con 2 en vez de adivinar" sin_psi_no_adivina

# --- pesado -----------------------------------------------------------------------------------
presion 5 0 8000

# Dos trabajos en la misma cola de una plaza no se solapan: cada uno apunta inicio y fin.
de_uno_en_uno() {
  local log="$tmp/serie.log"; : >"$log"
  for n in a b; do
    "$aqui/pesado.sh" "t-$n" -- sh -c "echo inicio-$n >>'$log'; sleep 1; echo fin-$n >>'$log'" 2>/dev/null &
  done
  wait
  # Válido: inicio-X, fin-X, inicio-Y, fin-Y (en cualquier orden de X e Y).
  [ "$(sed -n 1p "$log" | cut -d- -f2)" = "$(sed -n 2p "$log" | cut -d- -f2)" ] &&
    [ "$(sed -n 2p "$log" | cut -d- -f1)" = fin ]
}
prueba "una cola de una plaza ejecuta de uno en uno" de_uno_en_uno

# Con dos plazas, dos trabajos de 2 s acaban en menos de 4 s.
dos_plazas_en_paralelo() {
  local t0=$SECONDS
  for n in 1 2; do "$aqui/pesado.sh" --cola gpu --plazas 2 "g-$n" -- sleep 2 2>/dev/null & done
  wait
  ((SECONDS - t0 < 4))
}
prueba "con --plazas 2 corren dos a la vez" dos_plazas_en_paralelo

# Colas distintas no se esperan entre sí.
colas_independientes() {
  local t0=$SECONDS
  "$aqui/pesado.sh" --cola cpu c -- sleep 2 2>/dev/null &
  "$aqui/pesado.sh" --cola gpu g -- sleep 2 2>/dev/null &
  wait
  ((SECONDS - t0 < 4))
}
prueba "colas distintas no se esperan" colas_independientes

# Reentrante: un trabajo con turno que vuelve a pedirlo en su cola no se espera a sí mismo.
reentrante() {
  PESADO_ESPERA_MAX=3 timeout 10 "$aqui/pesado.sh" fuera -- \
    "$aqui/pesado.sh" dentro -- true 2>/dev/null
}
prueba "pedir turno desde dentro del turno no se bloquea" reentrante

# El código de salida de la orden llega a quien llama.
devuelve_el_codigo() { "$aqui/pesado.sh" x -- sh -c 'exit 7' 2>/dev/null; [ $? -eq 7 ]; }
prueba "devuelve el código de salida de la orden" devuelve_el_codigo

# Si el trabajo muere, la plaza se suelta (el cerrojo es del proceso, no un fichero). Se mata el
# grupo entero: la orden hereda el cerrojo, así que mientras ella viva la plaza sigue ocupada.
muere_y_suelta() {
  setsid "$aqui/pesado.sh" largo -- sleep 30 2>/dev/null &
  local pid=$!
  sleep 1
  kill -- "-$pid" 2>/dev/null; wait "$pid" 2>/dev/null
  PESADO_ESPERA_MAX=5 timeout 10 "$aqui/pesado.sh" siguiente -- true 2>/dev/null
}
prueba "si el trabajo muere, la plaza queda libre" muere_y_suelta

# Quien espera demasiado se rinde con 75 (EX_TEMPFAIL) en vez de quedarse para siempre.
se_rinde() {
  "$aqui/pesado.sh" ocupa -- sleep 4 2>/dev/null &
  sleep 1
  PESADO_ESPERA_MAX=1 "$aqui/pesado.sh" impaciente -- true 2>/dev/null
  local codigo=$?
  wait
  [ "$codigo" -eq 75 ]
}
prueba "tras la espera máxima se rinde con 75" se_rinde

# Con el semáforo en rojo no arranca; arranca en cuanto se pone verde.
espera_al_semaforo() {
  presion 90 0 8000
  local marca="$tmp/arranco"; rm -f "$marca"
  "$aqui/pesado.sh" paciente -- touch "$marca" 2>/dev/null &
  sleep 2
  [ ! -e "$marca" ] || return 1
  presion 5 0 8000
  wait
  [ -e "$marca" ]
}
prueba "espera al semáforo y arranca al ponerse verde" espera_al_semaforo

uso_incorrecto() { "$aqui/pesado.sh" sin-separador true 2>/dev/null; [ $? -eq 2 ]; }
prueba "sin «--» explica el uso y sale con 2" uso_incorrecto

echo
if ((fallos)); then echo "$fallos prueba(s) fallida(s)"; exit 1; fi
echo "todas las pruebas en verde"
