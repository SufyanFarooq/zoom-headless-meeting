#!/bin/bash

# Script to copy missing scripts to Server 2
# Run this on Server 1 or local machine

set -e

SERVER2_IP="${SERVER2_IP:-35.227.36.166}"
SERVER2_USER="${SERVER2_USER:-sufyanmaviya400}"
SERVER2_PATH="/opt/zoom-headless-meeting"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Copy Scripts to Server 2"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Server 2: $SERVER2_USER@$SERVER2_IP"
echo "Path: $SERVER2_PATH"
echo ""

# Check if scripts exist locally
REQUIRED_SCRIPTS=(
  "setup-flexible-bots.sh"
  "generate-flexible-bots.sh"
  "auto-setup-bots.sh"
  "update-compose-zak.py"
)

MISSING_SCRIPTS=()

for script in "${REQUIRED_SCRIPTS[@]}"; do
  if [ ! -f "$script" ]; then
    MISSING_SCRIPTS+=("$script")
  fi
done

if [ ${#MISSING_SCRIPTS[@]} -gt 0 ]; then
  echo "❌ Missing scripts locally:"
  for script in "${MISSING_SCRIPTS[@]}"; do
    echo "   - $script"
  done
  echo ""
  echo "Please run this script from project root directory"
  exit 1
fi

echo "✅ All scripts found locally"
echo ""

# Create tar archive
echo "📦 Creating archive..."
TAR_FILE="server2-scripts-$(date +%Y%m%d-%H%M%S).tar.gz"
tar -czf "$TAR_FILE" "${REQUIRED_SCRIPTS[@]}"
echo "✅ Created: $TAR_FILE"
echo ""

# Check if gcloud is available
if command -v gcloud > /dev/null 2>&1; then
  echo "📤 Copying using gcloud..."
  read -p "GCP instance name (e.g., zoom-bots-server): " INSTANCE_NAME
  read -p "GCP zone (e.g., us-east1-c): " ZONE
  
  gcloud compute scp "$TAR_FILE" "${INSTANCE_NAME}:${SERVER2_PATH}/" --zone="$ZONE"
  
  echo ""
  echo "📝 Extracting on Server 2..."
  gcloud compute ssh "$INSTANCE_NAME" --zone="$ZONE" --command="cd $SERVER2_PATH && tar -xzf $TAR_FILE && chmod +x setup-flexible-bots.sh generate-flexible-bots.sh auto-setup-bots.sh update-compose-zak.py && rm $TAR_FILE && docker compose -f docker-compose.bot-server.yml restart"
  
elif command -v scp > /dev/null 2>&1; then
  echo "📤 Copying using scp..."
  scp "$TAR_FILE" "${SERVER2_USER}@${SERVER2_IP}:${SERVER2_PATH}/"
  
  echo ""
  echo "📝 Extracting on Server 2..."
  ssh "${SERVER2_USER}@${SERVER2_IP}" "cd $SERVER2_PATH && tar -xzf $TAR_FILE && chmod +x setup-flexible-bots.sh generate-flexible-bots.sh auto-setup-bots.sh update-compose-zak.py && rm $TAR_FILE && docker compose -f docker-compose.bot-server.yml restart"
  
else
  echo "⚠️  Neither gcloud nor scp found"
  echo ""
  echo "Manual steps:"
  echo "1. Copy $TAR_FILE to Server 2"
  echo "2. Extract: tar -xzf $TAR_FILE"
  echo "3. Permissions: chmod +x setup-flexible-bots.sh generate-flexible-bots.sh auto-setup-bots.sh update-compose-zak.py"
  echo "4. Restart: docker compose -f docker-compose.bot-server.yml restart"
  exit 1
fi

# Cleanup
rm -f "$TAR_FILE"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Scripts Copied Successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Verify on Server 2:"
echo "   ssh ${SERVER2_USER}@${SERVER2_IP}"
echo "   cd $SERVER2_PATH"
echo "   ls -la setup-flexible-bots.sh generate-flexible-bots.sh auto-setup-bots.sh update-compose-zak.py"
echo ""
echo "✅ Bot server restarted"
echo "✅ Ready to create bots!"
echo ""

