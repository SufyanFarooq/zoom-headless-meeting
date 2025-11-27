#!/bin/bash

# Script to register both bot servers with proper priorities and capacities
# Server 1: Primary (priority=1) - 32 vCPUs, 128GB Memory
# Server 2: Secondary (priority=2) - 4 vCPUs, 16GB Memory

API_URL="${API_URL:-http://localhost:3000/api}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 Registering Bot Servers"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Get Server 1 details
read -p "Enter Server 1 URL (e.g., http://server1-ip:3001): " SERVER1_URL
if [ -z "$SERVER1_URL" ]; then
    echo "❌ Server 1 URL is required"
    exit 1
fi

# Get Server 2 details
read -p "Enter Server 2 URL (e.g., http://server2-ip:3001): " SERVER2_URL
if [ -z "$SERVER2_URL" ]; then
    echo "❌ Server 2 URL is required"
    exit 1
fi

# Calculate capacities based on server specs
# Each bot uses: 0.3 CPU cores, 256MB memory
# Server 1: 32 vCPUs / 0.3 = ~106 bots (CPU limited)
# Server 2: 4 vCPUs / 0.3 = ~13 bots (CPU limited)
SERVER1_CAPACITY="${SERVER1_CAPACITY:-100}"  # Conservative estimate for Server 1
SERVER2_CAPACITY="${SERVER2_CAPACITY:-10}"   # Conservative estimate for Server 2

echo ""
echo "📊 Server Capacities:"
echo "  Server 1: $SERVER1_CAPACITY bots (32 vCPUs, 128GB Memory)"
echo "  Server 2: $SERVER2_CAPACITY bots (4 vCPUs, 16GB Memory)"
echo ""

# Register Server 1 (Primary)
echo "📝 Registering Server 1 (Primary)..."
SERVER1_RESPONSE=$(curl -s -X POST "${API_URL}/bot-servers" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${AUTH_TOKEN}" \
  -d "{
    \"serverName\": \"server-1\",
    \"serverUrl\": \"${SERVER1_URL}\",
    \"capacity\": ${SERVER1_CAPACITY},
    \"priority\": 1
  }")

if echo "$SERVER1_RESPONSE" | grep -q "success"; then
    echo "✅ Server 1 registered successfully"
    echo "$SERVER1_RESPONSE" | jq '.' 2>/dev/null || echo "$SERVER1_RESPONSE"
else
    echo "❌ Failed to register Server 1:"
    echo "$SERVER1_RESPONSE"
    exit 1
fi

echo ""

# Register Server 2 (Secondary)
echo "📝 Registering Server 2 (Secondary)..."
SERVER2_RESPONSE=$(curl -s -X POST "${API_URL}/bot-servers" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${AUTH_TOKEN}" \
  -d "{
    \"serverName\": \"server-2\",
    \"serverUrl\": \"${SERVER2_URL}\",
    \"capacity\": ${SERVER2_CAPACITY},
    \"priority\": 2
  }")

if echo "$SERVER2_RESPONSE" | grep -q "success"; then
    echo "✅ Server 2 registered successfully"
    echo "$SERVER2_RESPONSE" | jq '.' 2>/dev/null || echo "$SERVER2_RESPONSE"
else
    echo "❌ Failed to register Server 2:"
    echo "$SERVER2_RESPONSE"
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Both servers registered successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Server Configuration:"
echo "  Server 1 (Primary):"
echo "    - Priority: 1 (used first)"
echo "    - Capacity: $SERVER1_CAPACITY bots"
echo "    - URL: $SERVER1_URL"
echo ""
echo "  Server 2 (Secondary):"
echo "    - Priority: 2 (used when Server 1 is full)"
echo "    - Capacity: $SERVER2_CAPACITY bots"
echo "    - URL: $SERVER2_URL"
echo ""
echo "💡 Load Balancing:"
echo "  - Requests will first try Server 1"
echo "  - When Server 1 is full, requests will use Server 2"
echo ""

