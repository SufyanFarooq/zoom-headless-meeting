#!/bin/bash

# Script to setup Server 2 on Google Cloud Platform
# This script helps:
# 1. Generate SSH key for GCP
# 2. Copy SSH key to GCP VM
# 3. Copy bot-server package from Server 1 to Server 2

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 GCP Server 2 Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get GCP VM details
read -p "Enter GCP VM External IP (e.g., 35.227.36.166): " GCP_IP
if [ -z "$GCP_IP" ]; then
    echo -e "${RED}❌ GCP VM IP is required${NC}"
    exit 1
fi

read -p "Enter GCP VM username (default: your-gcp-username or use gcloud default): " GCP_USER
GCP_USER=${GCP_USER:-$(whoami)}

read -p "Enter GCP VM zone (e.g., us-east1-c, default: us-east1-c): " GCP_ZONE
GCP_ZONE=${GCP_ZONE:-us-east1-c}

read -p "Enter GCP VM instance name (e.g., zoom-bots-server): " GCP_INSTANCE_NAME
if [ -z "$GCP_INSTANCE_NAME" ]; then
    GCP_INSTANCE_NAME="zoom-bots-server"
fi

echo ""
echo "📋 Configuration:"
echo "  VM IP: $GCP_IP"
echo "  Username: $GCP_USER"
echo "  Zone: $GCP_ZONE"
echo "  Instance: $GCP_INSTANCE_NAME"
echo ""

# Check if gcloud is installed
if command -v gcloud > /dev/null 2>&1; then
    echo -e "${GREEN}✅ gcloud CLI found${NC}"
    USE_GCLOUD=true
else
    echo -e "${YELLOW}⚠️  gcloud CLI not found. Will use direct SSH${NC}"
    USE_GCLOUD=false
fi

# Step 1: Generate SSH key (if doesn't exist)
SSH_KEY_PATH="$HOME/.ssh/gcp_zoom_bots"
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo ""
    echo "📝 Step 1: Generating SSH key..."
    ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N "" -C "zoom-bots-server2"
    echo -e "${GREEN}✅ SSH key generated: $SSH_KEY_PATH${NC}"
else
    echo ""
    echo -e "${GREEN}✅ SSH key already exists: $SSH_KEY_PATH${NC}"
fi

# Step 2: Add SSH key to GCP VM
echo ""
echo "📝 Step 2: Adding SSH key to GCP VM..."

if [ "$USE_GCLOUD" = true ]; then
    echo "Using gcloud to add SSH key..."
    
    # Method 1: Using gcloud compute ssh (recommended)
    echo ""
    echo "Option 1: Using gcloud compute ssh (Recommended)"
    echo "Run this command:"
    echo ""
    echo "  gcloud compute ssh $GCP_INSTANCE_NAME --zone=$GCP_ZONE --command='echo \"SSH key added\"'"
    echo ""
    echo "Or manually add public key:"
    echo ""
    echo "  gcloud compute instances add-metadata $GCP_INSTANCE_NAME \\"
    echo "    --zone=$GCP_ZONE \\"
    echo "    --metadata-from-file ssh-keys=<(echo \"$GCP_USER:$(cat $SSH_KEY_PATH.pub)\")"
    echo ""
    
    read -p "Have you added SSH key to GCP VM? (y/n): " KEY_ADDED
    if [ "$KEY_ADDED" != "y" ]; then
        echo ""
        echo "📝 Manual steps to add SSH key:"
        echo "1. Go to GCP Console → Compute Engine → VM instances"
        echo "2. Click on your VM instance: $GCP_INSTANCE_NAME"
        echo "3. Click 'Edit'"
        echo "4. Scroll to 'SSH Keys' section"
        echo "5. Click 'Add Item'"
        echo "6. Paste this public key:"
        echo ""
        cat "$SSH_KEY_PATH.pub"
        echo ""
        echo "7. Click 'Save'"
        echo ""
        read -p "Press Enter after adding SSH key..."
    fi
else
    echo ""
    echo "📝 Manual steps to add SSH key:"
    echo "1. Go to GCP Console → Compute Engine → VM instances"
    echo "2. Click on your VM instance: $GCP_INSTANCE_NAME"
    echo "3. Click 'Edit'"
    echo "4. Scroll to 'SSH Keys' section"
    echo "5. Click 'Add Item'"
    echo "6. Paste this public key:"
    echo ""
    cat "$SSH_KEY_PATH.pub"
    echo ""
    echo "7. Click 'Save'"
    echo ""
    read -p "Press Enter after adding SSH key..."
fi

# Step 3: Test SSH connection
echo ""
echo "📝 Step 3: Testing SSH connection..."
echo "Attempting to connect to $GCP_USER@$GCP_IP..."

# Try SSH connection
if ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$GCP_USER@$GCP_IP" "echo 'SSH connection successful'" 2>/dev/null; then
    echo -e "${GREEN}✅ SSH connection successful!${NC}"
    SSH_WORKING=true
