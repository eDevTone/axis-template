# HOW IT WORKS — AXIS Context System

> Cómo interactúan todos los archivos de contexto cuando programas con un agente AI (Claude Code, Cursor, Windsurf).

---

## Al abrir Claude Code (cada sesión)

**Carga automática — sin que hagas nada:**

```
CLAUDE.md  →  El agente lo lee primero, siempre
```

Este archivo es el "sistema nervioso central". Contiene quién eres, en qué fase estás, las reglas inquebrantables, y la lista de skills disponibles. Claude Code lo carga solo al iniciar.

---

## Al escribir `/session-start`

El skill `session-start` toma el control y carga:

```
WORKING_STATE.md              →  ¿Dónde quedamos? ¿Qué está en progreso?
AGENT_CONTEXT.md              →  Mapa de contexto (qué cargar según la tarea)
.product/memory/MEMORY.md     →  Hechos duraderos del producto
```

Con esto el agente ya sabe: qué estabas construyendo, qué decisiones se tomaron, y qué sigue.

---

## Mientras programas (bajo demanda)

El agente carga **solo lo que necesita** según el tipo de tarea. No carga todo de golpe — eso desperdiciaría contexto:

| Tipo de tarea | Archivos que se cargan |
|--------------|------------------------|
| Feature nueva | `.product/architecture/OVERVIEW.md` + `COMPONENTS.md` + skill relevante |
| Debugging | `.product/architecture/COMPONENTS.md` + `DECISIONS.md` |
| Decisión de arquitectura | `DECISIONS.md` + `RISKS.md` + `MEMORY.md` |
| Deploy / Release | `RELEASE_CHECKLIST.md` + `RUNBOOK.md` + `SECURITY.md` |

---

## Al terminar una tarea

El agente actualiza:

```
WORKING_STATE.md                  →  Qué se hizo, qué sigue, qué bloquea
```

Y si surgió algo importante:

```
.product/memory/MEMORY.md         →  Decisiones duraderas
.product/memory/SESSION-STATE.md  →  Estado activo (WAL — Write-Ahead Log)
.product/context/DECISIONS.md     →  ADRs (decisiones arquitectónicas)
```

---

## Al hacer commit

El **git hook** `pre-commit` entra automáticamente:

```
WORKING_STATE.md  →  se sincroniza dentro de CLAUDE.md y .cursorrules
```

Así la próxima sesión (en cualquier IDE) arranca con el estado actual sin que hagas nada.

---

## Al escribir `/session-end`

Flush de memoria:

```
WORKING_STATE.md           →  Estado final del día
.product/memory/MEMORY.md  →  Hechos nuevos que valen guardar
```

---

## Niveles de autonomía del agente

Define cuánta libertad tiene el agente para actuar sin pedirte permiso. Se configura en `.product/contracts/AGENT_CONTRACT.md`.

### 🧭 Explorador
**"Propone, no actúa"**

El agente analiza y te presenta opciones — pero no escribe una línea hasta que tú apruebes.

> *"Encontré 3 formas de estructurar el auth. ¿Cuál prefieres?"*

**Cuándo usarlo:** Proyectos nuevos, decisiones arquitectónicas abiertas, o cuando el costo de un error es alto.

---

### ⚙️ Ejecutor *(recomendado)*
**"Implementa lo que está claro, pregunta lo que es ambiguo"**

Implementa features cuando las specs están definidas. Solo interrumpe si hay ambigüedad real.

> *"Implementé el CRUD de clientes con validación Zod. Hay una decisión sobre soft delete — ¿flag o tabla separada?"*

**Cuándo usarlo:** El 90% del tiempo. Stack definido, arquitectura clara, quieres avanzar sin micromanagear.

---

### 🚀 Piloto Automático
**"Actúa, entrega, informa"**

Máxima autonomía. Implementa, escribe tests, hace commits y propone el PR completo. Tú solo revisas el resultado final.

> *"Feature de exportar CSV lista. Tests pasando. PR #12 abierto."*

**Cuándo usarlo:** Tareas rutinarias de bajo riesgo donde ya confías totalmente en el agente y el patrón está establecido.

---

## El diagrama mental

```
Siempre activo:
  CLAUDE.md ──────────────────── Bootstrap (reglas, identidad, skills)

Al iniciar sesión:
  WORKING_STATE.md ────────────── ¿Dónde quedamos?
  AGENT_CONTEXT.md ────────────── Mapa de contexto
  .product/memory/MEMORY.md ───── Historia del producto

Bajo demanda (según tarea):
  .product/architecture/   ──────── Estructura, componentes, riesgos
  .product/context/        ──────── Negocio, decisiones, roadmap
  .product/security/       ──────── Solo cuando hay deploy o auth
  .product/operations/     ──────── Solo en release
  .claude/skills/          ──────── Solo cuando la tarea lo requiere

Se actualiza constantemente:
  WORKING_STATE.md ────────────── Después de cada tarea
  SESSION-STATE.md ────────────── WAL (correcciones, decisiones del día)
  .product/memory/MEMORY.md ───── Hechos que vale recordar siempre
```

---

## La clave del sistema

AXIS evita que el agente cargue miles de tokens de contexto en cada turno. En cambio, carga por capas — solo lo relevante para la tarea actual. Eso mantiene al agente enfocado y no desperdicia tu ventana de contexto.

**Progressive disclosure:** el agente carga más contexto solo cuando lo necesita, no todo de golpe.

---

## Referencia rápida de archivos

| Archivo | Quién lo escribe | Cuándo se actualiza |
|---------|-----------------|---------------------|
| `CLAUDE.md` | Tú (+ git hook auto-sync) | Al inicializar y en cada commit |
| `WORKING_STATE.md` | El agente | Después de cada tarea |
| `AGENT_CONTEXT.md` | Tú / el agente | Cuando cambia el mapa de contexto |
| `.product/memory/MEMORY.md` | El agente | Cuando hay hechos duraderos nuevos |
| `.product/memory/SESSION-STATE.md` | El agente | WAL — cada corrección o decisión |
| `.product/context/DECISIONS.md` | El agente | Al tomar decisiones arquitectónicas |
| `.product/contracts/AGENT_CONTRACT.md` | `init-project.sh` / tú | Al configurar nivel de autonomía |
