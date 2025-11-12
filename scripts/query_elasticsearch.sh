#!/usr/bin/env bash
# Query Elasticsearch for SSH log data

set -e

QUERY=${1:-all}
SIZE=${2:-10}

case "$QUERY" in
    count)
        echo "Total documents:"
        curl -s "http://localhost:9200/authlogs/_count?pretty"
        ;;
    failed)
        echo "Failed login attempts:"
        curl -s -X POST "http://localhost:9200/authlogs/_search?pretty" \
          -H 'Content-Type: application/json' \
          -d '{
            "query": { "term": { "status.keyword": "Failed" } },
            "size": '$SIZE'
          }'
        ;;
    top-ips)
        echo "Top attacking IPs:"
        curl -s -X POST "http://localhost:9200/authlogs/_search?pretty" \
          -H 'Content-Type: application/json' \
          -d '{
            "size": 0,
            "aggs": {
              "top_ips": {
                "terms": {
                  "field": "src_ip.keyword",
                  "size": '$SIZE'
                }
              }
            }
          }'
        ;;
    top-users)
        echo "Most targeted usernames:"
        curl -s -X POST "http://localhost:9200/authlogs/_search?pretty" \
          -H 'Content-Type: application/json' \
          -d '{
            "size": 0,
            "query": { "term": { "status.keyword": "Failed" } },
            "aggs": {
              "top_users": {
                "terms": {
                  "field": "user.keyword",
                  "size": '$SIZE'
                }
              }
            }
          }'
        ;;
    recent)
        echo "Recent events:"
        curl -s -X POST "http://localhost:9200/authlogs/_search?pretty" \
          -H 'Content-Type: application/json' \
          -d '{
            "sort": [{ "@timestamp": { "order": "desc" } }],
            "size": '$SIZE'
          }'
        ;;
    stats)
        echo "=== SSH Log Statistics ==="
        echo ""
        echo "Total documents:"
        TOTAL=$(curl -s "http://localhost:9200/authlogs/_count?pretty" | grep -o '"count" : [0-9]*' | awk '{print $3}')
        echo "  $TOTAL"
        echo ""
        echo "Failed logins:"
        FAILED_RESPONSE=$(curl -s -X POST "http://localhost:9200/authlogs/_search" \
          -H 'Content-Type: application/json' \
          -d '{"size":0,"query":{"term":{"status.keyword":"Failed"}}}')
        # Extract value from "total":{"value":436,"relation":"eq"}
        FAILED=$(echo "$FAILED_RESPONSE" | grep -oE '"total":\{"value":[0-9]+' | grep -oE '[0-9]+' | head -1)
        echo "  ${FAILED:-0}"
        echo ""
        echo "Successful logins:"
        SUCCESS_RESPONSE=$(curl -s -X POST "http://localhost:9200/authlogs/_search" \
          -H 'Content-Type: application/json' \
          -d '{"size":0,"query":{"term":{"status.keyword":"Accepted"}}}')
        SUCCESS=$(echo "$SUCCESS_RESPONSE" | grep -oE '"total":\{"value":[0-9]+' | grep -oE '[0-9]+' | head -1)
        echo "  ${SUCCESS:-0}"
        echo ""
        echo "Other events:"
        OTHER=$((TOTAL - ${FAILED:-0} - ${SUCCESS:-0}))
        echo "  $OTHER"
        ;;
    all|*)
        echo "Usage: $0 [count|failed|top-ips|top-users|recent|stats] [size]"
        echo ""
        echo "Examples:"
        echo "  $0 count              # Total document count"
        echo "  $0 failed 20          # Show 20 failed login attempts"
        echo "  $0 top-ips 10         # Top 10 attacking IPs"
        echo "  $0 top-users 10       # Top 10 targeted usernames"
        echo "  $0 recent 5           # 5 most recent events"
        echo "  $0 stats              # Overall statistics"
        ;;
esac