else
    echo -e "${YELLOW}⚠️  Direct SSH failed. Trying gcloud...${NC}"
    
    if [ "$USE_GCLOUD" = true ]; then
        if gcloud compute ssh "$GCP_INSTANCE_NAME" --zone="$GCP_ZONE" --command="echo 'SSH via gcloud successful'" 2>/dev/null; then
            echo -e "${GREEN}✅ SSH via gcloud successful!${NC}"
            SSH_WORKING=true
            USE_GCLOUD_SSH=true
        else
            echo -e "${RED}❌ SSH connection failed${NC}"
            echo ""
            echo "Troubleshooting:"
            echo "1. Check firewall rules allow SSH (port 22)"
            echo "2. Verify SSH key is added to VM"
            echo "3. Check VM is running"
            echo "4. Try: gcloud compute ssh $GCP_INSTANCE_NAME --zone=$GCP_ZONE"
            SSH_WORKING=false
        fi
    else
        SSH_WORKING=false
    fi
fi

# Step 4: Copy package to Server 2
if [ "$SSH_WORKING" = true ]; then
    echo ""
    echo "📝 Step 4: Copying bot-server package to Server 2..."
    
    # Check if package exists
    PACKAGE_NAME="bot-server-only.tar.gz"
    if [ ! -f "$PACKAGE_NAME" ]; then
        echo ""
        echo "📦 Creating bot-server package..."
        ./scripts/prepare-bot-server-package.sh
    fi
    
    if [ ! -f "$PACKAGE_NAME" ]; then
        echo -e "${RED}❌ Package not found: $PACKAGE_NAME${NC}"
        echo "Run: ./scripts/prepare-bot-server-package.sh"
        exit 1
    fi
    
    PACKAGE_SIZE=$(du -h "$PACKAGE_NAME" | cut -f1)
    echo "Package size: $PACKAGE_SIZE"
    echo "Copying to $GCP_USER@$GCP_IP:/opt/..."
    
    if [ "$USE_GCLOUD_SSH" = true ]; then
        # Use gcloud compute scp
        gcloud compute scp "$PACKAGE_NAME" "$GCP_INSTANCE_NAME:/opt/" --zone="$GCP_ZONE"
    else
        # Use regular scp with SSH key
        scp -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$PACKAGE_NAME" "$GCP_USER@$GCP_IP:/opt/"
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Package copied successfully!${NC}"
    else
        echo -e "${RED}❌ Failed to copy package${NC}"
        exit 1
    fi
    
    # Step 5: Extract and setup on Server 2
    echo ""
    echo "📝 Step 5: Setting up on Server 2..."
    
    SSH_CMD="cd /opt && tar -xzf $PACKAGE_NAME && cd zoom-headless-meeting && cp .env.example .env"
    
    if [ "$USE_GCLOUD_SSH" = true ]; then
        gcloud compute ssh "$GCP_INSTANCE_NAME" --zone="$GCP_ZONE" --command="$SSH_CMD"
    else
        ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$GCP_USER@$GCP_IP" "$SSH_CMD"
    fi
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${GREEN}✅ Setup Complete!${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📋 Next steps on Server 2:"
    echo ""
    echo "1. SSH to Server 2:"
    if [ "$USE_GCLOUD_SSH" = true ]; then
        echo "   gcloud compute ssh $GCP_INSTANCE_NAME --zone=$GCP_ZONE"
    else
        echo "   ssh -i $SSH_KEY_PATH $GCP_USER@$GCP_IP"
    fi
    echo ""
    echo "2. Edit .env file:"
    echo "   cd /opt/zoom-headless-meeting"
    echo "   nano .env"
    echo ""
    echo "   Add these:"
    echo "   BOT_SERVER_PORT=3001"
    echo "   SERVER_CAPACITY=10"
    echo "   BOT_PROJECT_DIR=/app/bot-project"
    echo "   HOST_PROJECT_PATH=/opt/zoom-headless-meeting"
    echo ""
    echo "3. Install Docker (if not installed):"
    echo "   curl -fsSL https://get.docker.com -o get-docker.sh"
    echo "   sudo sh get-docker.sh"
    echo ""
    echo "4. Start bot server:"
    echo "   cd /opt/zoom-headless-meeting"
    echo "   docker compose -f docker-compose.bot-server.yml up -d"
    echo ""
    echo "5. Verify:"
    echo "   curl http://localhost:3001/health"
    echo ""
    echo "6. Register on Server 1:"
    echo "   curl -X POST http://SERVER1_IP:3000/api/bot-servers \\"
    echo "     -H \"Content-Type: application/json\" \\"
    echo "     -d '{\"serverName\": \"server-2\", \"serverUrl\": \"http://$GCP_IP:3001\", \"capacity\": 10, \"priority\": 2}'"
    echo ""
else
    echo ""
    echo "⚠️  SSH setup incomplete. Please:"
    echo "1. Add SSH key to GCP VM manually"
    echo "2. Test SSH connection"
    echo "3. Run this script again"
fi

