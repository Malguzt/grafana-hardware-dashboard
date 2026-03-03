#!/bin/bash
set -e

# Directorio base
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="$BASE_DIR/bin"

mkdir -p "$BIN_DIR"
cd "$BIN_DIR"

echo "Descargando Prometheus..."
if [ ! -d "prometheus-2.45.0.linux-amd64" ]; then
    wget -q --show-progress https://github.com/prometheus/prometheus/releases/download/v2.45.0/prometheus-2.45.0.linux-amd64.tar.gz
    tar xzf prometheus-2.45.0.linux-amd64.tar.gz
    rm prometheus-2.45.0.linux-amd64.tar.gz
    echo "Prometheus descargado."
else
    echo "Prometheus ya existe."
fi

echo "Descargando Node Exporter..."
if [ ! -d "node_exporter-1.6.0.linux-amd64" ]; then
    wget -q --show-progress https://github.com/prometheus/node_exporter/releases/download/v1.6.0/node_exporter-1.6.0.linux-amd64.tar.gz
    tar xzf node_exporter-1.6.0.linux-amd64.tar.gz
    rm node_exporter-1.6.0.linux-amd64.tar.gz
    echo "Node Exporter descargado."
else
    echo "Node Exporter ya existe."
fi

echo "Descargando Grafana..."
if [ ! -d "grafana-10.0.0" ]; then
    wget -q --show-progress https://dl.grafana.com/oss/release/grafana-10.0.0.linux-amd64.tar.gz
    tar xzf grafana-10.0.0.linux-amd64.tar.gz
    rm grafana-10.0.0.linux-amd64.tar.gz
    echo "Grafana descargado."
else
    echo "Grafana ya existe."
fi

echo "Instalación de dependencias completada."
