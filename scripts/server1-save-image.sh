#!/bin/bash

# Script to save Docker image on Server 1
# Run this on Server 1

set -e

IMAGE_NAME="zoom-bot:latest"
IMAGE_FILE="zoom-bot-image.tar.gz"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Save Docker Image - Server 1"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if image exists
echo "📋 Step 1: Checking if image exists..."
if ! docker images "$IMAGE_NAME" --format "{{.Repository}}:{{.Tag}}" | grep -q "$IMAGE_NAME"; then
    echo "❌ Image $IMAGE_NAME not found"
    echo ""
    echo "Build image first:"
    echo "   docker build -t $IMAGE_NAME ."
    echo ""
    read -p "Build image now? (y/n): " BUILD_NOW
    if [ "$BUILD_NOW" = "y" ]; then
        echo "Building image (this may take 10-30 minutes)..."
        docker build -t "$IMAGE_NAME" .
    else
        exit 1
    fi
fi

IMAGE_SIZE=$(docker images "$IMAGE_NAME" --format "{{.Size}}")
IMAGE_ID=$(docker images "$IMAGE_NAME" --format "{{.ID}}")
echo "✅ Image found: $IMAGE_NAME"
echo "   Size: $IMAGE_SIZE"
echo "   ID: $IMAGE_ID"
echo ""

# Save image
echo "📋 Step 2: Saving image..."
echo "This may take a few minutes..."
docker save "$IMAGE_NAME" | gzip > "$IMAGE_FILE"

FILE_SIZE=$(du -h "$IMAGE_FILE" | cut -f1)
FILE_PATH=$(realpath "$IMAGE_FILE")
echo "✅ Image saved: $IMAGE_FILE"
echo "   Size: $FILE_SIZE"
echo "   Location: $FILE_PATH"
echo ""

# Check available methods
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📤 Copy to Server 2"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if command -v gcloud > /dev/null 2>&1; then
    echo "Method 1: Using gcloud (Recommended)"
    echo ""
    echo "Run this command:"
    echo "   gcloud compute scp $IMAGE_FILE zoom-bots-server:/tmp/ --zone=us-east1-c"
    echo ""
    read -p "Copy now using gcloud? (y/n): " COPY_NOW
    if [ "$COPY_NOW" = "y" ]; then
        gcloud compute scp "$IMAGE_FILE" zoom-bots-server:/tmp/ --zone=us-east1-c
        echo ""
        echo "✅ Image copied to Server 2"
        echo ""
        echo "📋 Now on Server 2, run:"
        echo "   gunzip -c /tmp/$IMAGE_FILE | docker load"
        echo "   docker images | grep zoom-bot"
        echo "   rm /tmp/$IMAGE_FILE"
    fi
elif command -v scp > /dev/null 2>&1; then
    echo "Method 2: Using scp"
    echo ""
    echo "Run this command:"
    echo "   scp $IMAGE_FILE user@35.227.36.166:/tmp/"
    echo ""
else
    echo "Method 3: Browser SSH Upload"
    echo ""
    echo "1. Download $IMAGE_FILE from Server 1"
    echo "2. GCP Browser SSH → Upload file"
    echo "3. Upload to Server 2 (/tmp/)"
    echo "4. On Server 2: gunzip -c /tmp/$IMAGE_FILE | docker load"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Image Saved!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📦 File: $IMAGE_FILE"
echo "📊 Size: $FILE_SIZE"
echo "📁 Location: $FILE_PATH"
echo ""

