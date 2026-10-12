---
name: relevo
description: Usar cuando el contexto del chat pase del ~30 %, cuando la persona pida «relevo» o «cambiamos de chat», o al cerrar una sesión larga en un proyecto. Deja escrito en la hoja de ruta del proyecto dónde estamos y qué sigue, lo sube a git y avisa a la jefatura, para que un agente nuevo retome con solo «sigue con <proyecto>».
---

# Relevo de chat

El chat es desechable; la hoja de ruta no. El relevo escribe lo que un agente nuevo **no puede
deducir del código ni de git**, en el sitio donde ese agente va a mirar primero.

## Dónde vive el estado

Cada proyecto tiene un `CLAUDE.md` corto que manda leer `docs/HOJA-DE-RUTA.md`, y la hoja de
ruta empieza por **«1. Dónde estamos ahora»**. Si el proyecto no la tiene, créala con
[`plantillas/HOJA-DE-RUTA.md`](../plantillas/HOJA-DE-RUTA.md).

## Pasos

1. **Qué proyectos ha tocado esta sesión.** El relevo se hace en cada uno.
2. **Reescribir «Dónde estamos ahora»** con la fecha y la hora, para que se lea en un minuto:
   - lo último terminado, con su commit;
   - **lo que queda a medias, exacto**: rama, fichero, qué falta y por qué se paró;
   - el **siguiente paso concreto** (lo primero que hará el agente nuevo);
   - lo que espera a la persona, si algo.
   Se reescribe, no se añade debajo.
3. **Decisiones**: cada una con su porqué donde el proyecto las guarde (el registro del plan).
4. **Commit y push.** Puede haber otros agentes en el mismo repo: mirar `git status` y añadir
   **solo** los ficheros de esta sesión, nunca `git add -A`.
5. **Avisar a la jefatura con `send_message`** («relevo hecho» + tres líneas: qué queda guardado,
   el siguiente paso, cualquier aviso). Escribirlo solo en la respuesta no lo ve nadie.
6. **Responder** en tres líneas: qué ha quedado guardado, el siguiente paso y la frase para el
   chat nuevo: «sigue con <proyecto>».

## Al empezar con «sigue con <proyecto>»

Leer el `CLAUDE.md` del proyecto y su «Dónde estamos ahora», comprobar con `git log -5` y
`git status` que coincide con el código (si no coincide, manda el código y se corrige la hoja de
ruta) y continuar por el siguiente paso sin preguntar lo que ya está escrito.
