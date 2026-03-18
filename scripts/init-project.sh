#!/bin/bash
# init-project.sh
# Wizard interactivo de configuración para AXIS.
# Llena los placeholders, detecta tu stack, y sugiere skills desde skills.ws.
#
# Uso (desde la raíz de tu proyecto con AXIS instalado):
#   bash scripts/init-project.sh

set -euo pipefail

SKILLS_API="https://www.skills.ws/skills.json"
SKILLS_DIR=".claude/skills"

# ─── Colores ────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ─── Helpers ─────────────────────────────────────────────────────────────────
print_header() {
    echo ""
    echo -e "${BOLD}${BLUE}══════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${BLUE}  AXIS — Project Setup Wizard${NC}"
    echo -e "${BOLD}${BLUE}══════════════════════════════════════════════${NC}"
    echo ""
}

print_step() {
    echo ""
    echo -e "${CYAN}${BOLD}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

ask() {
    local prompt="$1"
    local default="${2:-}"
    local var_name="$3"

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
    # Muestra opciones numeradas y el usuario escribe los números separados por espacio
    local prompt="$1"
    shift
    local options=("$@")

    echo -e "${BOLD}$prompt${NC}"
    for i in "${!options[@]}"; do
        echo -e "  ${CYAN}$((i+1))${NC}) ${options[$i]}"
    done
    echo -ne "${BOLD}Elige números separados por espacio (ej: 1 3 5) o Enter para ninguno${NC}: "
    read -r selection
    MULTISELECT_RESULT="$selection"
}

# ─── Verificaciones previas ───────────────────────────────────────────────────
check_requirements() {
    if [ ! -f "CLAUDE.md" ]; then
        print_error "No se encontró CLAUDE.md. ¿Estás en la raíz de un proyecto con AXIS instalado?"
        echo "Instala AXIS primero: curl -fsSL https://raw.githubusercontent.com/ManuelFeregrino/axis-template/main/scripts/install-axis.sh | bash"
        exit 1
    fi

    if ! command -v curl &> /dev/null; then
        print_error "curl no está instalado. Necesario para descargar skills."
        exit 1
    fi
}

# ─── Fetch skills desde skills.ws ────────────────────────────────────────────
fetch_skills_catalog() {
    print_step "Descargando catálogo de skills desde skills.ws..."
    SKILLS_JSON=$(curl -s --max-time 10 "$SKILLS_API" 2>/dev/null || echo "")

    if [ -z "$SKILLS_JSON" ]; then
        print_warning "No se pudo conectar a skills.ws. Se omitirá la sugerencia de skills."
        SKILLS_AVAILABLE=false
    else
        print_success "Catálogo cargado"
        SKILLS_AVAILABLE=true
    fi
}

# ─── Matching de stack → skills ──────────────────────────────────────────────
get_skills_for_stack() {
    local stack_choices="$1"
    SUGGESTED_SKILLS=()

    # Mapa de stack → skills relevantes en skills.ws
    declare -A STACK_SKILL_MAP
    STACK_SKILL_MAP["nextjs"]="nextjs-stack nextjs-performance web-performance"
    STACK_SKILL_MAP["react"]="nextjs-stack design-system ui-ux-pro-max"
    STACK_SKILL_MAP["react-native"]="ui-ux-pro-max design-system"
    STACK_SKILL_MAP["node"]="api-design database-design security-hardening"
    STACK_SKILL_MAP["nestjs"]="api-design database-design security-hardening"
    STACK_SKILL_MAP["postgres"]="postgres-mastery database-design"
    STACK_SKILL_MAP["typescript"]="testing-strategy git-workflow"
    STACK_SKILL_MAP["stripe"]="stripe-billing saas-billing"
    STACK_SKILL_MAP["auth"]="auth-implementation security-hardening"
    STACK_SKILL_MAP["aws"]="aws-production-deploy docker-production monitoring-observability"
    STACK_SKILL_MAP["vercel"]="nextjs-performance ci-cd-pipeline"
    STACK_SKILL_MAP["docker"]="docker-production monitoring-observability"
    STACK_SKILL_MAP["testing"]="testing-strategy"
    STACK_SKILL_MAP["web3"]="solidity-dev wallet-integration defi-integration"

    declare -A added_skills

    for tech in $stack_choices; do
        tech_lower=$(echo "$tech" | tr '[:upper:]' '[:lower:]')
        if [ -n "${STACK_SKILL_MAP[$tech_lower]:-}" ]; then
            for skill in ${STACK_SKILL_MAP[$tech_lower]}; do
                if [ -z "${added_skills[$skill]:-}" ]; then
                    SUGGESTED_SKILLS+=("$skill")
                    added_skills[$skill]=1
                fi
            done
        fi
    done
}

# ─── Instalar un skill desde skills.ws ───────────────────────────────────────
install_skill_from_skills_ws() {
    local skill_name="$1"
    local target_dir="$SKILLS_DIR/$skill_name"

    # Verificar si ya existe (no sobreescribir)
    if [ -d "$target_dir" ]; then
        print_warning "Skill '$skill_name' ya existe en $target_dir — omitido (no se sobreescribe)"
        return 0
    fi

    # Obtener contenido del skill desde la API
    local content
    content=$(echo "$SKILLS_JSON" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for skill in data.get('skills', []):
    if skill['name'] == '$skill_name':
        print(skill.get('content', ''))
        sys.exit(0)
sys.exit(1)
" 2>/dev/null || echo "")

    if [ -z "$content" ]; then
        print_warning "No se encontró contenido para skill '$skill_name'"
        return 1
    fi

    mkdir -p "$target_dir"
    echo "$content" > "$target_dir/SKILL.md"
    print_success "Skill '$skill_name' instalado en $target_dir"
}

# ─── Reemplazar placeholders en archivos ─────────────────────────────────────
replace_placeholders() {
    local file="$1"
    local product_name="$2"
    local product_desc="$3"
    local stack_str="$4"
    local phase="$5"
    local author_name="$6"

    if [ ! -f "$file" ]; then
        return 0
    fi

    # Usar sed para reemplazar placeholders
    sed -i \
        -e "s/\[NOMBRE DEL PRODUCTO\]/$product_name/g" \
        -e "s/\[NOMBRE\]/$author_name/g" \
        -e "s/\[Construccion \/ Validacion \/ Produccion\]/$phase/g" \
        -e "s/\[que estamos haciendo ahora\]/Configuración inicial del proyecto/g" \
        -e "s|\[fecha + que cambio\]|$(date '+%Y-%m-%d') — Setup inicial|g" \
        -e "s|\[que sigue\]|Implementar primera feature|g" \
        "$file" 2>/dev/null || true
}

# ─── Crear/actualizar .product/context/PRODUCT.md ────────────────────────────
setup_product_md() {
    local product_name="$1"
    local product_desc="$2"
    local target_audience="$3"
    local stack_str="$4"

    local product_file=".product/context/PRODUCT.md"
    mkdir -p ".product/context"

    cat > "$product_file" << EOF
# $product_name — Producto

## Qué es
$product_desc

## Para quién
$target_audience

## Stack
$stack_str

## Generado
$(date '+%Y-%m-%d') via init-project.sh
EOF

    print_success "Creado $product_file"
}

# ─── Crear/actualizar .product/architecture/OVERVIEW.md ──────────────────────
setup_overview_md() {
    local product_name="$1"
    local stack_str="$2"

    local overview_file=".product/architecture/OVERVIEW.md"
    mkdir -p ".product/architecture"

    if [ ! -f "$overview_file" ]; then
        cat > "$overview_file" << EOF
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
        print_success "Creado $overview_file (completar manualmente)"
    else
        print_warning "$overview_file ya existe — no sobreescrito"
    fi
}

# ─── MAIN ─────────────────────────────────────────────────────────────────────
main() {
    print_header
    check_requirements
    fetch_skills_catalog

    # ── Paso 1: Info del proyecto ──────────────────────────────────────────
    print_step "1/4 — Información del proyecto"

    ask "Nombre del producto" "" PRODUCT_NAME
    if [ -z "$PRODUCT_NAME" ]; then
        print_error "El nombre del producto es obligatorio."
        exit 1
    fi

    ask "Descripción corta (1 línea: qué hace y para quién)" "" PRODUCT_DESC
    ask "Audiencia objetivo" "desarrolladores / pequeñas empresas" TARGET_AUDIENCE
    ask "Tu nombre (para los placeholders [NOMBRE])" "" AUTHOR_NAME

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

    # ── Paso 2: Stack tecnológico ──────────────────────────────────────────
    print_step "2/4 — Stack tecnológico"

    TECH_OPTIONS=(
        "Next.js"
        "React"
        "React Native"
        "Node.js"
        "NestJS"
        "TypeScript"
        "PostgreSQL"
        "Stripe"
        "Auth (Clerk/Auth.js/NextAuth)"
        "AWS"
        "Vercel"
        "Docker"
        "Testing"
        "Web3/Blockchain"
    )

    ask_multiselect "¿Qué tecnologías usas? (escribe los números)" "${TECH_OPTIONS[@]}"

    SELECTED_STACK=()
    STACK_KEYS=("nextjs" "react" "react-native" "node" "nestjs" "typescript" "postgres" "stripe" "auth" "aws" "vercel" "docker" "testing" "web3")
    STACK_DISPLAY=""

    for num in $MULTISELECT_RESULT; do
        idx=$((num - 1))
        if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#TECH_OPTIONS[@]}" ]; then
            SELECTED_STACK+=("${STACK_KEYS[$idx]}")
            STACK_DISPLAY="$STACK_DISPLAY ${TECH_OPTIONS[$idx]},"
        fi
    done

    STACK_STR="${STACK_DISPLAY%, }"
    echo ""
    echo -e "Stack seleccionado: ${GREEN}${STACK_STR}${NC}"

    # ── Paso 3: Skills sugeridos ───────────────────────────────────────────
    print_step "3/4 — Skills recomendados para tu stack"

    if [ "$SKILLS_AVAILABLE" = true ] && [ "${#SELECTED_STACK[@]}" -gt 0 ]; then
        get_skills_for_stack "${SELECTED_STACK[*]}"

        if [ "${#SUGGESTED_SKILLS[@]}" -gt 0 ]; then
            echo ""
            echo -e "Skills recomendados desde ${CYAN}skills.ws${NC}:"
            echo ""
            for i in "${!SUGGESTED_SKILLS[@]}"; do
                skill="${SUGGESTED_SKILLS[$i]}"
                existing=""
                [ -d "$SKILLS_DIR/$skill" ] && existing=" ${YELLOW}(ya instalado)${NC}"
                echo -e "  ${CYAN}$((i+1))${NC}) ${BOLD}$skill${NC}$existing"
            done

            echo ""
            ask "¿Instalar todos los sugeridos? (s/n)" "s" INSTALL_ALL

            if [[ "$INSTALL_ALL" =~ ^[sS]$ ]]; then
                SKILLS_TO_INSTALL=("${SUGGESTED_SKILLS[@]}")
            else
                echo ""
                ask_multiselect "¿Cuáles instalar?" "${SUGGESTED_SKILLS[@]}"
                SKILLS_TO_INSTALL=()
                for num in $MULTISELECT_RESULT; do
                    idx=$((num - 1))
                    if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#SUGGESTED_SKILLS[@]}" ]; then
                        SKILLS_TO_INSTALL+=("${SUGGESTED_SKILLS[$idx]}")
                    fi
                done
            fi

            echo ""
            echo -e "${BOLD}Instalando skills...${NC}"
            for skill in "${SKILLS_TO_INSTALL[@]}"; do
                install_skill_from_skills_ws "$skill"
            done
        else
            print_warning "No se encontraron skills específicos para tu stack en skills.ws."
        fi
    else
        print_warning "Sin conexión a skills.ws o stack no seleccionado — saltando sugerencias."
    fi

    # ── Paso 4: Aplicar configuración ─────────────────────────────────────
    print_step "4/4 — Aplicando configuración"

    replace_placeholders "CLAUDE.md" "$PRODUCT_NAME" "$PRODUCT_DESC" "$STACK_STR" "$PHASE" "$AUTHOR_NAME"
    print_success "CLAUDE.md actualizado"

    replace_placeholders "AGENT_CONTEXT.md" "$PRODUCT_NAME" "$PRODUCT_DESC" "$STACK_STR" "$PHASE" "$AUTHOR_NAME"
    print_success "AGENT_CONTEXT.md actualizado"

    replace_placeholders "WORKING_STATE.md" "$PRODUCT_NAME" "$PRODUCT_DESC" "$STACK_STR" "$PHASE" "$AUTHOR_NAME"
    print_success "WORKING_STATE.md actualizado"

    setup_product_md "$PRODUCT_NAME" "$PRODUCT_DESC" "$TARGET_AUDIENCE" "$STACK_STR"
    setup_overview_md "$PRODUCT_NAME" "$STACK_STR"

    # ── Resumen final ──────────────────────────────────────────────────────
    echo ""
    echo -e "${BOLD}${GREEN}══════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${GREEN}  ✓ Proyecto configurado: $PRODUCT_NAME${NC}"
    echo -e "${BOLD}${GREEN}══════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${BOLD}Fase:${NC}   $PHASE"
    echo -e "  ${BOLD}Stack:${NC}  $STACK_STR"
    echo ""
    echo -e "  ${BOLD}Próximos pasos:${NC}"
    echo -e "  1. Revisa ${CYAN}CLAUDE.md${NC} y ajusta las Reglas Inquebrantables"
    echo -e "  2. Llena ${CYAN}.product/context/PRODUCT.md${NC} con más detalle"
    echo -e "  3. Completa ${CYAN}.product/architecture/OVERVIEW.md${NC} con tu estructura real"
    echo -e "  4. Haz commit: ${CYAN}git add . && git commit -m 'init: configure AXIS for $PRODUCT_NAME'${NC}"
    echo ""
    echo -e "  ${BOLD}Skills instalados:${NC} $(ls $SKILLS_DIR 2>/dev/null | wc -l) en total"
    echo ""
}

main "$@"
