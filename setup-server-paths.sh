#!/bin/bash
# Setup correct server paths

set -e

echo "🔧 Setting up server paths..."
echo ""

# Get current directory (where script is run from)
CURRENT_DIR=$(pwd)
echo "Current directory: $CURRENT_DIR"

# Check if this is the project directory
if [ -f "compose-50-bots.yaml" ] && [ -f "bin/entry-bot-optimized.sh" ]; then
    echo "✅ This appears to be the project directory"
    PROJECT_DIR="$CURRENT_DIR"
else
    echo "❌ Project files not found in current directory"
    echo "Please run this script from the project root directory"
    exit 1
fi

echo ""
echo "Project directory: $PROJECT_DIR"
echo ""

# Check if entry script exists
if [ -f "$PROJECT_DIR/bin/entry-bot-optimized.sh" ]; then
    echo "✅ Entry script found: $PROJECT_DIR/bin/entry-bot-optimized.sh"
    ls -lh "$PROJECT_DIR/bin/entry-bot-optimized.sh"
else
    echo "❌ Entry script not found!"
    exit 1
fi

echo ""
echo "📝 Update docker-compose.full.yml with correct path:"
echo "   HOST_PROJECT_PATH: \"$PROJECT_DIR\""
echo ""

# Option to update docker-compose.full.yml
read -p "Update docker-compose.full.yml? (y/n): " UPDATE
if [ "$UPDATE" = "y" ]; then
    # Update HOST_PROJECT_PATH in docker-compose.full.yml
    sed -i "s|HOST_PROJECT_PATH:.*|HOST_PROJECT_PATH: \"$PROJECT_DIR\"|" docker-compose.full.yml
    echo "✅ Updated docker-compose.full.yml"
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Restart bot-server: docker compose -f docker-compose.full.yml restart bot-server"
echo "  2. Clean old containers: docker ps -a --filter 'name=zoom-bot' -q | xargs -r docker rm -f"
echo "  3. Create meeting again"
