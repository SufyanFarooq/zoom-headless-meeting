#!/bin/bash

# Real-time monitoring script for both servers
# Shows capacity, load, and availability

set -e

SERVER1_IP="${SERVER1_IP:-}"
SERVER2_IP="35.227.36.166"

if [ -z "$SERVER1_IP" ]; then
    echo "Usage: SERVER1_IP=YOUR_SERVER1_IP ./monitor-servers.sh"
    echo ""
    echo "Example:"
    echo "  SERVER1_IP=192.168.1.100 ./monitor-servers.sh"
    exit 1
fi

clear
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Server Load Monitoring"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Press Ctrl+C to stop"
echo ""

while true; do
    # Get timestamp
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    
    clear
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 Server Load Monitoring - $TIMESTAMP"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Server 1
    echo "🖥️  Server 1 (Primary - Priority 1):"
    echo "   URL: http://${SERVER1_IP}:3001"
    if SERVER1_DATA=$(curl -s --max-time 2 "http://${SERVER1_IP}:3001/api/bots/capacity" 2>/dev/null); then
        if command -v jq > /dev/null 2>&1; then
            echo "$SERVER1_DATA" | jq -r '
                "   Capacity: \(.capacity) bots",
                "   Current Load: \(.currentLoad) bots",
                "   Available: \(.available) bots",
                "   Usage: \(.currentLoad)/\(.capacity) (\((.currentLoad/.capacity*100)|floor)%)"
            '
        else
            echo "$SERVER1_DATA"
        fi
    else
        echo "   ⚠️  Cannot connect"
    fi
    echo ""
    
    # Server 2
    echo "🖥️  Server 2 (Secondary - Priority 2):"
    echo "   URL: http://${SERVER2_IP}:3001"
    if SERVER2_DATA=$(curl -s --max-time 2 "http://${SERVER2_IP}:3001/api/bots/capacity" 2>/dev/null); then
        if command -v jq > /dev/null 2>&1; then
            echo "$SERVER2_DATA" | jq -r '
                "   Capacity: \(.capacity) bots",
                "   Current Load: \(.currentLoad) bots",
                "   Available: \(.available) bots",
                "   Usage: \(.currentLoad/.capacity*100|floor)%"
            '
        else
            echo "$SERVER2_DATA"
        fi
    else
        echo "   ⚠️  Cannot connect"
    fi
    echo ""
    
    # Database Status (if accessible)
    echo "📊 Database Status:"
    if DB_STATUS=$(docker exec zoom-dashboard-db psql -U postgres -d zoom_bots -t -c \
        "SELECT server_name, capacity, current_load, priority FROM bot_servers ORDER BY priority;" 2>/dev/null); then
        echo "$DB_STATUS" | while read line; do
            if [ -n "$line" ]; then
                echo "   $line"
            fi
        done
    else
        echo "   ⚠️  Cannot access database"
    fi
    echo ""
    
    # Summary
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "💡 Load Balancing:"
    echo "   • New requests → Server 1 (if available)"
    echo "   • Server 1 full → Server 2 (automatic)"
    echo "   • Both full → Error"
    echo ""
    echo "Press Ctrl+C to stop | Refreshing in 5 seconds..."
    sleep 5
done

