#!/bin/bash

# Script to copy zoom-bot Docker image from Server 1 to Server 2
# Run this on Server 1

set -e

SERVER2_IP="${SERVER2_IP:-35.227.36.166}"
SERVER2_USER="${SERVER2_USER:-sufyanmaviya400}"
GCP_INSTANCE="${GCP_INSTANCE:-zoom-bots-server}"
GCP_ZONE="${GCP_ZONE:-us-east1-c}"

IMAGE_NAME="zoom-bot:latest"
IMAGE_FILE="zoom-bot-image.tar.gz"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Copy Docker Image to Server 2"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if image exists locally
echo "📋 Step 1: Checking if image exists..."
if ! docker images "$IMAGE_NAME" --format "{{.Repository}}:{{.Tag}}" | grep -q "$IMAGE_NAME"; then
    echo "❌ Image $IMAGE_NAME not found locally"
    echo ""
    echo "Build image first:"
    echo "   docker build -t $IMAGE_NAME ."
    exit 1
fi

IMAGE_SIZE=$(docker images "$IMAGE_NAME" --format "{{.Size}}")
echo "✅ Image found: $IMAGE_NAME ($IMAGE_SIZE)"
echo ""

# Save image
echo "📋 Step 2: Saving image..."
echo "This may take a few minutes..."
docker save "$IMAGE_NAME" | gzip > "$IMAGE_FILE"

FILE_SIZE=$(du -h "$IMAGE_FILE" | cut -f1)
echo "✅ Image saved: $IMAGE_FILE ($FILE_SIZE)"
echo ""

# Check if gcloud is available
if command -v gcloud > /dev/null 2>&1; then
    echo "📋 Step 3: Copying to Server 2 (GCP)..."
    echo "Using gcloud..."
    
    gcloud compute scp "$IMAGE_FILE" "${GCP_INSTANCE}:/tmp/" --zone="$GCP_ZONE"
    
    echo ""
    echo "📋 Step 4: Loading image on Server 2..."
    gcloud compute ssh "$GCP_INSTANCE" --zone="$GCP_ZONE" --command="gunzip -c /tmp/$IMAGE_FILE | docker load && docker images | grep zoom-bot && rm /tmp/$IMAGE_FILE"
    
elif command -v scp > /dev/null 2>&1; then
    echo "📋 Step 3: Copying to Server 2..."
    echo "Using scp..."
    
    scp "$IMAGE_FILE" "${SERVER2_USER}@${SERVER2_IP}:/tmp/"
    
    echo ""
    echo "📋 Step 4: Loading image on Server 2..."
    ssh "${SERVER2_USER}@${SERVER2_IP}" "gunzip -c /tmp/$IMAGE_FILE | docker load && docker images | grep zoom-bot && rm /tmp/$IMAGE_FILE"
    
else
    echo "⚠️  Neither gcloud nor scp found"
    echo ""
    echo "Manual steps:"
    echo "1. Copy $IMAGE_FILE to Server 2"
    echo "2. On Server 2, run:"
    echo "   gunzip -c /tmp/$IMAGE_FILE | docker load"
    echo "   docker images | grep zoom-bot"
    echo "   rm /tmp/$IMAGE_FILE"
    exit 1
fi

# Cleanup
rm -f "$IMAGE_FILE"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Image Copied Successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Verify on Server 2:"
echo "   docker images | grep zoom-bot"
echo ""
echo "✅ Server 2 ready to create bots!"
echo ""

