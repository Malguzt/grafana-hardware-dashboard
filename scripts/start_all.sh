#!/bin/bash

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="$BASE_DIR/bin"
CONFIG_DIR="$BASE_DIR/config"
LOG_DIR="$BASE_DIR/logs"

mkdir -p "$LOG_DIR"

# Kill running instances if any (simple kill, strictly filtering by path/names would be better but this is a local user script)
pkill -f "prometheus --config.file=$CONFIG_DIR/prometheus.yml" || true
pkill -f "node_exporter" || true
pkill -f "python3 $BASE_DIR/scripts/nvidia_exporter.py" || true
pkill -f "grafana-server" || true

sleep 5

echo "Iniciando servicios..."

# 1. Node Exporter
echo "Iniciando Node Exporter..."
"$BIN_DIR/node_exporter-1.6.0.linux-amd64/node_exporter" > "$LOG_DIR/node_exporter.log" 2>&1 &
echo $! > "$LOG_DIR/node_exporter.pid"

# 2. Nvidia Exporter
echo "Iniciando Nvidia Exporter..."
python3 "$BASE_DIR/scripts/nvidia_exporter.py" > "$LOG_DIR/nvidia_exporter.log" 2>&1 &
echo $! > "$LOG_DIR/nvidia_exporter.pid"

# 3. Prometheus
echo "Iniciando Prometheus..."
"$BIN_DIR/prometheus-2.45.0.linux-amd64/prometheus" \
    --config.file="$CONFIG_DIR/prometheus.yml" \
    --storage.tsdb.path="$BASE_DIR/data/prometheus" \
    > "$LOG_DIR/prometheus.log" 2>&1 &
echo $! > "$LOG_DIR/prometheus.pid"

# 4. Grafana
echo "Iniciando Grafana..."
# Necesitamos configurar el provisioning path
export GF_PATHS_PROVISIONING="$CONFIG_DIR/provisioning"
# Crear estructura de provisioning si no existe y simlinkear o copiar el archivo
mkdir -p "$CONFIG_DIR/provisioning/datasources"
cp "$CONFIG_DIR/grafana_datasources.yaml" "$CONFIG_DIR/provisioning/datasources/default.yaml"

cd "$BIN_DIR/grafana-10.0.0" # Grafana necesita correr desde su home a veces o configurar paths
./bin/grafana-server \
    --homepath "$BIN_DIR/grafana-10.0.0" \
    --config "$BIN_DIR/grafana-10.0.0/conf/defaults.ini" \
    cfg:paths.data="$BASE_DIR/data/grafana" \
    cfg:paths.logs="$LOG_DIR" \
    cfg:paths.plugins="$BASE_DIR/data/plugins" \
    cfg:paths.provisioning="$CONFIG_DIR/provisioning" \
    cfg:server.http_port=3001 \
    > "$LOG_DIR/grafana.log" 2>&1 &
echo $! > "$LOG_DIR/grafana.pid"

echo "Todos los servicios iniciados."
echo "Grafana: http://localhost:3001 (admin/admin)"
echo "Prometheus: http://localhost:9090"
echo "Logs en: $LOG_DIR"
