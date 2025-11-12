#!/usr/bin/env bash
# Health check script for ELK stack

set -e

echo "=== ELK Stack Health Check ==="
echo ""

# Check Docker containers
echo "📦 Docker Containers:"
docker compose ps
echo ""

# Check Elasticsearch
echo "🔍 Elasticsearch:"
if curl -s http://localhost:9200 > /dev/null 2>&1; then
    echo "  ✓ Elasticsearch is running"
    HEALTH=$(curl -s http://localhost:9200/_cluster/health?pretty | grep -o '"status" : "[^"]*"' | cut -d'"' -f4)
    echo "  Status: $HEALTH"
    
    COUNT=$(curl -s http://localhost:9200/authlogs/_count?pretty | grep -o '"count" : [0-9]*' | awk '{print $3}')
    echo "  Documents in authlogs: $COUNT"
    
    SHARDS=$(curl -s http://localhost:9200/_cat/shards/authlogs?v 2>/dev/null | tail -n +2 | wc -l)
    echo "  Active shards: $SHARDS"
else
    echo "  ✗ Elasticsearch is not responding"
fi
echo ""

# Check Kibana
echo "📊 Kibana:"
if curl -s http://localhost:5601/api/status > /dev/null 2>&1; then
    echo "  ✓ Kibana is running"
    STATUS=$(curl -s http://localhost:5601/api/status 2>/dev/null | grep -o '"state" : "[^"]*"' | head -1 | cut -d'"' -f4 || echo "unknown")
    echo "  Status: $STATUS"
else
    echo "  ✗ Kibana is not responding"
fi
echo ""

# Check Logstash
echo "📥 Logstash:"
if curl -s http://localhost:9600 > /dev/null 2>&1; then
    echo "  ✓ Logstash is running"
    PIPELINE=$(curl -s http://localhost:9600/_node/pipelines?pretty 2>/dev/null | grep -o '"pipeline.workers" : [0-9]*' | head -1 || echo "unknown")
    echo "  Pipeline: active"
else
    echo "  ✗ Logstash is not responding"
fi
echo ""

# Check log file
echo "📄 Log File:"
if [ -f "./auth.log" ]; then
    LINES=$(wc -l < ./auth.log)
    SIZE=$(du -h ./auth.log | cut -f1)
    echo "  ✓ auth.log exists"
    echo "  Lines: $LINES"
    echo "  Size: $SIZE"
else
    echo "  ✗ auth.log not found"
fi
echo ""

echo "=== Health Check Complete ==="

