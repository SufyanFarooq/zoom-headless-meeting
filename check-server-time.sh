#!/bin/bash
# Check server time and timezone

echo "🕐 Server Time Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "1️⃣ System Time:"
date
echo ""

echo "2️⃣ UTC Time:"
date -u
echo ""

echo "3️⃣ Timezone:"
timedatectl 2>/dev/null || echo "   (timedatectl not available)"
echo ""

echo "4️⃣ IST Calculation (UTC + 5:30):"
UTC_HOUR=$(date -u +%H)
UTC_MINUTE=$(date -u +%M)
UTC_SECOND=$(date -u +%S)

# Add 5:30 to UTC
IST_HOUR=$((10#$UTC_HOUR + 5))
IST_MINUTE=$((10#$UTC_MINUTE + 30))

# Handle overflow
if [ $IST_MINUTE -ge 60 ]; then
    IST_HOUR=$((IST_HOUR + 1))
    IST_MINUTE=$((IST_MINUTE - 60))
fi

if [ $IST_HOUR -ge 24 ]; then
    IST_HOUR=$((IST_HOUR - 24))
fi

IST_TIME=$(printf "%02d:%02d:%02d" $IST_HOUR $IST_MINUTE $UTC_SECOND)
echo "   UTC: $(date -u +%H:%M:%S)"
echo "   IST: $IST_TIME"
echo ""

echo "5️⃣ Test Scheduled Time:"
SCHEDULED="2025-11-25T18:55"
echo "   Scheduled: $SCHEDULED IST"
echo "   Current IST: $(date +%Y-%m-%d)T$IST_TIME"
echo ""

# Compare
CURRENT_IST_FULL="$(date +%Y-%m-%d)T$IST_TIME"
if [ "$CURRENT_IST_FULL" \> "$SCHEDULED" ]; then
    echo "   ❌ Scheduled time is in the past"
else
    echo "   ✅ Scheduled time is in the future"
fi
