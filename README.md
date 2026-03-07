# AXIS Template

**AXIS** (Agent eXperience & Information Structure) es un sistema de archivos que organiza el contexto, la memoria y las instrucciones de un proyecto de software para que agentes de AI (Claude Code, Cursor, Windsurf, etc.) trabajen de forma efectiva desde el primer minuto.

En lugar de explicarle todo al agente en cada conversacion, AXIS estructura la informacion del proyecto en capas. El agente carga solo lo que necesita, cuando lo necesita, y recuerda lo importante entre sesiones.

## El problema que resuelve

Cuando trabajas con un agente de AI en un proyecto de software:

- **Sin contexto**, el agente genera codigo generico que no respeta la arquitectura existente.
- **Con demasiado contexto**, se desperdician tokens en cada turno y el agente pierde foco.
- **Sin memoria**, cada sesion empieza de cero: repites las mismas explicaciones una y otra vez.
- **Sin estructura**, el agente no sabe donde buscar ni que archivos importan.

AXIS resuelve esto con tres ideas:

1. **Progressive disclosure** — el agente carga contexto por capas segun la tarea, no todo de golpe.
2. **Token budgets** — cada archivo tiene un limite de tokens para evitar saturar la ventana de contexto.
3. **Memoria de 3 capas** — estado actual (`WORKING_STATE.md`), logs diarios (`.product/memory/YYYY-MM-DD.md`), y hechos duraderos (`MEMORY.md`).

## Quick Start

### Opcion A: Usar como template para un proyecto nuevo

```bash
# 1. Clonar el template
git clone https://github.com/ManuelFeregrino/axis-template.git mi-proyecto
cd mi-proyecto

# 2. Limpiar el historial de git para empezar fresco
rm -rf .git
git init

# 3. Hacer ejecutables los scripts e instalar git hooks
chmod +x scripts/*.sh
./scripts/install-git-hooks.sh

# 4. Reemplazar los placeholders [NOMBRE DEL PRODUCTO], [NOMBRE], etc.
#    en CLAUDE.md, WORKING_STATE.md, y los archivos en .product/

# 5. Primer commit
git add .
git commit -m "init: inicializa proyecto con AXIS"
```

### Opcion B: Agregar AXIS a un proyecto existente

```bash
# 1. Desde la raiz de tu proyecto existente
git clone https://github.com/ManuelFeregrino/axis-template.git /tmp/axis-template

# 2. Copiar la estructura AXIS
cp -r /tmp/axis-template/.product .
cp -r /tmp/axis-template/.claude .
cp -r /tmp/axis-template/scripts .
cp -r /tmp/axis-template/git-hooks .
cp /tmp/axis-template/CLAUDE.md .
cp /tmp/axis-template/.cursorrules .
cp /tmp/axis-template/AGENT_CONTEXT.md .
cp /tmp/axis-template/WORKING_STATE.md .
cp /tmp/axis-template/CHANGELOG.md .

# 3. Instalar git hooks
chmod +x scripts/*.sh
./scripts/install-git-hooks.sh

# 4. Rellenar los placeholders y hacer commit
```

### Despues de instalar

Rellena estos archivos con la informacion de tu proyecto:

| Archivo | Que poner |
|---------|-----------|
| `CLAUDE.md` | Identidad del producto, reglas criticas, estado actual |
| `.cursorrules` | Lo mismo que CLAUDE.md (para Cursor/Windsurf) |
| `WORKING_STATE.md` | Que esta en progreso, que sigue |
| `.product/context/PRODUCT.md` | Que hace el producto y para quien |
| `.product/architecture/OVERVIEW.md` | Stack, diagrama, patrones |

Los demas archivos en `.product/` se van llenando conforme el proyecto avanza.

## Como funciona

### Capas de contexto

AXIS organiza la informacion en 4 capas. El agente solo carga lo que necesita:

```
Capa 0 - Bootstrap (se carga SIEMPRE, cada turno)
  CLAUDE.md / .cursorrules         max ~3,000 tokens

Capa 1 - Sesion (se carga al iniciar sesion)
  WORKING_STATE.md                 max ~2,000 tokens
  AGENT_CONTEXT.md                 max ~2,000 tokens

Capa 2 - Bajo demanda (se carga segun la tarea)
  .product/context/*               Negocio, roadmap, decisiones
  .product/architecture/*          Stack, componentes, riesgos
  .product/operations/*            Deploy, runbook
  .product/security/*              Politicas, amenazas
  .product/contracts/*             Autonomia del agente
  .product/memory/MEMORY.md        Hechos duraderos

Capa 3 - Skills (se carga cuando la tarea lo requiere)
  .claude/skills/*/SKILL.md        Instrucciones especializadas
```

El mapa de que cargar segun la tarea esta en `AGENT_CONTEXT.md`.

### Memoria entre sesiones

