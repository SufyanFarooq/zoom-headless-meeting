#!/bin/bash

# Script to create package locally and provide upload instructions
# For Browser SSH upload to GCP Server 2

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Create Package for Browser Upload"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Get project root
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

PACKAGE_NAME="bot-server-only.tar.gz"

# Step 1: Create package
echo "📝 Step 1: Creating package..."
if [ -f "$PACKAGE_NAME" ]; then
    read -p "Package already exists. Recreate? (y/n): " RECREATE
    if [ "$RECREATE" = "y" ]; then
        rm -f "$PACKAGE_NAME"
        ./scripts/prepare-bot-server-package.sh
    else
        echo "✅ Using existing package"
    fi
else
    ./scripts/prepare-bot-server-package.sh
fi

if [ ! -f "$PACKAGE_NAME" ]; then
    echo "❌ Package creation failed"
    exit 1
fi

# Get package info
PACKAGE_SIZE=$(du -h "$PACKAGE_NAME" | cut -f1)
PACKAGE_PATH=$(realpath "$PACKAGE_NAME")

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Package Created Successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📦 Package Details:"
echo "   Name: $PACKAGE_NAME"
echo "   Size: $PACKAGE_SIZE"
echo "   Location: $PACKAGE_PATH"
echo ""

# Step 2: Upload instructions
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📤 Upload Instructions (Browser SSH)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Method 1: Browser SSH Upload (Easiest)"
echo ""
echo "1. Open GCP Console:"
echo "   https://console.cloud.google.com/compute/instances"
echo ""
echo "2. Click 'SSH' button next to 'zoom-bots-server'"
echo ""
echo "3. In browser SSH terminal:"
echo "   - Click '⚙️ Settings' icon (top-right)"
echo "   - Click 'Upload file'"
echo "   - Select this file:"
echo "     $PACKAGE_PATH"
echo ""
echo "4. File will upload to: ~/bot-server-only.tar.gz"
echo ""
echo "5. Then run these commands in browser SSH:"
echo ""
cat << 'EOF'
   # Move to /opt
   sudo mkdir -p /opt
   sudo mv ~/bot-server-only.tar.gz /opt/
   cd /opt
   
   # Extract
   sudo tar -xzf bot-server-only.tar.gz
   cd zoom-headless-meeting
   sudo chown -R $USER:$USER .
   
   # Create .env
   cat > .env << 'ENVEOF'
BOT_SERVER_PORT=3001
SERVER_CAPACITY=10
BOT_PROJECT_DIR=/app/bot-project
HOST_PROJECT_PATH=/opt/zoom-headless-meeting
ENVEOF
   
   # Install Docker (if needed)
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh
   sudo usermod -aG docker $USER
   
   # Start bot server
   docker compose -f docker-compose.bot-server.yml up -d
   
   # Verify
   curl http://localhost:3001/health
EOF

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Alternative: Using gcloud (if installed)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Run this command:"
echo ""
echo "  gcloud compute scp $PACKAGE_NAME zoom-bots-server:/opt/ --zone=us-east1-c"
echo ""
echo "Then SSH and extract:"
echo ""
echo "  gcloud compute ssh zoom-bots-server --zone=us-east1-c"
echo "  cd /opt && tar -xzf bot-server-only.tar.gz"
echo "  cd zoom-headless-meeting"
echo ""

# Check if file is too large
PACKAGE_SIZE_BYTES=$(stat -f%z "$PACKAGE_NAME" 2>/dev/null || stat -c%s "$PACKAGE_NAME" 2>/dev/null)
PACKAGE_SIZE_MB=$((PACKAGE_SIZE_BYTES / 1024 / 1024))

if [ "$PACKAGE_SIZE_MB" -gt 500 ]; then
    echo "⚠️  Warning: Package is large ($PACKAGE_SIZE_MB MB)"
    echo "   Consider using Cloud Storage for large files:"
    echo ""
    echo "   # Upload to Cloud Storage"
    echo "   gsutil cp $PACKAGE_NAME gs://your-bucket/"
    echo ""
    echo "   # Download on Server 2"
    echo "   gsutil cp gs://your-bucket/$PACKAGE_NAME /opt/"
    echo ""
fi

echo ""
echo "✅ Package ready for upload!"
echo "📁 File location: $PACKAGE_PATH"
echo ""

