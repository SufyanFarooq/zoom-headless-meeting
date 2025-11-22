# Build Image on Server - Quick Guide

## Problem
Docker Compose build is running out of memory during OpenSSL compilation.

## Solution
Build the image separately first, then use the pre-built image.

## Quick Commands (Run on Server)

### Step 1: Build Image
```bash
docker build -t zoom-bot:latest . --platform linux/amd64
```

This will take 10-30 minutes depending on server speed and memory.

### Step 2: Update Compose File
```bash
# Backup compose file
cp compose-50-bots.yaml compose-50-bots.yaml.backup

# Replace build: ./ with image: zoom-bot:latest
sed -i 's|build: \./|image: zoom-bot:latest|' compose-50-bots.yaml

# Remove platform line (not needed with image)
sed -i '/platform: linux\/amd64/d' compose-50-bots.yaml
```

### Step 3: Start Container
```bash
docker compose -f compose-50-bots.yaml up -d bot-1
```

## Alternative: Create Script on Server

If you want to use the script:

```bash
# Create build-image.sh
cat > build-image.sh << 'EOF'
#!/bin/bash
set -e
IMAGE_NAME="zoom-bot"
IMAGE_TAG="latest"
echo "🔨 Building Docker image: ${IMAGE_NAME}:${IMAGE_TAG}"
docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" --platform linux/amd64 .
if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo ""
    echo "Next: Update compose file and start containers"
else
    echo "❌ Build failed!"
    exit 1
fi
EOF

chmod +x build-image.sh
./build-image.sh
```

## Create update-compose script on server:

```bash
cat > update-compose-to-use-image.sh << 'EOF'
#!/bin/bash
set -e
COMPOSE_FILE="compose-50-bots.yaml"
IMAGE_NAME="zoom-bot:latest"

if [ ! -f "$COMPOSE_FILE" ]; then
    echo "❌ Error: $COMPOSE_FILE not found"
    exit 1
fi

echo "🔄 Updating $COMPOSE_FILE to use pre-built image: $IMAGE_NAME"
cp "$COMPOSE_FILE" "${COMPOSE_FILE}.backup"

# Replace build: ./ with image: zoom-bot:latest
sed -i 's|build: \./|image: zoom-bot:latest|' "$COMPOSE_FILE"

# Remove platform line
sed -i '/platform: linux\/amd64/d' "$COMPOSE_FILE"

echo "✅ Done! Now containers will use pre-built image"
echo "   Backup saved to: ${COMPOSE_FILE}.backup"
EOF

chmod +x update-compose-to-use-image.sh
./update-compose-to-use-image.sh
```

## Verify

After updating, check the compose file:
```bash
grep -A 2 "bot-1:" compose-50-bots.yaml | head -5
```

Should show:
```yaml
  bot-1:
    image: zoom-bot:latest
    container_name: zoom-bot-1
```

Instead of:
```yaml
  bot-1:
    build: ./
    platform: linux/amd64
```

## Troubleshooting

### Build fails with memory error
- Increase Docker memory limit in Docker settings
- Or build on a machine with more RAM and transfer the image

### Build takes too long
- This is normal for first build (10-30 minutes)
- Subsequent builds will be faster due to caching

### Image not found after build
```bash
# Check if image exists
docker images | grep zoom-bot

# If not found, rebuild
docker build -t zoom-bot:latest . --platform linux/amd64
```

