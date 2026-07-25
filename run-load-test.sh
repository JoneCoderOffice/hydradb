#!/bin/bash

# run-load-test.sh - Dynamic load test script for NestJS HA database cluster
# Usage: ./run-load-test.sh [duration_seconds] [concurrency]

DURATION=${1:-10}
CONCURRENCY=${2:-100}
URL="http://localhost:3000/users"

echo "=========================================================="
echo " Starting Database Cluster Load Test (NestJS + Patroni)"
echo " Duration: $DURATION seconds | Concurrency: $CONCURRENCY clients"
echo "=========================================================="
echo ""

# Check if autocannon is installed
if ! command -v autocannon &> /dev/null; then
    echo "autocannon not found locally, running via npx..."
    AUTOCANNON_CMD="npx autocannon"
else
    AUTOCANNON_CMD="autocannon"
fi

echo "----------------------------------------------------------"
echo " Phase 1: Load testing READS (GET /users)"
echo " (Queries load-balanced across $REPLICAS PostgreSQL replicas)"
echo "----------------------------------------------------------"
$AUTOCANNON_CMD -c $CONCURRENCY -d $DURATION $URL

echo ""
echo "----------------------------------------------------------"
echo " Phase 2: Load testing WRITES (POST /users)"
echo " (Transactions routed strictly to primary write leader)"
echo "----------------------------------------------------------"
$AUTOCANNON_CMD -c $((CONCURRENCY / 2)) -d $DURATION \
  -m POST \
  -H "Content-Type: application/json" \
  -b '{"name":"Load Test User","email":"test@load.com"}' \
  $URL

echo ""
echo "=========================================================="
echo " Load Test Completed Successfully!"
echo "=========================================================="
