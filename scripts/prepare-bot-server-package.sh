#!/bin/bash

# Script to create minimal package for Bot Server Only (Server 2)
# This creates a tar.gz with only files needed for bot server

set -e

PACKAGE_NAME="bot-server-only.tar.gz"
TEMP_DIR=$(mktemp -d)

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Creating Bot Server Package"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Get project root directory
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "📁 Project root: $PROJECT_ROOT"
echo "📦 Package name: $PACKAGE_NAME"
echo ""

# Create temporary directory structure
mkdir -p "$TEMP_DIR/zoom-headless-meeting"

echo "📋 Copying required files..."

# Required directories
echo "  ✅ bot-server/ - Bot server API"
cp -r bot-server "$TEMP_DIR/zoom-headless-meeting/"

echo "  ✅ build/ - Bot executable (REQUIRED)"
if [ -d "build" ]; then
    cp -r build "$TEMP_DIR/zoom-headless-meeting/"
else
    echo "  ⚠️  WARNING: build/ directory not found!"
    echo "     Bot server needs build/zoomsdk executable"
fi

echo "  ✅ lib/ - Zoom SDK libraries (REQUIRED)"
if [ -d "lib" ]; then
    cp -r lib "$TEMP_DIR/zoom-headless-meeting/"
else
    echo "  ⚠️  WARNING: lib/ directory not found!"
    echo "     Bot server needs lib/zoomsdk/"
fi

echo "  ✅ videos/ - Video files"
if [ -d "videos" ]; then
    cp -r videos "$TEMP_DIR/zoom-headless-meeting/"
else
    mkdir -p "$TEMP_DIR/zoom-headless-meeting/videos"
    echo "  ℹ️  Created empty videos/ directory"
fi

echo "  ✅ profile-pics/ - Name files"
if [ -d "profile-pics" ]; then
    cp -r profile-pics "$TEMP_DIR/zoom-headless-meeting/"
else
    echo "  ⚠️  WARNING: profile-pics/ directory not found!"
fi

echo "  ✅ bin/ - Entry scripts"
if [ -d "bin" ]; then
    cp -r bin "$TEMP_DIR/zoom-headless-meeting/"
else
    echo "  ⚠️  WARNING: bin/ directory not found!"
fi

# Required files
echo "  ✅ docker-compose.bot-server.yml"
cp docker-compose.bot-server.yml "$TEMP_DIR/zoom-headless-meeting/" 2>/dev/null || echo "  ⚠️  docker-compose.bot-server.yml not found"

echo "  ✅ Dockerfile.bot-server"
cp Dockerfile.bot-server "$TEMP_DIR/zoom-headless-meeting/" 2>/dev/null || echo "  ⚠️  Dockerfile.bot-server not found"

echo "  ✅ package.json"
cp package.json "$TEMP_DIR/zoom-headless-meeting/" 2>/dev/null || echo "  ⚠️  package.json not found"

echo "  ✅ compose-50-bots.yaml"
cp compose-50-bots.yaml "$TEMP_DIR/zoom-headless-meeting/" 2>/dev/null || echo "  ⚠️  compose-50-bots.yaml not found"

echo "  ✅ config.toml"
cp config.toml "$TEMP_DIR/zoom-headless-meeting/" 2>/dev/null || echo "  ⚠️  config.toml not found"

# Required scripts for bot creation
echo "  ✅ setup-flexible-bots.sh (REQUIRED)"
cp setup-flexible-bots.sh "$TEMP_DIR/zoom-headless-meeting/" 2>/dev/null || echo "  ⚠️  setup-flexible-bots.sh not found"

echo "  ✅ generate-flexible-bots.sh (REQUIRED)"
cp generate-flexible-bots.sh "$TEMP_DIR/zoom-headless-meeting/" 2>/dev/null || echo "  ⚠️  generate-flexible-bots.sh not found"

echo "  ✅ auto-setup-bots.sh (REQUIRED)"
cp auto-setup-bots.sh "$TEMP_DIR/zoom-headless-meeting/" 2>/dev/null || echo "  ⚠️  auto-setup-bots.sh not found"

