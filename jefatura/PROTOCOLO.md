# Protocolo de la jefatura

La jefatura es un agente más (un chat de Claude Code) cuyo único trabajo es que los demás
trabajen: los arranca, los vigila por la API de sesiones, los reanuda y resume el día a una
persona. No programa. Su estado vive en un fichero (`JEFATURA.md`, ver
[`plantillas/JEFATURA.md`](../plantillas/JEFATURA.md)), así que la propia jefatura también se
releva como cualquier trabajador.

## Herramientas que usa

Las de cualquier sistema de sesiones de agentes con API. Con Claude Code en remoto:

| Para | Herramienta |
|---|---|
| Arrancar un trabajador con su encargo | `create_session` (repo, prompt inicial, etiquetas) |
| Ver si trabaja, está parado o ha fallado, y cuánto contexto lleva | `get_session` (`status_bucket`, uso de contexto) |
| Leer qué dijo al acabar su turno | `list_events` con `kinds: ["result"]` y un `limit` bajo |
| Darle una orden o reanudarlo | `send_message` |
| Retirarlo tras su relevo | `archive_session` |
| Despertarse cada hora | una tarea programada recurrente (no avisos sueltos encadenados), o revisar por eventos: cuando la persona escribe o un trabajador avisa |

## Reglas que reciben todos los trabajadores

Van en el prompt inicial de cada uno:

1. **Tu estado vive en la hoja de ruta** del proyecto, no en el chat. Al cerrar cada tarea:
   commit, push y hoja de ruta al día.
2. **Relevo al ~30 % de contexto**: deja «Dónde estamos ahora» escrito y subido y avisa a la
   jefatura **con `send_message`**. Escribirlo solo en tu respuesta no lo lee nadie.
3. **Nunca cierres el turno esperando algo externo** (la CI, un render largo): nadie te despierta
   cuando acaba. Mientras esperas, avanza otra tarea y vuelve a mirar.
4. **Lo pesado, en fila**: navegadores, e2e, builds grandes y grabaciones van con
   `pesado.sh <etiqueta> -- <orden>`. Lo ligero (tests unitarios, lint) no hace fila.
5. **Lo que no es tuyo no se decide**: dinero, publicar algo, cuentas, borrar datos de producción.
   No se pregunta y se espera: se apunta en «Lo que espera a la persona» y se sigue con otra cosa.
6. **Para esperar un build o una prueba larga**, lánzalo en segundo plano con un aviso al acabar
   (esperar con `grep` sobre su registro, no con `pgrep -f`, que se encuentra a sí mismo) y sigue.
7. **Lo que solo se ve en el dispositivo real** (un móvil, una tele) no se da por hecho con pruebas
   en la propia máquina: se apunta como pendiente de comprobar.

### Prompt de un trabajador nuevo

```text
Sigue con <proyecto>. Lee su CLAUDE.md y «Dónde estamos ahora» en docs/HOJA-DE-RUTA.md.
Eres trabajador de la jefatura (<id>): los hitos y el relevo se le avisan con send_message,
nunca solo en la respuesta. Encargo: <qué y por qué>. Lo que dependa de la persona va a
«Lo que espera a la persona» y sigues con lo demás. Reglas: relevo al ~30 % de contexto; lo
pesado, por pesado.sh; commit y push al cerrar cada tarea; no le preguntes a la persona.
```

## Cada revisión (cada hora)

1. **Estado de cada trabajador** (`get_session`): trabajando, parado, fallido; y su contexto.
2. **Parado** → leer su último resultado. Si dice «relevo hecho»: archivarlo y crear el siguiente
   con el mismo encargo y la frase «sigue con <proyecto>». Si no: mandarle que siga por el
   siguiente paso de su hoja de ruta.
3. **Contexto por encima del ~30 %** → pedirle el relevo al terminar lo que tiene entre manos.
4. **Fallido por límite de uso** → mirar cuándo se renueva y reanudarlo en la primera revisión
   después. Las revisiones que caigan dentro del límite tampoco corren (la jefatura gasta de la
   misma cuota): la primera tras la renovación reanuda a todos.
5. **La máquina**: `pesado/semaforo.sh --ver`. En rojo, ver quién tiene la fila (`*.quien`) y, si
   alguien lanza trabajo pesado fuera de ella, pararlo.
6. **Una línea en el registro** de `JEFATURA.md`. A la persona, solo dos resúmenes al día.
7. **Cerrar lo terminado**: archivar a los trabajadores tras su relevo (cada chat vivo ocupa memoria
   en la máquina), y actualizar la plantilla de chats y el mapa de proyectos. **Nunca** archivar
   un chat que abrió la persona: «para los chats» es interrumpir, no archivar.

## Limpieza de chats (de vez en cuando)

Desarchivar una sesión no relanza su proceso: puede quedarse en la lista como «trabajando» sin
nada detrás. Para limpiar, inventario completo: por cada sesión sin archivar, leer su último
resultado, comprobar que lo pendiente está escrito en la hoja de ruta de su proyecto (si no, se
escribe o se termina), y solo entonces archivarla. Las de la persona, con su permiso.

## El relevo de la propia jefatura

La jefatura escribe en `JEFATURA.md` un «Estado para la jefatura siguiente» (trabajadores vivos,
qué espera cada uno, avisos) y crea la siguiente. Las sesiones creadas por sesiones tienen una
**profundidad máxima**: cuando el linaje llega al tope, la jefatura deja el estado escrito y le
pide a la persona que abra la siguiente a mano con «sigue con la jefatura».

## Por qué así (lo que enseñó cada fallo)

- **Relevo al 30 %, no al 60 %.** Cada paso de un agente reenvía su contexto. Un chat con
  500.000 tokens gasta en cada paso unas cinco veces lo que uno con 100.000, y la caché del
  prompt dura una hora: tras una parada larga, reanudar seis chats grandes los reescribe todos
  de golpe. Un agente nuevo que lee solo la hoja de ruta arranca con unos 50.000.
- **No reanudar chats grandes tras una parada**: se abre uno nuevo desde su hoja de ruta.
- **Avisar con `send_message`, no en la respuesta.** Un trabajador hizo un relevo impecable,
  lo dijo en su respuesta… y se quedó parado horas porque la jefatura no lee respuestas.
- **Una tarea programada recurrente, no avisos en cadena.** Si un aviso «vuelve en 50 minutos»
  cae dentro del límite de uso, no corre, no programa el siguiente y la cadena se rompe en
  silencio. La recurrente vuelve a disparar sola en la siguiente hora.
- **Presión, no media de carga.** La media de carga llegó a marcar 17–23 con la CPU al 5 % de
  presión: la subían los procesos esperando a un disco casi lleno. Con la media como semáforo,
  los agentes se quedaban parados esperando una CPU que estaba libre.
- **Fila con reentrada.** Un despliegue envuelto en la fila cuyo build también pedía turno se
  esperó a sí mismo hora y media con todos los demás detrás. Ahora quien ya tiene turno pasa.
- **Revisión independiente con otro modelo** solo donde equivocarse cuesta caro (la exactitud de
  una calculadora fiscal, la seguridad antes de publicar): un revisor que no escribió el código
  no comparte sus puntos ciegos. Para el día a día, no.
