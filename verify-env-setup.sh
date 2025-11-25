#!/bin/bash
# Verify HOST_PROJECT_PATH is set correctly

echo "🔍 Verifying HOST_PROJECT_PATH setup..."
echo ""

# Check .env file
if [ -f .env ]; then
    echo "✅ .env file found"
    if grep -q "HOST_PROJECT_PATH" .env; then
        echo "✅ HOST_PROJECT_PATH found in .env:"
        grep "HOST_PROJECT_PATH" .env
    else
        echo "❌ HOST_PROJECT_PATH not found in .env"
    fi
else
    echo "⚠️  .env file not found"
fi

echo ""
echo "📋 Checking docker-compose.full.yml:"
if grep -q "HOST_PROJECT_PATH" docker-compose.full.yml; then
    echo "✅ HOST_PROJECT_PATH configured in docker-compose:"
    grep "HOST_PROJECT_PATH" docker-compose.full.yml
else
    echo "❌ HOST_PROJECT_PATH not in docker-compose.full.yml"
fi

echo ""
echo "🔍 Testing environment variable:"
# Source .env if it exists
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
    echo "HOST_PROJECT_PATH from .env: $HOST_PROJECT_PATH"
fi

echo ""
echo "📁 Checking if path exists:"
if [ -n "$HOST_PROJECT_PATH" ]; then
    if [ -d "$HOST_PROJECT_PATH" ]; then
        echo "✅ Directory exists: $HOST_PROJECT_PATH"
        if [ -f "$HOST_PROJECT_PATH/bin/entry-bot-optimized.sh" ]; then
            echo "✅ Entry script found!"
        else
            echo "❌ Entry script not found at: $HOST_PROJECT_PATH/bin/entry-bot-optimized.sh"
        fi
    else
        echo "❌ Directory does not exist: $HOST_PROJECT_PATH"
    fi
fi

echo ""
echo "✅ Verification complete!"
