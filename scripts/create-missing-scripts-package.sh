#!/bin/bash

# Create package with only missing scripts for Server 2
# Run this on local machine or Server 1

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Create Missing Scripts Package"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Get project root
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

PACKAGE_NAME="missing-scripts.tar.gz"

# Required scripts
REQUIRED_SCRIPTS=(
  "setup-flexible-bots.sh"
  "generate-flexible-bots.sh"
  "auto-setup-bots.sh"
  "update-compose-zak.py"
)

# Check if scripts exist
MISSING=()
for script in "${REQUIRED_SCRIPTS[@]}"; do
  if [ ! -f "$script" ]; then
    MISSING+=("$script")
  fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
  echo "❌ Missing scripts:"
  for script in "${MISSING[@]}"; do
    echo "   - $script"
  done
  exit 1
fi

echo "✅ All scripts found"
echo ""

# Create package
echo "📦 Creating package..."
tar -czf "$PACKAGE_NAME" "${REQUIRED_SCRIPTS[@]}"

PACKAGE_SIZE=$(du -h "$PACKAGE_NAME" | cut -f1)
PACKAGE_PATH=$(realpath "$PACKAGE_NAME")

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Package Created!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📦 Package: $PACKAGE_NAME"
echo "📊 Size: $PACKAGE_SIZE"
echo "📁 Location: $PACKAGE_PATH"
echo ""
echo "📋 Contents:"
for script in "${REQUIRED_SCRIPTS[@]}"; do
  echo "   ✅ $script"
done
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📤 Upload Instructions"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Method 1: Browser SSH Upload (Easiest)"
echo ""
echo "1. GCP Console → Compute Engine → VM instances"
echo "2. Click 'SSH' button next to 'zoom-bots-server'"
echo "3. Click '⚙️ Settings' → 'Upload file'"
echo "4. Select: $PACKAGE_NAME"
echo "5. Extract on Server 2:"
echo ""
cat << 'EOF'
   cd /opt/zoom-headless-meeting
   tar -xzf ~/missing-scripts.tar.gz
   chmod +x setup-flexible-bots.sh generate-flexible-bots.sh auto-setup-bots.sh update-compose-zak.py
   rm ~/missing-scripts.tar.gz
   docker compose -f docker-compose.bot-server.yml restart
EOF

echo ""
echo "Method 2: Using gcloud"
echo ""
echo "  gcloud compute scp $PACKAGE_NAME zoom-bots-server:/opt/zoom-headless-meeting/ --zone=us-east1-c"
echo ""
echo "  gcloud compute ssh zoom-bots-server --zone=us-east1-c --command=\"cd /opt/zoom-headless-meeting && tar -xzf $PACKAGE_NAME && chmod +x setup-flexible-bots.sh generate-flexible-bots.sh auto-setup-bots.sh update-compose-zak.py && rm $PACKAGE_NAME\""
echo ""

