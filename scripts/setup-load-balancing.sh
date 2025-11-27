#!/bin/bash

# Complete setup script for load balancing between Server 1 and Server 2
# This script:
# 1. Adds priority column to database (if needed)
# 2. Registers both servers with proper priorities
# 3. Verifies the setup

set -e

API_URL="${API_URL:-http://localhost:3000/api}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-zoom_bots}"
DB_USER="${DB_USER:-postgres}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Load Balancing Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Step 1: Database Migration
echo "📊 Step 1: Updating database schema..."
if command -v psql > /dev/null 2>&1; then
    export PGPASSWORD="${DB_PASSWORD}"
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$(dirname "$0")/migrate-add-priority.sql"
    echo "✅ Database schema updated"
else
    echo "⚠️  psql not found. Please run migrate-add-priority.sql manually:"
    echo "   psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f scripts/migrate-add-priority.sql"
fi

echo ""

# Step 2: Get server URLs
echo "📝 Step 2: Server Configuration"
echo ""

read -p "Enter Server 1 URL (Primary - 32 vCPUs, 128GB): " SERVER1_URL
if [ -z "$SERVER1_URL" ]; then
    echo "❌ Server 1 URL is required"
    exit 1
fi

read -p "Enter Server 2 URL (Secondary - 4 vCPUs, 16GB): " SERVER2_URL
if [ -z "$SERVER2_URL" ]; then
    echo "❌ Server 2 URL is required"
    exit 1
fi

# Step 3: Calculate capacities
SERVER1_CAPACITY="${SERVER1_CAPACITY:-100}"  # 32 vCPUs / 0.3 per bot = ~106, use 100 for safety
SERVER2_CAPACITY="${SERVER2_CAPACITY:-10}"   # 4 vCPUs / 0.3 per bot = ~13, use 10 for safety

read -p "Server 1 capacity (default: $SERVER1_CAPACITY): " INPUT_CAP1
if [ -n "$INPUT_CAP1" ]; then
    SERVER1_CAPACITY="$INPUT_CAP1"
fi

read -p "Server 2 capacity (default: $SERVER2_CAPACITY): " INPUT_CAP2
if [ -n "$INPUT_CAP2" ]; then
    SERVER2_CAPACITY="$INPUT_CAP2"
fi

echo ""
echo "📊 Server Capacities:"
echo "  Server 1: $SERVER1_CAPACITY bots"
echo "  Server 2: $SERVER2_CAPACITY bots"
echo ""

# Step 4: Register servers
echo "📝 Step 3: Registering servers..."
echo ""

# Check if auth token is needed
if [ -z "$AUTH_TOKEN" ]; then
    echo "⚠️  AUTH_TOKEN not set. If API requires authentication, set it:"
    echo "   export AUTH_TOKEN='your-token-here'"
    echo ""
fi

# Register Server 1
echo "Registering Server 1 (Primary)..."
SERVER1_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${API_URL}/bot-servers" \
  -H "Content-Type: application/json" \
  ${AUTH_TOKEN:+-H "Authorization: Bearer ${AUTH_TOKEN}"} \
  -d "{
    \"serverName\": \"server-1\",
    \"serverUrl\": \"${SERVER1_URL}\",
    \"capacity\": ${SERVER1_CAPACITY},
    \"priority\": 1
  }")

HTTP_CODE=$(echo "$SERVER1_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$SERVER1_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ] || echo "$RESPONSE_BODY" | grep -q "success"; then
    echo "✅ Server 1 registered"
    echo "$RESPONSE_BODY" | jq '.' 2>/dev/null || echo "$RESPONSE_BODY"
else
    echo "❌ Failed to register Server 1 (HTTP $HTTP_CODE):"
    echo "$RESPONSE_BODY"
    exit 1
fi

echo ""

# Register Server 2
echo "Registering Server 2 (Secondary)..."
SERVER2_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${API_URL}/bot-servers" \
  -H "Content-Type: application/json" \
  ${AUTH_TOKEN:+-H "Authorization: Bearer ${AUTH_TOKEN}"} \
  -d "{
    \"serverName\": \"server-2\",
    \"serverUrl\": \"${SERVER2_URL}\",
    \"capacity\": ${SERVER2_CAPACITY},
    \"priority\": 2
  }")

HTTP_CODE=$(echo "$SERVER2_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$SERVER2_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ] || echo "$RESPONSE_BODY" | grep -q "success"; then
    echo "✅ Server 2 registered"
    echo "$RESPONSE_BODY" | jq '.' 2>/dev/null || echo "$RESPONSE_BODY"
else
    echo "❌ Failed to register Server 2 (HTTP $HTTP_CODE):"
    echo "$RESPONSE_BODY"
    exit 1
fi

echo ""

# Step 5: Verify setup
echo "📋 Step 4: Verifying setup..."
VERIFY_RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "${API_URL}/bot-servers" \
  ${AUTH_TOKEN:+-H "Authorization: Bearer ${AUTH_TOKEN}"})

HTTP_CODE=$(echo "$VERIFY_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$VERIFY_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Current server configuration:"
    echo "$RESPONSE_BODY" | jq '.servers[] | {name: .server_name, url: .server_url, capacity: .capacity, load: .current_load, priority: .priority, available: (.capacity - .current_load)}' 2>/dev/null || echo "$RESPONSE_BODY"
else
    echo "⚠️  Could not verify servers (HTTP $HTTP_CODE)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Load Balancing Setup Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Summary:"
echo "  ✅ Database schema updated"
echo "  ✅ Server 1 (Primary) registered: $SERVER1_URL"
echo "  ✅ Server 2 (Secondary) registered: $SERVER2_URL"
echo ""
echo "💡 How it works:"
echo "  1. All new bot requests will first try Server 1"
echo "  2. When Server 1 is full, requests will automatically use Server 2"
echo "  3. Server 1 has priority 1, Server 2 has priority 2"
echo ""

