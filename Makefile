.PHONY: run stop install logs clean

run:
	@echo "Ejecutando start_all.sh..."
	@bash scripts/start_all.sh

stop:
	@echo "Deteniendo servicios en ejecución..."
	@pkill -f "prometheus --config.file" || true
	@pkill -f "node_exporter" || true
	@pkill -f "nvidia_exporter.py" || true
	@pkill -f "grafana-server" || true
	@echo "Servicios detenidos."

install:
	@echo "Instalando dependencias..."
	@bash scripts/install_dependencies.sh

logs:
	@echo "Mostrando logs..."
	@tail -f logs/*.log

clean:
	@echo "Limpiando logs..."
	@rm -rf logs/*
	@echo "Logs limpiados."
