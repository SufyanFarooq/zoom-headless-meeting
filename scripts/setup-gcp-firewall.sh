#!/bin/bash

# Script to setup GCP firewall rule for bot server
# Handles authentication and creates firewall rule

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔥 GCP Firewall Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if gcloud is installed
if ! command -v gcloud > /dev/null 2>&1; then
    echo "❌ gcloud CLI not found"
    echo ""
    echo "Install gcloud:"
    echo "  curl https://sdk.cloud.google.com | bash"
    echo "  exec -l \$SHELL"
    exit 1
fi

echo "✅ gcloud CLI found"
echo ""

# Check authentication
echo "📋 Checking authentication..."
CURRENT_USER=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | head -1)

if [ -z "$CURRENT_USER" ]; then
    echo "⚠️  Not authenticated"
    echo ""
    echo "Logging in..."
    gcloud auth login
else
    echo "✅ Authenticated as: $CURRENT_USER"
fi
echo ""

# Check project
echo "📋 Checking project..."
CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null)

if [ -z "$CURRENT_PROJECT" ] || [ "$CURRENT_PROJECT" = "(unset)" ]; then
    echo "⚠️  No project set"
    echo ""
    echo "Available projects:"
    gcloud projects list --format="table(projectId,name)"
    echo ""
    read -p "Enter project ID: " PROJECT_ID
    gcloud config set project "$PROJECT_ID"
else
    echo "✅ Current project: $CURRENT_PROJECT"
    read -p "Use this project? (y/n): " USE_PROJECT
    if [ "$USE_PROJECT" != "y" ]; then
        echo ""
        echo "Available projects:"
        gcloud projects list --format="table(projectId,name)"
        echo ""
        read -p "Enter project ID: " PROJECT_ID
        gcloud config set project "$PROJECT_ID"
    fi
fi
echo ""

# Check if firewall rule already exists
RULE_NAME="allow-bot-server"
echo "📋 Checking if firewall rule exists..."
if gcloud compute firewall-rules describe "$RULE_NAME" > /dev/null 2>&1; then
    echo "⚠️  Firewall rule '$RULE_NAME' already exists"
    echo ""
    echo "Current rule:"
    gcloud compute firewall-rules describe "$RULE_NAME"
    echo ""
    read -p "Delete and recreate? (y/n): " RECREATE
    if [ "$RECREATE" = "y" ]; then
        echo "Deleting existing rule..."
        gcloud compute firewall-rules delete "$RULE_NAME" --quiet
    else
        echo "✅ Using existing firewall rule"
        exit 0
    fi
fi
echo ""

# Get source IP range
echo "📋 Source IP Configuration:"
echo "1. Allow from anywhere (0.0.0.0/0) - Less secure"
echo "2. Allow from specific IP (Server 1 IP) - More secure"
read -p "Choose option (1/2): " SOURCE_OPTION

if [ "$SOURCE_OPTION" = "2" ]; then
    read -p "Enter Server 1 IP (e.g., 192.168.1.100): " SERVER1_IP
    SOURCE_RANGES="${SERVER1_IP}/32"
    echo "✅ Will allow from: $SOURCE_RANGES"
else
    SOURCE_RANGES="0.0.0.0/0"
    echo "✅ Will allow from: anywhere (0.0.0.0/0)"
fi
echo ""

# Create firewall rule
echo "📝 Creating firewall rule..."
echo "   Name: $RULE_NAME"
echo "   Port: tcp:3001"
echo "   Source: $SOURCE_RANGES"
echo ""

if gcloud compute firewall-rules create "$RULE_NAME" \
  --allow tcp:3001 \
  --source-ranges "$SOURCE_RANGES" \
  --description "Allow bot server API on port 3001" \
  --direction INGRESS \
  --priority 1000; then
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ Firewall Rule Created Successfully!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    echo "📋 Rule Details:"
    gcloud compute firewall-rules describe "$RULE_NAME"
    echo ""
    
    echo "✅ Test connectivity:"
    echo "   curl http://35.227.36.166:3001/health"
    echo ""
    
else
    echo ""
    echo "❌ Failed to create firewall rule"
    echo ""
    echo "💡 Alternative: Create manually via GCP Console"
    echo "   1. Go to: https://console.cloud.google.com/networking/firewalls"
    echo "   2. Click 'Create Firewall Rule'"
    echo "   3. Name: allow-bot-server"
    echo "   4. Port: tcp:3001"
    echo "   5. Source: $SOURCE_RANGES"
    echo "   6. Create"
    echo ""
    exit 1
fi

