---
name: session-end
description: Memory flush y cierre de sesion. Persiste el estado y conocimiento adquirido.
triggers: Cuando el usuario dice /session-end, "guarda estado", "memory flush", o "cierra sesion".
dependencies: WORKING_STATE.md, .product/memory/MEMORY.md, .product/context/DECISIONS.md
---

## Que hacer

### Paso 1 — Actualizar WORKING_STATE.md
1. Mover tareas completadas a "Completado en Ultima Sesion"
2. Actualizar "En Progreso" con el estado real
3. Ajustar "Proxima Sesion" con lo que sigue
4. Agregar blockers si aparecieron

### Paso 2 — Evaluar MEMORY.md
Revisar la sesion y determinar si hay hechos nuevos que deban persistir:
- Decisiones tomadas (que no sean ADR)
- Preferencias descubiertas
- Lecciones aprendidas
- Contexto de negocio nuevo

Si hay cambios, proponer el diff al usuario. No modificar sin aprobacion.

### Paso 3 — Evaluar ADRs
Si durante la sesion se tomo alguna decision arquitectonica que no se documento:
- Proponer crear un ADR en `.product/context/DECISIONS.md`
- Seguir el formato del skill `adr`

### Paso 3.5 — Sugerir sync de Jira
Si hay tasks con Jira keys (patron PROJ-XXX) en "Completado en Ultima Sesion" o "Blockers":
- Mencionar: "Hay X tasks con Jira keys que cambiaron de status. Considera ejecutar `/sync-jira` para actualizar Jira."
- NO ejecutar automaticamente — solo sugerir.

### Paso 3.7 — Log diario (skill daily-log)
Añadir entrada al log de hoy en `.product/memory/[YYYY-MM-DD].md`:
- Resumen de qué se hizo en esta sesión
- Decisiones tomadas
- Aprendizajes o errores relevantes
- Archivos principales tocados

Si MEMORY.md tiene más de ~2,500 tokens, sugerir: "Considera ejecutar `/distill-memory` para limpiar y destilar la memoria."

### Paso 3.8 — Limpiar working-buffer
Si `.product/memory/working-buffer.md` tiene contenido de esta sesión, añadir entrada final de cierre y dejar el archivo listo para la próxima sesión.

### Paso 4 — Reporte de cierre
Presentar resumen al usuario:

```
## Cierre de sesion

**Actualizado:** WORKING_STATE.md
**MEMORY.md:** [sin cambios / propuesta de cambio pendiente]
**Log diario:** .product/memory/[YYYY-MM-DD].md actualizado
**Working buffer:** limpiado para próxima sesión
**ADRs:** [ninguno / ADR-XXX propuesto]
**Jira sync:** [sin tasks Jira / X tasks pendientes de sync — /sync-jira]
**Distilación:** [no necesaria / MEMORY.md cerca del límite — ejecutar /distill-memory]

Estado guardado. La proxima sesion puede retomar desde WORKING_STATE.md.
```

## Reglas

1. WORKING_STATE.md se actualiza directamente (es estado actual, se sobrescribe)
2. MEMORY.md se propone como diff — el usuario decide
3. Si MEMORY.md excede ~3,000 tokens, proponer mover items obsoletos a MEMORY_ARCHIVE.md
4. (Opcional) Si el equipo usa logs diarios, anadir entrada a `.product/memory/YYYY-MM-DD.md`
5. Precedencia de memoria: ADRs > MEMORY.md > logs diarios > WORKING_STATE.md
