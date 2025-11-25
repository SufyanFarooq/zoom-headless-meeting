#!/bin/bash
# Start Docker daemon on macOS

echo "🐳 Starting Docker..."

# Check if Docker Desktop is installed
if [ -d "/Applications/Docker.app" ]; then
    echo "   Found Docker Desktop"
    
    # Try to open Docker Desktop
    if open -a Docker 2>/dev/null; then
        echo "   ✅ Docker Desktop is starting..."
        echo "   ⏳ Please wait 30-60 seconds for Docker to fully start"
        echo ""
        echo "   You can check status with:"
        echo "   docker ps"
    else
        echo "   ❌ Failed to start Docker Desktop"
        echo "   Please start Docker Desktop manually from Applications"
    fi
else
    echo "   ❌ Docker Desktop not found in /Applications"
    echo "   Please install Docker Desktop from:"
    echo "   https://www.docker.com/products/docker-desktop"
fi
