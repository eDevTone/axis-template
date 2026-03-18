#!/bin/bash
# init-project.sh
# Wizard interactivo de configuración para AXIS.
# - Auto-detecta stack desde package.json
# - Configura autonomía del agente (AGENT_CONTRACT.md)
# - Llena reglas inquebrantables en CLAUDE.md
# - Crea estructura de memoria (MEMORY.md + SESSION-STATE.md)
# - Busca e instala skills desde skills.sh según stack + README
#
# Uso (desde la raíz de tu proyecto con AXIS instalado):
#   bash scripts/init-project.sh

set -euo pipefail

# ─── Log de errores ───────────────────────────────────────────────────────────
LOG_FILE="/tmp/axis-init-$(date '+%Y%m%d-%H%M%S').log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Trap para mostrar el error y el log cuando falla
trap 'echo ""; echo -e "\033[0;31m✗ Error en línea $LINENO. Log completo en: $LOG_FILE\033[0m"; echo ""; echo "--- Últimas líneas del log ---"; tail -20 "$LOG_FILE"' ERR

SKILLS_DIR=".claude/skills"

# ─── Colores ─────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${BOLD}${BLUE}══════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${BLUE}  AXIS — Project Setup Wizard${NC}"
    echo -e "${BOLD}${BLUE}══════════════════════════════════════════════${NC}"
    echo ""
}

print_step() { echo ""; echo -e "${CYAN}${BOLD}▶ $1${NC}"; }
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_info() { echo -e "  ${BLUE}→${NC} $1"; }

ask() {
    local prompt="$1" default="${2:-}" var_name="$3"
    if [ -n "$default" ]; then
        echo -ne "${BOLD}$prompt${NC} ${YELLOW}[$default]${NC}: "
    else
        echo -ne "${BOLD}$prompt${NC}: "
    fi
    read -r input
    if [ -z "$input" ] && [ -n "$default" ]; then
        eval "$var_name=\"$default\""
    else
        eval "$var_name=\"$input\""
    fi
}

ask_multiselect() {
    local prompt="$1"; shift
    local options=("$@")
    echo -e "${BOLD}$prompt${NC}"
    for i in "${!options[@]}"; do
        echo -e "  ${CYAN}$((i+1))${NC}) ${options[$i]}"
    done
    echo -ne "${BOLD}Elige números separados por espacio (Enter para ninguno)${NC}: "
    read -r selection
    MULTISELECT_RESULT="$selection"
}

# ─── Verificaciones previas ───────────────────────────────────────────────────
check_requirements() {
    if [ ! -f "CLAUDE.md" ]; then
        print_error "No se encontró CLAUDE.md. ¿Estás en la raíz de un proyecto con AXIS instalado?"
        echo "Instala AXIS: curl -fsSL https://raw.githubusercontent.com/ManuelFeregrino/axis-template/main/scripts/install-axis.sh | bash"
        exit 1
    fi
    command -v node &> /dev/null && SKILLS_CLI_AVAILABLE=true || SKILLS_CLI_AVAILABLE=false
}

# ─── Auto-detectar stack desde package.json ───────────────────────────────────
autodetect_stack() {
    AUTO_DETECTED_STACK=()
    AUTO_DETECTED_LABELS=()

    if [ ! -f "package.json" ]; then
        return
    fi

    print_info "Leyendo package.json para detectar stack..."

    local pkg
    pkg=$(cat package.json)

    # Detección por dependencias
    echo "$pkg" | grep -qi '"next"' && AUTO_DETECTED_STACK+=("nextjs") && AUTO_DETECTED_LABELS+=("Next.js") || true
    echo "$pkg" | grep -qi '"react-native"' && AUTO_DETECTED_STACK+=("react-native") && AUTO_DETECTED_LABELS+=("React Native") || true
    (echo "$pkg" | grep -qi '"react"' && ! echo "$pkg" | grep -qi '"react-native"') && AUTO_DETECTED_STACK+=("react") && AUTO_DETECTED_LABELS+=("React") || true
    echo "$pkg" | grep -qi '"@nestjs/core"' && AUTO_DETECTED_STACK+=("nestjs") && AUTO_DETECTED_LABELS+=("NestJS") || true
    echo "$pkg" | grep -qi '"typescript"' && AUTO_DETECTED_STACK+=("typescript") && AUTO_DETECTED_LABELS+=("TypeScript") || true
    echo "$pkg" | grep -qi '"drizzle-orm"\|"prisma"\|"pg"\|"postgres"' && AUTO_DETECTED_STACK+=("postgres") && AUTO_DETECTED_LABELS+=("PostgreSQL") || true
    echo "$pkg" | grep -qi '"stripe"' && AUTO_DETECTED_STACK+=("stripe") && AUTO_DETECTED_LABELS+=("Stripe") || true
    echo "$pkg" | grep -qi '"@clerk\|next-auth\|@auth"' && AUTO_DETECTED_STACK+=("auth") && AUTO_DETECTED_LABELS+=("Auth") || true
    echo "$pkg" | grep -qi '"vitest"\|"jest"\|"playwright"\|"cypress"' && AUTO_DETECTED_STACK+=("testing") && AUTO_DETECTED_LABELS+=("Testing") || true
    echo "$pkg" | grep -qi '"tailwindcss"\|"@shadcn\|"@radix-ui"' && AUTO_DETECTED_STACK+=("design") && AUTO_DETECTED_LABELS+=("Design System / UI") || true
    echo "$pkg" | grep -qi '"viem"\|"wagmi"\|"ethers"' && AUTO_DETECTED_STACK+=("web3") && AUTO_DETECTED_LABELS+=("Web3") || true

    if [ "${#AUTO_DETECTED_LABELS[@]}" -gt 0 ]; then
        print_info "Stack detectado: ${GREEN}${AUTO_DETECTED_LABELS[*]}${NC}"
    fi
}

