#!/bin/bash

# Quick load balancing test script
# Tests Server 1 → Server 2 load balancing

set -e

SERVER1_IP="${SERVER1_IP:-}"
AUTH_TOKEN="${AUTH_TOKEN:-}"

if [ -z "$SERVER1_IP" ] || [ -z "$AUTH_TOKEN" ]; then
    echo "Usage: SERVER1_IP=YOUR_IP AUTH_TOKEN=YOUR_TOKEN ./quick-test-load-balancing.sh"
    exit 1
fi

API_URL="http://${SERVER1_IP}:3000/api/meetings"
SERVER1_CAPACITY_URL="http://${SERVER1_IP}:3001/api/bots/capacity"
SERVER2_CAPACITY_URL="http://35.227.36.166:3001/api/bots/capacity"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 Quick Load Balancing Test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Server 1: $SERVER1_IP (Capacity: 150)"
echo "Server 2: 35.227.36.166 (Capacity: 50)"
echo ""

# Function to create meeting
create_meeting() {
    local members=$1
    curl -s -X POST "$API_URL" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${AUTH_TOKEN}" \
        -d "{
            \"meetingId\": \"5067498331\",
            \"password\": \"123456\",
            \"membersCount\": $members,
            \"videoCount\": 0,
            \"audioCount\": $members,
            \"nameType\": \"Indian\",
            \"meetingType\": \"Normal Member\"
        }"
}

# Function to check status
check_status() {
    echo ""
    echo "📊 Current Status:"
    echo "  Server 1:"
    curl -s "$SERVER1_CAPACITY_URL" | jq -r '  "    Load: \(.currentLoad)/\(.capacity) (\(.available) available)"' 2>/dev/null || echo "    Cannot connect"
    echo "  Server 2:"
    curl -s "$SERVER2_CAPACITY_URL" | jq -r '  "    Load: \(.currentLoad)/\(.capacity) (\(.available) available)"' 2>/dev/null || echo "    Cannot connect"
    echo ""
}

# Initial status
echo "📊 Initial Status:"
check_status

# Test 1: Small meeting (Server 1)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 1: Small Meeting (10 bots) - Should use Server 1"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Creating meeting..."
RESPONSE=$(create_meeting 10)
if echo "$RESPONSE" | grep -q "success\|meeting"; then
    echo "✅ Meeting created"
else
    echo "❌ Failed: $RESPONSE"
fi
sleep 3
check_status

# Test 2: Fill Server 1 (150 bots)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 2: Filling Server 1 (150 bots total)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Creating 14 more meetings (10 bots each)..."
for i in {1..14}; do
    echo -n "Meeting $i/14... "
    RESPONSE=$(create_meeting 10)
    if echo "$RESPONSE" | grep -q "success\|meeting"; then
        echo "✅"
    else
        echo "❌"
    fi
    sleep 1
done
check_status

# Test 3: Server 2 test
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 3: New Meeting (Server 1 Full) - Should use Server 2"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Creating meeting (Server 1 should be full)..."
RESPONSE=$(create_meeting 10)
if echo "$RESPONSE" | grep -q "success\|meeting"; then
    echo "✅ Meeting created (should be on Server 2)"
else
    echo "❌ Failed: $RESPONSE"
fi
sleep 3
check_status

# Final status
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Test Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Final Status:"
docker exec -it zoom-dashboard-db psql -U postgres -d zoom_bots -c \
    "SELECT server_name, capacity, current_load, (capacity - current_load) as available, priority FROM bot_servers ORDER BY priority;" 2>/dev/null || echo "Cannot access database"
echo ""
echo "💡 Expected:"
echo "   Server 1: 150/150 (full)"
echo "   Server 2: 10/50 (used)"
echo ""

