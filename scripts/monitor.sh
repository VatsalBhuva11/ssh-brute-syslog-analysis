#!/usr/bin/env bash
# Real-time monitoring of ELK stack

set -e

echo "=== ELK Stack Real-time Monitor ==="
echo "Press Ctrl+C to stop"
echo ""

# Function to display stats
show_stats() {
    clear
    echo "=== ELK Stack Monitor - $(date) ==="
    echo ""
    
    # Elasticsearch stats
    if curl -s http://localhost:9200 > /dev/null 2>&1; then
        COUNT=$(curl -s http://localhost:9200/authlogs/_count?pretty 2>/dev/null | grep -o '"count" : [0-9]*' | awk '{print $3}' || echo "0")
        HEALTH=$(curl -s http://localhost:9200/_cluster/health?pretty 2>/dev/null | grep -o '"status" : "[^"]*"' | cut -d'"' -f4 || echo "unknown")
        echo "📊 Elasticsearch:"
        echo "   Status: $HEALTH"
        echo "   Documents: $COUNT"
    else
        echo "📊 Elasticsearch: Not responding"
    fi
    
    echo ""
    
    # Log file stats
    if [ -f "./auth.log" ]; then
        LINES=$(wc -l < ./auth.log)
        echo "📄 auth.log: $LINES lines"
    fi
    
    echo ""
    echo "Press Ctrl+C to stop monitoring"
}

# Monitor loop
while true; do
    show_stats
    sleep 5
done