El agente no pierde contexto entre conversaciones:

- **`WORKING_STATE.md`** — Estado actual: que esta en progreso, que sigue, que bloquea. Se sobrescribe cada sesion.
- **`.product/memory/YYYY-MM-DD.md`** — Log diario: que se hizo, que se decidio, que se aprendio. Append-only.
- **`.product/memory/MEMORY.md`** — Hechos duraderos: decisiones vigentes, preferencias, lecciones. Se mantiene bajo 3,000 tokens.

Un git hook sincroniza automaticamente el estado de `WORKING_STATE.md` dentro de `CLAUDE.md` en cada commit, para que el agente siempre arranque con contexto fresco.

### Skills

Los skills son instrucciones modulares que el agente carga solo cuando las necesita. Viven en `.claude/skills/[nombre]/SKILL.md`.

El template incluye 3 skills base:

| Skill | Que hace |
|-------|---------|
| `session-protocol` | Protocolo de inicio/cierre de sesion y memory flush |
| `commit-and-pr` | Conventional Commits, branching, estructura de PRs |
| `adr` | Formato y proceso para Architecture Decision Records |

Puedes agregar skills propios para tu dominio (patrones de codigo, testing, etc.).

### Niveles de autonomia

El archivo `.product/contracts/AGENT_CONTRACT.md` define 3 niveles:

| Nivel | Cuando | Comportamiento |
|-------|--------|----------------|
| **Explorador** | Arquitectura, decisiones de diseno | Propone opciones, espera aprobacion |
| **Ejecutor** (default) | Features con specs claras | Implementa y reporta |
| **Piloto Automatico** | Tareas rutinarias, bajo riesgo | Implementa y propone PR completo |

## Estructura completa

```
proyecto/
├── CLAUDE.md                          # Bootstrap para Claude Code
├── .cursorrules                       # Bootstrap para Cursor/Windsurf
├── AGENT_CONTEXT.md                   # Mapa de progressive disclosure
├── WORKING_STATE.md                   # Estado actual del trabajo
├── CHANGELOG.md                       # Historial de cambios
│
├── .product/                          # Cerebro del producto
│   ├── context/
│   │   ├── PRODUCT.md                 # Que es y para quien
│   │   ├── BUSINESS.md                # Modelo de negocio
│   │   ├── ROADMAP.md                 # Hacia donde va
│   │   └── DECISIONS.md               # ADRs (decisiones arquitectonicas)
│   ├── architecture/
│   │   ├── OVERVIEW.md                # Stack y estructura general
│   │   ├── COMPONENTS.md              # Detalle de componentes
│   │   └── RISKS.md                   # Riesgos y deuda tecnica
│   ├── operations/
│   │   ├── RUNBOOK.md                 # Procedimientos de deploy/rollback
│   │   └── RELEASE_CHECKLIST.md       # Checklist obligatorio pre-release
│   ├── security/
│   │   ├── SECURITY.md                # Politicas de seguridad
│   │   └── THREAT_MODEL.md            # Modelo de amenazas
│   ├── contracts/
│   │   └── AGENT_CONTRACT.md          # Autonomia y protocolos del agente
│   └── memory/
│       └── MEMORY.md                  # Hechos duraderos del producto
│
├── .claude/skills/                    # Skills modulares
│   ├── session-protocol/SKILL.md
│   ├── commit-and-pr/SKILL.md
│   └── adr/SKILL.md
│
├── scripts/
│   ├── sync-working-state.sh          # Sincroniza WORKING_STATE -> CLAUDE.md
│   ├── install-git-hooks.sh           # Instala git hooks de AXIS
│   └── validate-axis-tokens.sh        # Valida limites de tokens
│
└── git-hooks/
    └── pre-commit                     # Auto-sync en cada commit
```

## Scripts incluidos

| Script | Que hace | Cuando usarlo |
|--------|---------|---------------|
| `install-git-hooks.sh` | Copia los hooks de `git-hooks/` a `.git/hooks/` | Una vez despues de clonar |
| `sync-working-state.sh` | Inyecta el estado de `WORKING_STATE.md` en `CLAUDE.md` | Automatico via pre-commit hook |
| `validate-axis-tokens.sh` | Verifica que ningun archivo exceda su limite de tokens | Manual o en CI |

```bash
# Validar que todos los archivos estan dentro de limites
./scripts/validate-axis-tokens.sh --verbose

# Solo verificar (exit code 1 si falla, util para CI)
./scripts/validate-axis-tokens.sh --ci
```

## Compatible con

- **Claude Code** — usa `CLAUDE.md` (se auto-carga)
- **Cursor** — usa `.cursorrules` (se auto-carga)
- **Windsurf** — usa `.cursorrules` (se auto-carga)
- **Cualquier agente** — los archivos `.product/` son markdown estandar

## Licencia

MIT
