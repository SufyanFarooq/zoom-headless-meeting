#!/bin/bash
# Check server paths and fix setup

echo "🔍 Checking server paths..."
echo ""

# Check common locations
echo "1. Checking common project locations:"
for path in "/opt/zoom-headless-meeting" "/opt/zoom-bot-dashboard" "/home/*/zoom*" "/root/zoom*"; do
    if [ -d "$path" ] 2>/dev/null; then
        echo "   ✅ Found: $path"
        if [ -f "$path/bin/entry-bot-optimized.sh" ]; then
            echo "      ✅ Entry script found!"
        else
            echo "      ❌ Entry script missing"
        fi
    fi
done

echo ""
echo "2. Finding entry-bot-optimized.sh:"
find /opt /home /root -name "entry-bot-optimized.sh" 2>/dev/null | head -5

echo ""
echo "3. Finding project directory (looking for compose-50-bots.yaml):"
find /opt /home /root -name "compose-50-bots.yaml" 2>/dev/null | head -5

echo ""
echo "4. Current working directory:"
pwd

echo ""
echo "5. Files in current directory:"
ls -la | head -10
