.PHONY: init update help

init:
	@bash scripts/init-project.sh

update:
	@bash scripts/update-axis.sh

help:
	@echo ""
	@echo "AXIS — Comandos disponibles"
	@echo "─────────────────────────────"
	@echo "  make init    → Configurar proyecto (wizard interactivo)"
	@echo "  make update  → Actualizar AXIS desde el template"
	@echo "  make help    → Mostrar esta ayuda"
	@echo ""
