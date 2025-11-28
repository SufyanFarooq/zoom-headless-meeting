#!/bin/bash

# Script to copy Dockerfile to Server 1
# Run this on Local Machine

set -e

SERVER1_IP="${SERVER1_IP:-}"
SERVER1_USER="${SERVER1_USER:-root}"
SERVER1_PATH="/opt/zoom-headless-meeting"

if [ -z "$SERVER1_IP" ]; then
    echo "Usage: SERVER1_IP=YOUR_SERVER1_IP ./copy-dockerfile-to-server1.sh"
    echo ""
    echo "Example:"
    echo "  SERVER1_IP=192.168.1.100 ./copy-dockerfile-to-server1.sh"
    echo ""
    echo "Optional:"
    echo "  SERVER1_USER=root SERVER1_IP=192.168.1.100 ./copy-dockerfile-to-server1.sh"
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Copy Dockerfile to Server 1"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Server 1 IP: $SERVER1_IP"
echo "Server 1 User: $SERVER1_USER"
echo "Server 1 Path: $SERVER1_PATH"
echo ""

# Check if Dockerfile exists locally
if [ ! -f "Dockerfile" ]; then
    echo "❌ Dockerfile not found in current directory"
    echo ""
    echo "Please run this script from the project root directory"
    echo "   cd /path/to/meetingsdk-headless-linux-sample"
    echo "   ./scripts/copy-dockerfile-to-server1.sh"
    exit 1
fi

echo "✅ Dockerfile found locally"
echo ""

# Test SSH connection
echo "📋 Testing SSH connection..."
if ssh -o ConnectTimeout=5 -o BatchMode=yes "${SERVER1_USER}@${SERVER1_IP}" "echo 'SSH connection successful'" 2>/dev/null; then
    echo "✅ SSH connection successful"
else
    echo "⚠️  SSH connection test failed"
    echo ""
    echo "Please ensure:"
    echo "   1. SSH key is configured"
    echo "   2. Server 1 is accessible"
    echo "   3. User has permissions"
    echo ""
    read -p "Continue anyway? (y/n): " CONTINUE
    if [ "$CONTINUE" != "y" ]; then
        exit 1
    fi
fi
echo ""

# Check if directory exists on Server 1
echo "📋 Checking Server 1 directory..."
if ssh "${SERVER1_USER}@${SERVER1_IP}" "[ -d '$SERVER1_PATH' ]" 2>/dev/null; then
    echo "✅ Directory exists: $SERVER1_PATH"
else
    echo "⚠️  Directory does not exist: $SERVER1_PATH"
    echo ""
    read -p "Create directory? (y/n): " CREATE_DIR
    if [ "$CREATE_DIR" = "y" ]; then
        ssh "${SERVER1_USER}@${SERVER1_IP}" "mkdir -p $SERVER1_PATH"
        echo "✅ Directory created"
    else
        echo "❌ Cannot proceed without directory"
        exit 1
    fi
fi
echo ""

# Copy Dockerfile
echo "📋 Copying Dockerfile..."
scp Dockerfile "${SERVER1_USER}@${SERVER1_IP}:${SERVER1_PATH}/"

if [ $? -eq 0 ]; then
    echo "✅ Dockerfile copied successfully"
    echo ""
    
    # Verify on Server 1
    echo "📋 Verifying on Server 1..."
    if ssh "${SERVER1_USER}@${SERVER1_IP}" "[ -f '${SERVER1_PATH}/Dockerfile' ]" 2>/dev/null; then
        echo "✅ Dockerfile verified on Server 1"
        echo ""
        
        # Show file info
        ssh "${SERVER1_USER}@${SERVER1_IP}" "ls -lh ${SERVER1_PATH}/Dockerfile"
        echo ""
        
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "✅ Success!"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "Next steps on Server 1:"
        echo "   1. SSH to Server 1:"
        echo "      ssh ${SERVER1_USER}@${SERVER1_IP}"
        echo ""
        echo "   2. Go to project directory:"
        echo "      cd $SERVER1_PATH"
        echo ""
        echo "   3. Build image:"
        echo "      docker build -t zoom-bot:latest . --platform linux/amd64"
        echo ""
    else
        echo "⚠️  Could not verify Dockerfile on Server 1"
    fi
else
    echo "❌ Failed to copy Dockerfile"
    exit 1
fi

