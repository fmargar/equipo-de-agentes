# Prompt de la revisión horaria

Lo que la tarea programada recurrente le manda a la jefatura cada hora (unos minutos después de
la hora en que se renueva la cuota de uso, para que la primera revisión tras un corte reanude a
todos).

```text
Revisión horaria de la jefatura. Sigue jefatura/PROTOCOLO.md, «Cada revisión»:
1. get_session de cada trabajador de JEFATURA.md: estado y contexto.
2. Parados: lee su último resultado (list_events, kinds ["result"], limit 3). «Relevo hecho» →
   archívalo y crea el siguiente con su mismo encargo y «sigue con <proyecto>». Si no → mándale
   que siga por el siguiente paso de su hoja de ruta.
3. Contexto > 30 % → pídele el relevo al cerrar lo que tiene entre manos.
4. Fallidos por límite de uso → si la cuota ya se renovó, reanúdalos.
5. pesado/semaforo.sh --ver; en rojo, mira quién tiene la fila.
6. Una línea en el registro de JEFATURA.md, commit y push. Si tu propio contexto pasa del 30 %,
   haz tu relevo: JEFATURA.md al día y una sesión nueva que lo lea.
```