# ─── Extraer keywords del README/PRODUCT.md para búsqueda contextual ──────────
extract_context_keywords() {
    CONTEXT_KEYWORDS=""
    local source_file=""

    [ -f ".product/context/PRODUCT.md" ] && source_file=".product/context/PRODUCT.md"
    [ -z "$source_file" ] && [ -f "README.md" ] && source_file="README.md"

    if [ -n "$source_file" ]; then
        # Extraer palabras clave técnicas del archivo (primeras 50 líneas)
        CONTEXT_KEYWORDS=$(head -50 "$source_file" | \
            grep -oiE 'react|nextjs|next\.js|typescript|postgres|stripe|auth|api|saas|cfdi|factura|pos|mobile|web3|blockchain|testing|deploy' 2>/dev/null | \
            sort -u | tr '\n' ' ' | xargs || true)
        [ -n "$CONTEXT_KEYWORDS" ] && print_info "Keywords del proyecto: ${CYAN}$CONTEXT_KEYWORDS${NC}"
    fi
}

# ─── Skills desde skills.sh ───────────────────────────────────────────────────
search_skills() {
    local query="$1"
    npx --yes skills find "$query" 2>/dev/null \
        | grep -E '@' | grep -v '└' \
        | sed 's/\x1b\[[0-9;]*m//g' \
        | awk '{print $1}' | head -5 || true
}

install_skill() {
    local skill_ref="$1"
    local skill_name
    skill_name=$(echo "$skill_ref" | sed 's/.*@//')
    local target_dir="$SKILLS_DIR/$skill_name"

    if [ -d "$target_dir" ]; then
        print_warning "Skill '$skill_name' ya existe — omitido"
        return 0
    fi

    echo -e "  Instalando ${CYAN}$skill_ref${NC}..."
    npx --yes skills add "$skill_ref" 2>/dev/null && print_success "Instalado: $skill_name" || print_warning "No se pudo instalar: $skill_ref"
}

# ─── Reemplazar placeholders ──────────────────────────────────────────────────
replace_placeholders() {
    local file="$1" product_name="$2" phase="$3" author_name="$4"
    [ ! -f "$file" ] && return 0
    sed -i \
        -e "s/\[NOMBRE DEL PRODUCTO\]/$product_name/g" \
        -e "s/\[NOMBRE\]/$author_name/g" \
        -e "s/\[Construccion \/ Validacion \/ Produccion\]/$phase/g" \
        -e "s/\[que estamos haciendo ahora\]/Configuración inicial del proyecto/g" \
        -e "s|\[fecha + que cambio\]|$(date '+%Y-%m-%d') — Setup inicial|g" \
        -e "s|\[que sigue\]|Implementar primera feature|g" \
        "$file" 2>/dev/null || true
}

# ─── Inyectar reglas en CLAUDE.md ────────────────────────────────────────────
inject_rules_into_claude() {
    local rule1="$1" rule2="$2" rule3="$3"
    [ ! -f "CLAUDE.md" ] && return 0

    sed -i \
        -e "s|\[Regla de seguridad mas critica\]|$rule1|g" \
        -e "s|\[Restriccion arquitectonica fundamental\]|$rule2|g" \
        -e "s|\[Convencion obligatoria mas importante\]|$rule3|g" \
        "CLAUDE.md" 2>/dev/null || true
}

