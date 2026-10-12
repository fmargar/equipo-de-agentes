#!/usr/bin/env bash
# pesado.sh — fila común para los trabajos pesados de varios agentes en una misma máquina.
#
# Cuando varios agentes trabajan a la vez (uno por proyecto), cada uno cree que la máquina es
# suya: tres navegadores de pruebas, un build y una grabación de vídeo a la vez la ahogan, y
# todo va más lento que de uno en uno. Esto pone los trabajos pesados en fila:
#
#   1. Coge una plaza en su cola (flock). Si están todas cogidas, espera en fila.
#   2. Con la plaza, espera a que el semáforo de presión esté en verde (semaforo.sh).
#   3. Lanza la orden con prioridad baja (nice). Al acabar, o al morir, la plaza se suelta sola:
#      el cerrojo es del descriptor del proceso, no un fichero que haya que acordarse de borrar.
#
# Uso:
#   pesado.sh [--cola NOMBRE] [--plazas N] <etiqueta> -- <orden> [args...]
#     pesado.sh web-e2e -- pnpm test:e2e
#     pesado.sh --cola gpu --plazas 2 video-render -- ./render.sh escena-3
#
# Colas: cada una con sus plazas (1 por defecto). Una cola «gpu» deja que una grabación con la
# tarjeta no espere a un build que solo usa CPU; las dos respetan el mismo semáforo.
#
# Reentrante: si un trabajo con turno vuelve a pedirlo en la misma cola (un despliegue envuelto
# en pesado.sh cuyo build también llama a pesado.sh), pasa sin esperar. Sin esto se espera a sí
# mismo hasta agotar el plazo y bloquea la fila entera.
#
# Quién tiene cada plaza:  cat "$PESADO_DIR"/*.quien
#
# Entorno: PESADO_DIR (cerrojos; por defecto ${XDG_RUNTIME_DIR:-/tmp}/pesado), PESADO_ESPERA_MAX
# (segundos esperando plaza antes de rendirse, 5400), PESADO_NICE (10), PESADO_PAUSA (segundos
# entre lecturas del semáforo, 30) y los umbrales de semaforo.sh.
set -u

aqui=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
COLA=cpu
PLAZAS=1
while [[ "${1:-}" == --* && "${1:-}" != -- ]]; do
  case "$1" in
    --cola) COLA=${2:?falta el nombre de la cola}; shift 2 ;;
    --plazas) PLAZAS=${2:?faltan las plazas}; shift 2 ;;
    *) echo "pesado: opción desconocida: $1" >&2; exit 2 ;;
  esac
done
if [ $# -lt 3 ] || [ "$2" != "--" ]; then
  echo "uso: $0 [--cola NOMBRE] [--plazas N] <etiqueta> -- <orden> [args...]" >&2
  exit 2
fi
etiqueta=$1
shift 2
[[ "$COLA" =~ ^[a-z0-9_-]+$ ]] || { echo "pesado: nombre de cola no válido: $COLA" >&2; exit 2; }
[[ "$PLAZAS" =~ ^[1-9][0-9]*$ ]] || { echo "pesado: --plazas tiene que ser un entero >= 1" >&2; exit 2; }

dir=${PESADO_DIR:-${XDG_RUNTIME_DIR:-/tmp}/pesado}
espera_max=${PESADO_ESPERA_MAX:-5400}
prioridad=${PESADO_NICE:-10}
pausa=${PESADO_PAUSA:-30}
mkdir -p "$dir"

if [[ " ${PESADO_TURNO:-} " == *" $COLA "* ]]; then
  echo "[pesado] $etiqueta: ya dentro del turno de la cola $COLA" >&2
  exec nice -n "$prioridad" "$@"
fi

# Intenta coger cualquier plaza libre sin esperar; deja el cerrojo abierto en el descriptor 9.
coger_plaza() {
  local i
  for ((i = 1; i <= PLAZAS; i++)); do
    exec 9>"$dir/$COLA-$i.lock"
    if flock -n 9; then PLAZA=$i; return 0; fi
    exec 9>&-
  done
  return 1
}

if ! coger_plaza; then
  ocupan=$(cat "$dir/$COLA"-*.quien 2>/dev/null | paste -sd ';' -)
  echo "[pesado] cola $COLA llena (${ocupan:-?}); $etiqueta espera turno (máx. ${espera_max}s)" >&2
  if ((PLAZAS == 1)); then
    exec 9>"$dir/$COLA-1.lock"
    flock -w "$espera_max" 9 || { echo "[pesado] $etiqueta: sin turno tras ${espera_max}s" >&2; exit 75; }
    PLAZA=1
  else
    limite=$((SECONDS + espera_max))
    until coger_plaza; do
      ((SECONDS >= limite)) && { echo "[pesado] $etiqueta: sin turno tras ${espera_max}s" >&2; exit 75; }
      sleep 1
    done
  fi
fi

until "$aqui/semaforo.sh"; do sleep "$pausa"; done

quien="$dir/$COLA-$PLAZA.quien"
echo "$etiqueta (pid $$, desde $(date '+%H:%M'))" >"$quien"
trap 'rm -f "$quien"' EXIT
PESADO_TURNO="${PESADO_TURNO:+$PESADO_TURNO }$COLA" nice -n "$prioridad" "$@"
