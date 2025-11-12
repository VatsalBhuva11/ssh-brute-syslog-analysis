#!/usr/bin/env bash
# View logs from ELK stack services

set -e

SERVICE=${1:-all}
LINES=${2:-100}

case "$SERVICE" in
    elasticsearch|es)
        echo "=== Elasticsearch Logs (last $LINES lines) ==="
        docker compose logs --no-log-prefix -n "$LINES" elasticsearch
        ;;
    kibana|k)
        echo "=== Kibana Logs (last $LINES lines) ==="
        docker compose logs --no-log-prefix -n "$LINES" kibana
        ;;
    logstash|ls)
        echo "=== Logstash Logs (last $LINES lines) ==="
        docker compose logs --no-log-prefix -n "$LINES" logstash
        ;;
    all|*)
        echo "=== All ELK Stack Logs (last $LINES lines) ==="
        docker compose logs --no-log-prefix -n "$LINES"
        ;;
esac

