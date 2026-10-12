# <Proyecto> · hoja de ruta

**Léelo primero.** Documento de entrada para cualquier agente que retome el proyecto: dónde
estamos, cómo trabajamos, qué planes hay y qué sigue. Se actualiza **al cerrar cada tarea**, no al
final del día. Si algo de aquí contradice al código, manda el código y se corrige esto.

Última actualización: **<fecha y hora>** (<n.º de agente o relevo>)

---

## 1. Dónde estamos ahora

| | |
|---|---|
| Último terminado | <qué, con su commit> |
| A medias | <rama, fichero, qué falta y por qué se paró> |
| **Siguiente paso** | <lo primero que hará el agente nuevo, concreto> |
| Avisos para quien siga | <trampas descubiertas: «nunca X porque Y»> |
| Lo que espera a la persona | <dinero, publicar, cuentas…; o «nada»> |

## 2. Cómo trabajamos

- **Diseño → plan → tareas.** El diseño (`docs/diseno.md`) está aprobado y no se rediscute. Cada
  plan se escribe antes de tocar código, con tareas pequeñas y los casos que más pueden romperse.
- **Cada tarea:** test que falla → código → test que pasa → comprobación completa → commit →
  una línea por decisión en el registro del plan («Decisión: … — por qué: … — coste: …»).
- **Un fallo destapado = arreglo de raíz + test**, nunca una excepción en el test.
- **Nada se da por hecho sin verlo:** se despliega en staging y se prueba de verdad.
- **Una rama por plan**; a `main` solo con la CI en verde.
- Lo pesado (navegadores, e2e, builds grandes) va con `pesado.sh <etiqueta> -- <orden>`.

## 3. Los planes

| Plan | Estado | Qué deja hecho |
|---|---|---|
| 1 · <nombre> | ✅ <fecha> | <resumen de una línea> |
| 2 · <nombre> | En curso | <…> |

## 4. Registro

- **<fecha hora>** — <una línea por tarea cerrada o decisión importante>
