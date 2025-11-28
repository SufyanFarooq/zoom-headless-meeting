#!/bin/bash

# Quick script to register Server 2 on Server 1
# Usage: ./register-server2.sh SERVER1_IP [AUTH_TOKEN]

set -e

SERVER1_IP="${1:-}"
AUTH_TOKEN="${2:-}"

if [ -z "$SERVER1_IP" ]; then
    echo "Usage: $0 SERVER1_IP [AUTH_TOKEN]"
    echo ""
    echo "Example:"
    echo "  $0 192.168.1.100"
    echo "  $0 192.168.1.100 YOUR_AUTH_TOKEN"
    echo ""
    exit 1
fi

SERVER2_IP="35.227.36.166"
SERVER2_URL="http://${SERVER2_IP}:3001"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📝 Registering Server 2"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Server 1 IP: $SERVER1_IP"
echo "Server 2 URL: $SERVER2_URL"
echo ""

# Test Server 2 is accessible
echo "📋 Step 1: Testing Server 2 connectivity..."
if curl -s --max-time 5 "$SERVER2_URL/health" > /dev/null; then
    echo "✅ Server 2 is accessible"
else
    echo "⚠️  Warning: Cannot reach Server 2 at $SERVER2_URL"
    echo "   Make sure firewall allows port 3001"
    read -p "Continue anyway? (y/n): " CONTINUE
    if [ "$CONTINUE" != "y" ]; then
        exit 1
    fi
fi
echo ""

# Test Server 1 API
echo "📋 Step 2: Testing Server 1 API..."
if curl -s --max-time 5 "http://${SERVER1_IP}:3000/health" > /dev/null; then
    echo "✅ Server 1 API is accessible"
else
    echo "❌ Cannot reach Server 1 API at http://${SERVER1_IP}:3000"
    echo "   Check Server 1 IP and port 3000"
    exit 1
fi
echo ""

# Register Server 2
echo "📋 Step 3: Registering Server 2..."

HEADERS=("Content-Type: application/json")
if [ -n "$AUTH_TOKEN" ]; then
    HEADERS+=("Authorization: Bearer $AUTH_TOKEN")
fi

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "http://${SERVER1_IP}:3000/api/bot-servers" \
    -H "${HEADERS[0]}" \
    ${AUTH_TOKEN:+-H "${HEADERS[1]}"} \
    -d "{
        \"serverName\": \"server-2\",
        \"serverUrl\": \"${SERVER2_URL}\",
        \"capacity\": 10,
        \"priority\": 2
    }")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
    echo "✅ Server 2 registered successfully!"
    echo ""
    echo "$RESPONSE_BODY" | jq '.' 2>/dev/null || echo "$RESPONSE_BODY"
else
    echo "❌ Registration failed (HTTP $HTTP_CODE)"
    echo ""
    echo "Response:"
    echo "$RESPONSE_BODY"
    echo ""
    
    if [ "$HTTP_CODE" = "401" ]; then
        echo "💡 Authentication required. Get token from:"
        echo "   http://${SERVER1_IP}:3000/api/auth/login"
        echo ""
        echo "Then run:"
        echo "   $0 $SERVER1_IP YOUR_TOKEN"
    elif [ "$HTTP_CODE" = "400" ]; then
        echo "💡 Server might already be registered. Checking..."
        curl -s "http://${SERVER1_IP}:3000/api/bot-servers" ${AUTH_TOKEN:+-H "Authorization: Bearer $AUTH_TOKEN"} | jq '.servers[] | select(.server_name=="server-2")' 2>/dev/null || echo "Could not check"
    fi
    
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Registration Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Verify registration:"
echo ""
echo "  curl http://${SERVER1_IP}:3000/api/bot-servers ${AUTH_TOKEN:+-H \"Authorization: Bearer $AUTH_TOKEN\"}"
echo ""
echo "📋 Test load balancing:"
echo ""
echo "  # Create a meeting (will use Server 1 first)"
echo "  curl -X POST http://${SERVER1_IP}:3000/api/meetings \\"
echo "    -H \"Content-Type: application/json\" \\"
echo "    ${AUTH_TOKEN:+-H \"Authorization: Bearer $AUTH_TOKEN\"} \\"
echo "    -d '{\"meetingId\": \"123456789\", \"password\": \"test\", \"membersCount\": 10, \"videoCount\": 5, \"audioCount\": 5, \"nameType\": \"Indian\", \"meetingType\": \"Normal Member\"}'"
echo ""

