#!/usr/bin/env bash
# semaforo.sh — ¿hay sitio en la máquina para un trabajo pesado?
#
# Mira la presión real (PSI de Linux, /proc/pressure) y la memoria disponible, no la media de
# carga: la media de carga también cuenta los procesos esperando al disco, y puede marcar 20 en
# una máquina con la CPU casi libre. La presión dice cuánto tiempo pasan las tareas esperando
# de verdad por CPU, memoria o disco.
#
#   semaforo.sh          sale con 0 si está en verde y con 1 si está en rojo (y dice por qué)
#   semaforo.sh --ver    imprime las lecturas y el veredicto
#
# Umbrales (variables de entorno):
#   SEMAFORO_CPU_MAX   CPU «some» avg60, % del tiempo con alguna tarea esperando CPU   (40)
#   SEMAFORO_MEM_MAX   memoria «full» avg60, % del tiempo con TODO parado por memoria  (10)
#   SEMAFORO_DISP_MIN  MB de MemAvailable por debajo de los cuales no se arranca nada  (1536)
#   SEMAFORO_IO_MAX    disco «full» avg60, % del tiempo con TODO parado esperando al disco (40).
#                      Opcional: si el núcleo no da /proc/pressure/io, no se mira.
# Para las pruebas: SEMAFORO_PSI_DIR (por defecto /proc/pressure) y SEMAFORO_MEMINFO.
set -u

psi_dir=${SEMAFORO_PSI_DIR:-/proc/pressure}
meminfo=${SEMAFORO_MEMINFO:-/proc/meminfo}
cpu_max=${SEMAFORO_CPU_MAX:-40}
mem_max=${SEMAFORO_MEM_MAX:-10}
disp_min=${SEMAFORO_DISP_MIN:-1536}
io_max=${SEMAFORO_IO_MAX:-40}

# avg60 de la línea pedida («some» o «full») de un fichero PSI, redondeada hacia abajo.
avg60() { awk -v linea="$2" '$1 == linea { split($3, a, "="); print int(a[2]) }' "$psi_dir/$1"; }

if [ ! -r "$psi_dir/cpu" ] || [ ! -r "$psi_dir/memory" ]; then
  echo "semaforo: no hay PSI en $psi_dir (núcleo sin CONFIG_PSI o psi=0); no puedo medir" >&2
  exit 2
fi

cpu=$(avg60 cpu some)
mem=$(avg60 memory full)
disp=$(awk '/^MemAvailable:/ { print int($2 / 1024) }' "$meminfo")
io=""
[ -r "$psi_dir/io" ] && io=$(avg60 io full)

verde=1
[ "$cpu" -le "$cpu_max" ] || verde=0
[ "$mem" -le "$mem_max" ] || verde=0
[ "$disp" -ge "$disp_min" ] || verde=0
[ -z "$io" ] || [ "$io" -le "$io_max" ] || verde=0

lectura="cpu some $cpu% (máx. $cpu_max), memoria full $mem% (máx. $mem_max), disponibles $disp MB (mín. $disp_min)"
[ -z "$io" ] || lectura="$lectura, disco full $io% (máx. $io_max)"
if [ "${1:-}" = "--ver" ]; then
  if [ "$verde" = 1 ]; then echo "VERDE · $lectura"; else echo "ROJO · $lectura"; fi
fi
if [ "$verde" = 1 ]; then exit 0; fi
[ "${1:-}" = "--ver" ] || echo "semaforo en rojo: $lectura" >&2
exit 1
