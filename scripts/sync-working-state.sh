#!/bin/bash
# sync-working-state.sh
# Sincroniza el estado de WORKING_STATE.md en la seccion "Estado Actual" de
# CLAUDE.md y .cursorrules (si existe).
#
# Por que existe este script?
# Claude Code SOLO auto-carga CLAUDE.md. Cursor/Windsurf solo auto-cargan
# .cursorrules. WORKING_STATE.md NO se auto-carga — depende de que el agente
# siga la instruccion y lo lea activamente.
# Este script inyecta las primeras lineas de WORKING_STATE.md directamente
# en ambos archivos bootstrap para que el estado siempre este auto-cargado.
#
# Cuando se ejecuta:
# - Automaticamente como git pre-commit hook
# - Manualmente: ./scripts/sync-working-state.sh
#
# Que hace:
# 1. Lee las secciones clave de WORKING_STATE.md
# 2. Genera un resumen compacto (max ~300 tokens)
# 3. Reemplaza la seccion "## Estado Actual" en CLAUDE.md y .cursorrules
# 4. Si los archivos cambiaron, los agrega al commit automaticamente
#
# Uso:
#   ./scripts/sync-working-state.sh              # Sincronizar
#   ./scripts/sync-working-state.sh --dry-run     # Ver que cambiaria
#   ./scripts/sync-working-state.sh --check        # Solo verificar si esta desincronizado

set -euo pipefail

CLAUDE_FILE="CLAUDE.md"
CURSORRULES_FILE=".cursorrules"
WORKING_STATE_FILE="WORKING_STATE.md"
MODE="sync"

case "${1:-}" in
    --dry-run) MODE="dry-run" ;;
    --check)   MODE="check" ;;
    --help|-h)
        echo "Uso: $0 [--dry-run|--check|--help]"
        echo ""
        echo "  (sin args)   Sincronizar WORKING_STATE.md -> CLAUDE.md + .cursorrules"
        echo "  --dry-run    Ver que cambiaria sin aplicar"
        echo "  --check      Verificar si estan desincronizados (exit 1 si si)"
        echo "  --help       Mostrar esta ayuda"
        exit 0
        ;;
esac

if [ ! -f "$WORKING_STATE_FILE" ]; then
    echo "  $WORKING_STATE_FILE no encontrado — omitiendo sync"
    exit 0
fi

# Extraer contenido entre headers de WORKING_STATE.md
extract_section() {
    local file="$1"
    local header="$2"
    sed -n "/^## ${header}/,/^## /{ /^## ${header}/d; /^## /d; p; }" "$file" | head -5 | sed '/^$/d' | sed 's/^[[:space:]]*//'
}

EN_PROGRESO=$(extract_section "$WORKING_STATE_FILE" "En Progreso")
PROXIMA=$(extract_section "$WORKING_STATE_FILE" "Proxima Sesion")
BLOCKERS=$(extract_section "$WORKING_STATE_FILE" "Blockers")

# Si no hay contenido util, usar defaults
[ -z "$EN_PROGRESO" ] && EN_PROGRESO="- Sin tareas en progreso"
[ -z "$PROXIMA" ] && PROXIMA="- Sin proximos pasos definidos"

# Construir el bloque de estado (compacto, ~300 tokens max)
NEW_STATE="## Estado Actual"
NEW_STATE+="\n- En progreso: $(echo "$EN_PROGRESO" | head -1 | sed 's/^- //')"
NEW_STATE+="\n- Proximo: $(echo "$PROXIMA" | head -1 | sed 's/^- \[ \] //')"

# Solo agregar blockers si existen y no son "Ninguno"
if [ -n "$BLOCKERS" ] && ! echo "$BLOCKERS" | grep -qi "ningun"; then
    NEW_STATE+="\n- Blocker: $(echo "$BLOCKERS" | head -1 | sed 's/^- //')"
fi

NEW_STATE+="\n- Ultimo sync: $(date +%Y-%m-%d)"

# Funcion: sincronizar un archivo bootstrap individual
sync_target() {
    local target_file="$1"

    if [ ! -f "$target_file" ]; then
        return
    fi

    if ! grep -q "^## Estado Actual" "$target_file"; then
        return
    fi

    local current_state
    current_state=$(sed -n '/^## Estado Actual/,/^## /{ /^## Estado Actual/p; /^## [^E]/d; /^## Estado Actual/d; p; }' "$target_file")

    case "$MODE" in
        "check")
            local current_normalized new_normalized
            current_normalized=$(echo "$current_state" | sed '/^$/d' | sed 's/^[[:space:]]*//')
            new_normalized=$(echo -e "$NEW_STATE" | sed '/^$/d' | sed 's/^[[:space:]]*//' | tail -n +2)

            if [ "$current_normalized" != "$new_normalized" ]; then
                echo "$target_file esta desincronizado con WORKING_STATE.md"
                CHECK_FAILED=1
            else
                echo "$target_file esta sincronizado con WORKING_STATE.md"
            fi
            ;;

        "dry-run")
            echo "--- $target_file ---"
            echo "Seccion '## Estado Actual' se reemplazaria con:"
            echo -e "$NEW_STATE"
            echo ""
            ;;

        "sync")
            local tmp_file state_file
            tmp_file=$(mktemp)
            state_file=$(mktemp)
            echo -e "$NEW_STATE" > "$state_file"

            STATE_FILE="$state_file" awk '
            /^## Estado Actual/ {
                while ((getline line < ENVIRON["STATE_FILE"]) > 0) print line
                close(ENVIRON["STATE_FILE"])
                skip = 1
                next
            }
            /^## / && skip {
                skip = 0
            }
            !skip {
                print
            }
            ' "$target_file" > "$tmp_file"

            rm -f "$state_file"

            if diff -q "$target_file" "$tmp_file" > /dev/null 2>&1; then
                echo "$target_file ya esta sincronizado — sin cambios"
                rm "$tmp_file"
            else
                mv "$tmp_file" "$target_file"
                echo "$target_file actualizado con estado de WORKING_STATE.md"

                if [ -n "${GIT_INDEX_FILE:-}" ]; then
                    git add "$target_file"
                    echo "   -> $target_file agregado al commit automaticamente"
                fi
            fi
            ;;
    esac
}

CHECK_FAILED=0

# Sincronizar ambos archivos bootstrap
sync_target "$CLAUDE_FILE"
sync_target "$CURSORRULES_FILE"

if [ "$MODE" = "check" ] && [ "$CHECK_FAILED" -eq 1 ]; then
    exit 1
fi