echo "  ✅ update-compose-zak.py (REQUIRED)"
cp update-compose-zak.py "$TEMP_DIR/zoom-headless-meeting/" 2>/dev/null || echo "  ⚠️  update-compose-zak.py not found"

# Optional but useful
if [ -f ".dockerignore" ]; then
    echo "  ✅ .dockerignore"
    cp .dockerignore "$TEMP_DIR/zoom-headless-meeting/"
fi

if [ -f "CMakeLists.txt" ]; then
    echo "  ✅ CMakeLists.txt (for rebuilding if needed)"
    cp CMakeLists.txt "$TEMP_DIR/zoom-headless-meeting/"
fi

# Create .env.example for Server 2
echo "  ✅ Creating .env.example for Server 2"
cat > "$TEMP_DIR/zoom-headless-meeting/.env.example" << 'EOF'
# Bot Server Only Configuration
BOT_SERVER_PORT=3001
SERVER_CAPACITY=10
BOT_PROJECT_DIR=/app/bot-project
HOST_PROJECT_PATH=/opt/zoom-headless-meeting
EOF

# Create README for Server 2
echo "  ✅ Creating README-SERVER2.md"
cat > "$TEMP_DIR/zoom-headless-meeting/README-SERVER2.md" << 'EOF'
# Bot Server Only Setup

This is a minimal installation for Server 2 (Bot Server Only).

## Quick Setup

1. Extract files:
   ```bash
   tar -xzf bot-server-only.tar.gz
   cd zoom-headless-meeting
   ```

2. Create .env:
   ```bash
   cp .env.example .env
   nano .env  # Edit HOST_PROJECT_PATH if needed
   ```

3. Start bot server:
   ```bash
   docker compose -f docker-compose.bot-server.yml up -d
   ```

4. Verify:
   ```bash
   curl http://localhost:3001/health
   ```

5. Register on Server 1:
   ```bash
   curl -X POST http://SERVER1_IP:3000/api/bot-servers \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer YOUR_TOKEN" \
     -d '{
       "serverName": "server-2",
       "serverUrl": "http://SERVER2_IP:3001",
       "capacity": 10,
       "priority": 2
     }'
   ```

## Required Files

- ✅ bot-server/ - Bot server API
- ✅ build/ - Bot executable (zoomsdk)
- ✅ lib/ - Zoom SDK libraries
- ✅ videos/ - Video files
- ✅ profile-pics/ - Name files
- ✅ bin/ - Entry scripts

## Notes

- No database needed
- No API server needed
- No dashboard UI needed
- Bot server receives credentials from Server 1's API
EOF

# Create package
echo ""
echo "📦 Creating package..."
cd "$TEMP_DIR"
tar -czf "$PROJECT_ROOT/$PACKAGE_NAME" zoom-headless-meeting/

# Get package size
PACKAGE_SIZE=$(du -h "$PROJECT_ROOT/$PACKAGE_NAME" | cut -f1)

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Package created successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📦 Package: $PROJECT_ROOT/$PACKAGE_NAME"
echo "📊 Size: $PACKAGE_SIZE"
echo ""
echo "📋 Contents:"
echo "  ✅ bot-server/ - Bot server API"
echo "  ✅ build/ - Bot executable"
echo "  ✅ lib/ - Zoom SDK"
echo "  ✅ videos/ - Video files"
echo "  ✅ profile-pics/ - Name files"
echo "  ✅ bin/ - Entry scripts"
echo "  ✅ Docker files"
echo "  ✅ Configuration files"
echo ""
echo "📤 To transfer to Server 2:"
echo "   scp $PACKAGE_NAME user@server2:/opt/"
echo ""
echo "📥 On Server 2, extract:"
echo "   cd /opt"
echo "   tar -xzf $PACKAGE_NAME"
echo "   cd zoom-headless-meeting"
echo "   cp .env.example .env"
echo "   docker compose -f docker-compose.bot-server.yml up -d"
echo ""

# Cleanup
rm -rf "$TEMP_DIR"

