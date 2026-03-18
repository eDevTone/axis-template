# [NOMBRE DEL PRODUCTO] — Contexto para Claude Code

## Identidad
[Reemplazar con 1-2 lineas: que es, para quien, stack principal]

## Estado Actual
- Fase: [Construccion / Validacion / Produccion]
- Foco actual: [que estamos haciendo ahora]
- Ultimo cambio: [fecha + que cambio]
- Proximo objetivo: [que sigue]

## Reglas Inquebrantables
1. [Regla de seguridad mas critica]
2. [Restriccion arquitectonica fundamental]
3. [Convencion obligatoria mas importante]

## Protocolo de Sesion
0. **Si detectas compactacion** (mensaje con `<summary>` o usuario dice "donde estabamos") → activa skill `working-buffer` MODO 2 primero
1. Lee `WORKING_STATE.md` para saber donde quedamos
2. Lee `.product/memory/SESSION-STATE.md` si existe (WAL activo — correcciones y decisiones recientes)
3. Lee `.product/memory/MEMORY.md` si necesitas contexto de largo plazo
4. Consulta segun la tarea:
   - Codigo nuevo -> skill `[code-patterns]` + `.product/architecture/OVERVIEW.md`
   - Debugging -> `.product/architecture/COMPONENTS.md`
   - Arquitectura -> `.product/context/DECISIONS.md` + `.product/architecture/OVERVIEW.md`
   - Testing -> skill `[testing]`
   - Deploy -> `.product/operations/RELEASE_CHECKLIST.md`
5. Al completar cada tarea -> actualiza `WORKING_STATE.md` con lo hecho y lo que sigue
6. Al hacer commit -> verifica que `WORKING_STATE.md` refleje el estado actual
7. Si surgio un hecho significativo nuevo -> actualizar `.product/memory/MEMORY.md`
8. **WAL Protocol** — si el usuario hace una correccion o decision importante → escribe en `SESSION-STATE.md` ANTES de responder

## Skills Disponibles
| Skill | Cuando activarlo |
|-------|-----------------|
| session-start | `/session-start` — Cargar contexto e iniciar sesion (incluye recovery) |
| session-end | `/session-end` — Memory flush, log diario y cierre de sesion |
| working-buffer | `/danger-zone` — Activar buffer anti-compactacion / `/recover` — Recovery post-compactacion |
| daily-log | `/daily-log` — Añadir entrada al log del dia / `/distill-memory` — Destilar logs a MEMORY.md |
| update-memory | `/update-memory` — Revisar y limpiar MEMORY.md |
| sync-context | `/sync-context` — Verificar integridad del contexto |
| import-jira | `/import-jira` — Importar Epic/Stories/Tasks de Jira |
| sync-jira | `/sync-jira` — Sincronizar estado de tasks con Jira |
| session-protocol | Referencia completa del protocolo de sesion |
| commit-and-pr | Hacer commits o PRs |
| adr | Documentar decisiones arquitectonicas |

Para activar: lee `.claude/skills/[nombre]/SKILL.md`
