---
name: daily-log
description: Memoria en dos velocidades. Log diario crudo (append-only) + destilación periódica a MEMORY.md. Evita que MEMORY.md crezca sin control y preserva historial detallado por fecha.
triggers:
  - Cuando el usuario dice /daily-log o /log
  - Automáticamente al final de cada sesión (/session-end lo invoca)
  - Cuando el usuario dice /distill-memory o "actualiza la memoria"
  - Cuando MEMORY.md supera ~2,500 tokens
dependencies: .product/memory/MEMORY.md, .product/memory/YYYY-MM-DD.md
---

## El sistema de dos velocidades

```
Velocidad 1 — Log diario (crudo, append-only):
  .product/memory/YYYY-MM-DD.md
  → Qué pasó hoy, decisiones, cambios, errores
  → Sin límite de tokens, sin editar el pasado
  → Solo el agente escribe, append-only

Velocidad 2 — MEMORY.md (destilado, curado):
  .product/memory/MEMORY.md
  → Solo lo que vale recordar siempre
  → Máx ~3,000 tokens
  → Se actualiza por destilación, no por append
  → Tiene precedencia sobre logs diarios
```

**Analogía:** Los logs son el diario crudo. MEMORY.md es la sabiduría destilada de ese diario.

---

## MODO 1: Añadir entrada al log diario

### Cuándo:
- Al completar una tarea significativa durante la sesión
- Cuando se toma una decisión que no merece ADR pero vale recordar
- Al final de cada sesión (como parte de /session-end)
- Cuando ocurre un error importante y su solución

### Cómo:
Abrir `.product/memory/[YYYY-MM-DD].md` (crear si no existe) y añadir al final:

```markdown
## [HH:MM] [Título de la actividad]

**Tarea:** [qué se hizo]
**Resultado:** [qué se logró o qué falló]
**Decisiones:** [decisiones tomadas, si las hay]
**Aprendizaje:** [algo útil para el futuro, si aplica]
**Archivos tocados:** [lista de archivos modificados]
```

### Encabezado del archivo (solo primera entrada del día):
```markdown
# Log — [YYYY-MM-DD]

> Proyecto: [NOMBRE DEL PRODUCTO]
> Registro crudo de la sesión. No editar entradas pasadas — solo append.
```

---

## MODO 2: Distilación a MEMORY.md (/distill-memory)

### Cuándo activar:
- Cuando el usuario dice `/distill-memory`
- Cuando MEMORY.md supera ~2,500 tokens
- Periódicamente cada 3-5 días de trabajo activo
- Al inicio de un sprint o milestone nuevo

### Proceso de destilación:

**Paso 1 — Revisar logs recientes**
Leer los últimos 3-5 archivos `YYYY-MM-DD.md` en `.product/memory/`

**Paso 2 — Identificar qué merece ir a MEMORY.md**

Criterios para incluir:
- Decisiones arquitectónicas que siguen vigentes
- Patrones o convenciones descubiertas en el proyecto
- Errores importantes y cómo se resolvieron
- Preferencias del equipo confirmadas por la práctica
- Contexto de negocio que cambió

Criterios para NO incluir:
- Tareas completadas (eso va en WORKING_STATE.md)
- Bugs resueltos sin aprendizaje general
- Logs de debug
- Cosas que ya están en MEMORY.md sin cambios

**Paso 3 — Proponer diff de MEMORY.md**

Presentar al usuario:
```
## Propuesta de actualización — MEMORY.md

### Añadir:
- [item nuevo 1]
- [item nuevo 2]

### Actualizar:
- "[texto actual]" → "[texto nuevo]"

### Archivar (mover a MEMORY_ARCHIVE.md):
- [item obsoleto 1] — ya no relevante porque [razón]

¿Apruebas estos cambios?
```

**No modificar MEMORY.md sin aprobación explícita del usuario.**

**Paso 4 — Aplicar cambios aprobados**
- Actualizar MEMORY.md con los cambios aprobados
- Mover items archivados a `.product/memory/MEMORY_ARCHIVE.md`
- Añadir fecha de última destilación al encabezado de MEMORY.md

---

## Estructura de .product/memory/

```
.product/memory/
├── MEMORY.md              ← Destilado long-term (curado, máx 3k tokens)
├── MEMORY_ARCHIVE.md      ← Items archivados de MEMORY.md
├── SESSION-STATE.md       ← RAM activa (WAL, se sobrescribe cada sesión)
├── working-buffer.md      ← Red de seguridad anti-compactación
├── 2026-03-18.md          ← Log crudo del día
├── 2026-03-19.md
└── ...
```

---

## Precedencia de memoria

Cuando dos fuentes tienen información contradictoria:

1. **ADRs en DECISIONS.md** — máxima autoridad (decisiones formales)
2. **MEMORY.md** — fuente de verdad para hechos duraderos
3. **Logs diarios** — registro temporal, no prevalece sobre MEMORY.md
4. **SESSION-STATE.md** — estado operativo de hoy
5. **working-buffer.md** — más reciente, pero solo para recovery

---

## Integración con session-end

El skill `/session-end` debe invocar este skill automáticamente para:
1. Añadir entrada al log del día con resumen de la sesión
2. Verificar si MEMORY.md necesita destilación
3. Sugerir `/distill-memory` si hay muchos logs acumulados

---

## Reglas

1. **Logs son append-only** — nunca editar entradas pasadas
2. **MEMORY.md requiere aprobación** — proponer diff, no aplicar directo
3. **Destilación > acumulación** — mejor MEMORY.md pequeño y preciso que grande y ruidoso
4. **Fecha en nombre de archivo** — siempre `YYYY-MM-DD.md`, nunca `hoy.md` o `log.md`
5. **SESSION-STATE.md se sobrescribe** — es RAM, no historial
