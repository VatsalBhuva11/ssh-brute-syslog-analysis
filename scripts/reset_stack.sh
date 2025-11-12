#!/usr/bin/env bash
# Reset and restart the ELK stack

set -e

echo "⚠️  This will stop all containers and remove all data!"
read -p "Are you sure? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 1
fi

echo "Stopping containers..."
docker compose down -v

echo "Removing old volumes..."
docker volume rm csdf-project_esdata 2>/dev/null || true

echo "Starting fresh stack..."
docker compose up -d

echo "Waiting for services to start..."
sleep 10

echo "Checking health..."
./scripts/health_check.sh

echo ""
echo "✓ Stack reset complete!"
echo "Access Kibana at: http://localhost:5601"

