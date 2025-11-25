#!/bin/bash
# Check current time in UTC and IST

echo "🕐 Current Time Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# UTC time
UTC_TIME=$(date -u +"%Y-%m-%dT%H:%M:%S")
echo "UTC Time: $UTC_TIME UTC"

# IST time (UTC + 5:30)
IST_HOUR=$(date -u +%H)
IST_MINUTE=$(date -u +%M)
IST_SECOND=$(date -u +%S)

# Add 5 hours 30 minutes
IST_HOUR=$((10#$IST_HOUR + 5))
IST_MINUTE=$((10#$IST_MINUTE + 30))

# Handle minute overflow
if [ $IST_MINUTE -ge 60 ]; then
    IST_HOUR=$((IST_HOUR + 1))
    IST_MINUTE=$((IST_MINUTE - 60))
fi

# Handle hour overflow (24-hour format)
if [ $IST_HOUR -ge 24 ]; then
    IST_HOUR=$((IST_HOUR - 24))
    # Date would roll over, but for simplicity just show hour
fi

IST_TIME=$(date -u +"%Y-%m-%d")"T$(printf "%02d:%02d:%02d" $IST_HOUR $IST_MINUTE $IST_SECOND)"
echo "IST Time: $IST_TIME IST"
echo ""

# Calculate minimum future time (1 minute from now in IST)
FUTURE_MINUTE=$((IST_MINUTE + 1))
FUTURE_HOUR=$IST_HOUR
if [ $FUTURE_MINUTE -ge 60 ]; then
    FUTURE_HOUR=$((FUTURE_HOUR + 1))
    FUTURE_MINUTE=$((FUTURE_MINUTE - 60))
fi
if [ $FUTURE_HOUR -ge 24 ]; then
    FUTURE_HOUR=$((FUTURE_HOUR - 24))
fi

FUTURE_TIME=$(date -u +"%Y-%m-%d")"T$(printf "%02d:%02d" $FUTURE_HOUR $FUTURE_MINUTE)"
echo "💡 Minimum future time (IST): $FUTURE_TIME IST"
echo ""
echo "📋 Your scheduled time: 2025-11-25T18:35 IST"
echo "   Current IST time: $IST_TIME IST"
echo ""
if [ "$IST_TIME" \> "2025-11-25T18:35" ]; then
    echo "❌ Scheduled time is in the past!"
    echo "   Please schedule for at least: $FUTURE_TIME IST"
else
    echo "✅ Scheduled time is in the future"
fi