# ─── Crear AGENT_CONTRACT.md ─────────────────────────────────────────────────
setup_agent_contract() {
    local autonomy_level="$1"
    mkdir -p ".product/contracts"
    local contract_file=".product/contracts/AGENT_CONTRACT.md"

    case "$autonomy_level" in
        1) level_name="Explorador" level_desc="Propone opciones y espera aprobación antes de actuar. Ideal para proyectos en fase de diseño o con decisiones arquitectónicas abiertas." ;;
        2) level_name="Ejecutor" level_desc="Implementa features con specs claras y reporta al terminar. Nivel por defecto. Hace preguntas solo cuando hay ambigüedad real." ;;
        3) level_name="Piloto Automático" level_desc="Implementa, testea y propone PRs completos en tareas rutinarias de bajo riesgo. Máxima autonomía." ;;
        *) level_name="Ejecutor" level_desc="Implementa features con specs claras y reporta al terminar." ;;
    esac

    cat > "$contract_file" << EOF
# Agent Contract

## Nivel de Autonomía: $level_name

$level_desc

## Reglas de operación

### El agente PUEDE hacer sin pedir permiso:
- Leer archivos, explorar estructura, buscar en el código
- Crear archivos nuevos dentro de la estructura definida
- Refactorizar código sin cambiar comportamiento
- Escribir tests
- Actualizar WORKING_STATE.md y MEMORY.md

### El agente DEBE pedir permiso antes de:
- Modificar schemas de base de datos
- Cambiar contratos de API públicos
- Eliminar archivos
- Hacer commits o pushes a git
- Enviar cualquier request a APIs externas (excepto búsquedas)
- Cambiar dependencias en package.json

### El agente NUNCA debe:
- Exponer secrets, tokens, o credenciales
- Modificar archivos de configuración de seguridad sin revisión
- Ejecutar comandos destructivos (rm -rf, drop table, etc.)

## Niveles disponibles
| Nivel | Cuándo usar |
|-------|-------------|
| **Explorador** | Arquitectura, decisiones de diseño abiertas |
| **Ejecutor** ← actual | Features con specs claras |
| **Piloto Automático** | Tareas rutinarias, bajo riesgo |

## Generado
$(date '+%Y-%m-%d') via init-project.sh
EOF

    print_success "Creado $contract_file (nivel: $level_name)"
}

# ─── Crear estructura de memoria ─────────────────────────────────────────────
setup_memory_structure() {
    local product_name="$1" stack_str="$2"
    mkdir -p ".product/memory"

    # MEMORY.md
    if [ ! -f ".product/memory/MEMORY.md" ]; then
        cat > ".product/memory/MEMORY.md" << EOF
# $product_name — Memoria del Producto

> Hechos duraderos, decisiones vigentes, lecciones aprendidas.
> Mantener bajo 3,000 tokens. Archivar items obsoletos en MEMORY_ARCHIVE.md.

## Stack confirmado
$stack_str

## Decisiones clave
(llenar conforme avanza el proyecto)

## Lecciones aprendidas
(documentar errores y soluciones importantes)

## Convenciones del proyecto
(patrones de código, naming, estructura acordada)

## Creado
$(date '+%Y-%m-%d') via init-project.sh
EOF
        print_success "Creado .product/memory/MEMORY.md"
    else
        print_warning ".product/memory/MEMORY.md ya existe — no sobreescrito"
    fi

    # SESSION-STATE.md (WAL — Write-Ahead Log)
    if [ ! -f ".product/memory/SESSION-STATE.md" ]; then
        cat > ".product/memory/SESSION-STATE.md" << EOF
# SESSION-STATE — Estado Activo

> Estado operativo de la sesión actual. Se sobrescribe cada sesión.
> Usar como WAL: escribir correcciones y decisiones ANTES de responder.

## Tarea actual
(ninguna — proyecto recién inicializado)

## Decisiones de esta sesión
(vacío)

## Correcciones recibidas
(vacío)

## Bloqueantes
(ninguno)

## Última actualización
$(date '+%Y-%m-%d %H:%M')
EOF
        print_success "Creado .product/memory/SESSION-STATE.md"
    else
        print_warning ".product/memory/SESSION-STATE.md ya existe — no sobreescrito"
    fi
}

