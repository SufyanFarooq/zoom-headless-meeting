#!/bin/bash

# Script to extract and setup bot-server package on Server 2
# Run this on Server 2 (GCP) after uploading bot-server-only.tar.gz

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Setting up Bot Server on Server 2"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if package exists in home directory
PACKAGE_HOME="$HOME/bot-server-only.tar.gz"
PACKAGE_OPT="/opt/bot-server-only.tar.gz"
TARGET_DIR="/opt/zoom-headless-meeting"

# Check where package is located
if [ -f "$PACKAGE_HOME" ]; then
    PACKAGE_PATH="$PACKAGE_HOME"
    echo "✅ Found package in home directory: $PACKAGE_PATH"
elif [ -f "$PACKAGE_OPT" ]; then
    PACKAGE_PATH="$PACKAGE_OPT"
    echo "✅ Found package in /opt: $PACKAGE_PATH"
else
    echo "❌ Package not found!"
    echo "   Looking for: $PACKAGE_HOME or $PACKAGE_OPT"
    echo ""
    echo "Please upload bot-server-only.tar.gz first"
    exit 1
fi

# Get package size
PACKAGE_SIZE=$(du -h "$PACKAGE_PATH" | cut -f1)
echo "📦 Package size: $PACKAGE_SIZE"
echo ""

# Step 1: Create /opt/zoom-headless-meeting directory
echo "📝 Step 1: Creating target directory..."
sudo mkdir -p "$TARGET_DIR"
echo "✅ Created: $TARGET_DIR"
echo ""

# Step 2: Move package to /opt (if in home directory)
if [ "$PACKAGE_PATH" = "$PACKAGE_HOME" ]; then
    echo "📝 Step 2: Moving package to /opt..."
    sudo mv "$PACKAGE_HOME" "$PACKAGE_OPT"
    PACKAGE_PATH="$PACKAGE_OPT"
    echo "✅ Moved to: $PACKAGE_PATH"
    echo ""
fi

# Step 3: Extract package
echo "📝 Step 3: Extracting package..."
cd /opt
sudo tar -xzf "$PACKAGE_PATH"
echo "✅ Extracted to: $TARGET_DIR"
echo ""

# Step 4: Fix permissions
echo "📝 Step 4: Fixing permissions..."
sudo chown -R $USER:$USER "$TARGET_DIR"
sudo chmod +x "$TARGET_DIR/bin"/*.sh 2>/dev/null || true
echo "✅ Permissions fixed"
echo ""

# Step 5: Create .env file
echo "📝 Step 5: Creating .env file..."
cd "$TARGET_DIR"
cat > .env << 'EOF'
BOT_SERVER_PORT=3001
SERVER_CAPACITY=10
BOT_PROJECT_DIR=/app/bot-project
HOST_PROJECT_PATH=/opt/zoom-headless-meeting
EOF
echo "✅ Created .env file"
echo ""

# Step 6: Verify files
echo "📝 Step 6: Verifying extracted files..."
cd "$TARGET_DIR"
echo "Directory contents:"
ls -la | head -20
echo ""

# Check required directories
REQUIRED_DIRS=("bot-server" "build" "lib" "videos" "profile-pics" "bin")
MISSING_DIRS=()

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        MISSING_DIRS+=("$dir")
    fi
done

if [ ${#MISSING_DIRS[@]} -gt 0 ]; then
    echo "⚠️  Warning: Missing directories:"
    for dir in "${MISSING_DIRS[@]}"; do
        echo "   - $dir"
    done
    echo ""
else
    echo "✅ All required directories found"
    echo ""
fi

# Step 7: Check Docker
echo "📝 Step 7: Checking Docker..."
if command -v docker > /dev/null 2>&1; then
    echo "✅ Docker is installed"
    docker --version
    
    # Check if user is in docker group
    if groups | grep -q docker; then
        echo "✅ User is in docker group"
    else
        echo "⚠️  Adding user to docker group..."
        sudo usermod -aG docker $USER
        echo "✅ Added to docker group (logout/login required)"
    fi
else
    echo "⚠️  Docker not found. Installing..."
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sudo sh /tmp/get-docker.sh
    sudo usermod -aG docker $USER
    echo "✅ Docker installed"
    echo "⚠️  Please logout and login again for docker group to take effect"
fi
echo ""

# Step 8: Check if zoom-bot image exists
echo "📝 Step 8: Checking Docker images..."
if docker images | grep -q "zoom-bot.*latest"; then
    echo "✅ zoom-bot:latest image found"
else
    echo "⚠️  zoom-bot:latest image not found"
    echo "   You may need to build it:"
    echo "   cd $TARGET_DIR"
    echo "   docker build -t zoom-bot:latest ."
fi
echo ""

# Step 9: Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Setup Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Next Steps:"
echo ""
echo "1. If Docker group was added, logout and login:"
echo "   exit"
echo "   # Then SSH again"
echo ""
echo "2. Start bot server:"
echo "   cd $TARGET_DIR"
echo "   docker compose -f docker-compose.bot-server.yml up -d"
echo ""
echo "3. Verify bot server is running:"
echo "   curl http://localhost:3001/health"
echo ""
echo "4. Check logs (if needed):"
echo "   docker compose -f docker-compose.bot-server.yml logs -f"
echo ""
echo "5. Register Server 2 on Server 1:"
echo "   curl -X POST http://SERVER1_IP:3000/api/bot-servers \\"
echo "     -H \"Content-Type: application/json\" \\"
echo "     -d '{\"serverName\": \"server-2\", \"serverUrl\": \"http://35.227.36.166:3001\", \"capacity\": 10, \"priority\": 2}'"
echo ""