# ─── Crear archivos .product/context/ ────────────────────────────────────────
setup_product_files() {
    local product_name="$1" product_desc="$2" target_audience="$3" stack_str="$4"
    mkdir -p ".product/context" ".product/architecture"

    cat > ".product/context/PRODUCT.md" << EOF
# $product_name

## Qué es
$product_desc

## Para quién
$target_audience

## Stack
$stack_str

## Generado
$(date '+%Y-%m-%d') via init-project.sh
EOF
    print_success "Creado .product/context/PRODUCT.md"

    if [ ! -f ".product/architecture/OVERVIEW.md" ]; then
        cat > ".product/architecture/OVERVIEW.md" << EOF
# $product_name — Architecture Overview

## Stack
$stack_str

## Estructura
\`\`\`
(llenar con la estructura real del proyecto)
\`\`\`

## Patrones principales
(describir patrones arquitectónicos usados)

## Generado
$(date '+%Y-%m-%d') via init-project.sh — completar manualmente
EOF
        print_success "Creado .product/architecture/OVERVIEW.md"
    else
        print_warning ".product/architecture/OVERVIEW.md ya existe — no sobreescrito"
    fi
}

# ─── MAIN ─────────────────────────────────────────────────────────────────────
main() {
    print_header
    check_requirements

    # ── Paso 1: Info del proyecto ──────────────────────────────────────────
    print_step "1/5 — Información del proyecto"

    ask "Nombre del producto" "" PRODUCT_NAME
    [ -z "$PRODUCT_NAME" ] && print_error "El nombre es obligatorio." && exit 1

    ask "Descripción corta (qué hace y para quién)" "" PRODUCT_DESC
    ask "Audiencia objetivo" "desarrolladores / pequeñas empresas" TARGET_AUDIENCE
    ask "Tu nombre" "" AUTHOR_NAME

    echo ""
    echo -e "${BOLD}Fase del proyecto:${NC}"
    echo "  1) Construccion"
    echo "  2) Validacion"
    echo "  3) Produccion"
    ask "Fase" "1" PHASE_NUM
    case "$PHASE_NUM" in
        1) PHASE="Construccion" ;;
        2) PHASE="Validacion" ;;
        3) PHASE="Produccion" ;;
        *) PHASE="Construccion" ;;
    esac

    # ── Paso 2: Reglas + Autonomía ─────────────────────────────────────────
    print_step "2/5 — Reglas del proyecto y autonomía del agente"

    echo ""
    echo -e "${BOLD}Define las 3 reglas inquebrantables del proyecto:${NC}"
    echo -e "  ${YELLOW}(Estas van directo en CLAUDE.md — el agente las respetará siempre)${NC}"
    echo ""
    ask "Regla 1 — Seguridad crítica" "Nunca exponer secrets ni credenciales en código" RULE1
    ask "Regla 2 — Restricción arquitectónica" "Respetar la estructura de features definida" RULE2
    ask "Regla 3 — Convención obligatoria" "Todo el código en TypeScript strict mode" RULE3

    echo ""
    echo -e "${BOLD}Nivel de autonomía del agente:${NC}"
    echo "  1) Explorador    — propone opciones, espera aprobación"
    echo "  2) Ejecutor      — implementa con specs claras, reporta (recomendado)"
    echo "  3) Piloto Auto   — máxima autonomía en tareas rutinarias"
    ask "Nivel" "2" AUTONOMY_LEVEL

    # ── Paso 3: Stack (con auto-detección) ────────────────────────────────
    print_step "3/5 — Stack tecnológico"

    autodetect_stack
    extract_context_keywords

    TECH_OPTIONS=(
        "Next.js"
        "React"
        "React Native"
        "Node.js / NestJS"
        "TypeScript"
        "PostgreSQL"
        "Stripe"
        "Auth (Clerk/NextAuth)"
        "AWS"
        "Vercel"
        "Docker / DevOps"
        "Testing"
        "Design System / UI"
        "Web3 / Blockchain"
    )

    TECH_KEYS=("nextjs" "react" "react-native" "nestjs" "typescript" "postgres" "stripe" "auth" "aws" "vercel" "docker" "testing" "design" "web3")

    TECH_QUERIES=(
        "react nextjs"
        "react"
        "react native"
        "node typescript api"
        "typescript"
        "postgres database"
        "stripe billing"
        "auth authentication"
        "aws deploy"
        "vercel deploy"
        "docker devops ci-cd"
        "testing"
        "design ui"
        "web3 blockchain"
    )

    if [ "${#AUTO_DETECTED_LABELS[@]}" -gt 0 ]; then
        echo ""
        echo -e "  ${GREEN}Auto-detectado desde package.json:${NC} ${AUTO_DETECTED_LABELS[*]}"
        ask "¿Usar stack auto-detectado? (s/n)" "s" USE_AUTO
        if [[ "$USE_AUTO" =~ ^[sS]$ ]]; then
            SELECTED_INDICES=()
            for auto_key in "${AUTO_DETECTED_STACK[@]}"; do
                for i in "${!TECH_KEYS[@]}"; do
                    [ "${TECH_KEYS[$i]}" = "$auto_key" ] && SELECTED_INDICES+=("$i")
                done
            done
            STACK_DISPLAY="${AUTO_DETECTED_LABELS[*]}"
            STACK_STR="$STACK_DISPLAY"
        else
            ask_multiselect "¿Qué tecnologías usas?" "${TECH_OPTIONS[@]}"
            SELECTED_INDICES=()
            STACK_DISPLAY=""
            for num in $MULTISELECT_RESULT; do
                idx=$((num - 1))
                [ "$idx" -ge 0 ] && [ "$idx" -lt "${#TECH_OPTIONS[@]}" ] && \
                    SELECTED_INDICES+=("$idx") && STACK_DISPLAY="$STACK_DISPLAY ${TECH_OPTIONS[$idx]},"
            done
            STACK_STR="${STACK_DISPLAY%,}"
        fi
    else
        ask_multiselect "¿Qué tecnologías usas?" "${TECH_OPTIONS[@]}"
        SELECTED_INDICES=()
        STACK_DISPLAY=""
        for num in $MULTISELECT_RESULT; do
            idx=$((num - 1))
            [ "$idx" -ge 0 ] && [ "$idx" -lt "${#TECH_OPTIONS[@]}" ] && \
                SELECTED_INDICES+=("$idx") && STACK_DISPLAY="$STACK_DISPLAY ${TECH_OPTIONS[$idx]},"
        done
        STACK_STR="${STACK_DISPLAY%,}"
    fi

    echo ""
    echo -e "Stack: ${GREEN}${STACK_STR}${NC}"

    # ── Paso 4: Skills desde skills.sh ────────────────────────────────────
    print_step "4/5 — Skills desde skills.sh"

    declare -a ALL_FOUND_SKILLS=()

    if [ "$SKILLS_CLI_AVAILABLE" = true ] && [ "${#SELECTED_INDICES[@]}" -gt 0 ]; then
        declare -a SKILL_SEARCH_RESULTS=()

        # Búsqueda por stack
        for idx in "${SELECTED_INDICES[@]}"; do
            query="${TECH_QUERIES[$idx]}"
            label="${TECH_OPTIONS[$idx]}"
            echo ""
            echo -e "  ${BOLD}→ Skills para ${CYAN}$label${NC}:"
            while IFS= read -r skill_ref; do
                [ -z "$skill_ref" ] && continue
                skill_name=$(echo "$skill_ref" | sed 's/.*@//')
                existing=""
                [ -d "$SKILLS_DIR/$skill_name" ] && existing=" ${YELLOW}(ya instalado)${NC}"
                echo -e "    • $skill_ref$existing"
                SKILL_SEARCH_RESULTS+=("$skill_ref")
            done < <(search_skills "$query")
        done

        # Búsqueda adicional por keywords del README/PRODUCT.md
        if [ -n "${CONTEXT_KEYWORDS:-}" ]; then
            echo ""
            echo -e "  ${BOLD}→ Skills por keywords del proyecto (${CYAN}$CONTEXT_KEYWORDS${NC}${BOLD}):${NC}"
            while IFS= read -r skill_ref; do
                [ -z "$skill_ref" ] && continue
                # Evitar duplicados
                already=false
                for existing_skill in "${SKILL_SEARCH_RESULTS[@]:-}"; do
                    [ "$existing_skill" = "$skill_ref" ] && already=true && break
                done
                $already && continue
                skill_name=$(echo "$skill_ref" | sed 's/.*@//')
                existing=""
                [ -d "$SKILLS_DIR/$skill_name" ] && existing=" ${YELLOW}(ya instalado)${NC}"
                echo -e "    • $skill_ref$existing"
                SKILL_SEARCH_RESULTS+=("$skill_ref")
            done < <(search_skills "$CONTEXT_KEYWORDS")
        fi

        ALL_FOUND_SKILLS=("${SKILL_SEARCH_RESULTS[@]:-}")

        if [ "${#ALL_FOUND_SKILLS[@]}" -gt 0 ]; then
            echo ""
            ask "¿Instalar todos los skills encontrados? (s/n)" "s" INSTALL_ALL

            if [[ "$INSTALL_ALL" =~ ^[sS]$ ]]; then
                SKILLS_TO_INSTALL=("${ALL_FOUND_SKILLS[@]}")
            else
                # Mostrar numerados para selección
                echo ""
                declare -a UNIQUE_SKILLS=()
                declare -A seen_skills
                for s in "${ALL_FOUND_SKILLS[@]}"; do
                    [ -z "${seen_skills[$s]:-}" ] && UNIQUE_SKILLS+=("$s") && seen_skills[$s]=1
                done
                ask_multiselect "¿Cuáles instalar?" "${UNIQUE_SKILLS[@]}"
                SKILLS_TO_INSTALL=()
                for num in $MULTISELECT_RESULT; do
                    idx=$((num - 1))
                    [ "$idx" -ge 0 ] && [ "$idx" -lt "${#UNIQUE_SKILLS[@]}" ] && \
                        SKILLS_TO_INSTALL+=("${UNIQUE_SKILLS[$idx]}")
                done
            fi

            echo ""
            for skill_ref in "${SKILLS_TO_INSTALL[@]:-}"; do
                [ -n "$skill_ref" ] && install_skill "$skill_ref"
            done
        fi
    else
        print_warning "Sin Node.js o sin stack seleccionado. Busca skills después: npx skills find <query>"
    fi

    # ── Paso 5: Aplicar todo ───────────────────────────────────────────────
    print_step "5/5 — Aplicando configuración"

    for f in "CLAUDE.md" "AGENT_CONTEXT.md" "WORKING_STATE.md"; do
        replace_placeholders "$f" "$PRODUCT_NAME" "$PHASE" "$AUTHOR_NAME"
        [ -f "$f" ] && print_success "$f actualizado"
    done

    inject_rules_into_claude "$RULE1" "$RULE2" "$RULE3"
    print_success "Reglas inyectadas en CLAUDE.md"

    setup_agent_contract "$AUTONOMY_LEVEL"
    setup_memory_structure "$PRODUCT_NAME" "$STACK_STR"
    setup_product_files "$PRODUCT_NAME" "$PRODUCT_DESC" "$TARGET_AUDIENCE" "$STACK_STR"

    # ── Resumen ────────────────────────────────────────────────────────────
    echo ""
    echo -e "${BOLD}${GREEN}══════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${GREEN}  ✓ $PRODUCT_NAME listo para trabajar${NC}"
    echo -e "${BOLD}${GREEN}══════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${BOLD}Fase:${NC}       $PHASE"
    echo -e "  ${BOLD}Stack:${NC}      $STACK_STR"
    echo -e "  ${BOLD}Autonomía:${NC}  $(case $AUTONOMY_LEVEL in 1) echo Explorador;; 3) echo "Piloto Automático";; *) echo Ejecutor;; esac)"
    echo -e "  ${BOLD}Skills:${NC}     $(ls $SKILLS_DIR 2>/dev/null | wc -l) instalados en $SKILLS_DIR/"
    echo ""
    echo -e "  ${BOLD}Archivos creados:${NC}"
    echo -e "  • CLAUDE.md + AGENT_CONTEXT.md + WORKING_STATE.md (placeholders reemplazados)"
    echo -e "  • .product/contracts/AGENT_CONTRACT.md"
    echo -e "  • .product/memory/MEMORY.md"
    echo -e "  • .product/memory/SESSION-STATE.md"
    echo -e "  • .product/context/PRODUCT.md"
    echo -e "  • .product/architecture/OVERVIEW.md"
    echo ""
    echo -e "  ${BOLD}Próximos pasos:${NC}"
    echo -e "  1. Revisa ${CYAN}CLAUDE.md${NC} → verifica las reglas inyectadas"
    echo -e "  2. Completa ${CYAN}.product/architecture/OVERVIEW.md${NC} con tu estructura real"
    echo -e "  3. ${CYAN}git add . && git commit -m 'init: configure AXIS for $PRODUCT_NAME'${NC}"
    echo ""
    echo -e "  Más skills: ${CYAN}npx skills find <query>${NC}"
    echo ""
}

main "$@"
