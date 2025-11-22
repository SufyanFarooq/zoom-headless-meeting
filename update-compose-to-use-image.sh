#!/bin/bash

# Update compose-50-bots.yaml to use pre-built image instead of building

set -e

COMPOSE_FILE="compose-50-bots.yaml"
IMAGE_NAME="zoom-bot:latest"

if [ ! -f "$COMPOSE_FILE" ]; then
    echo "❌ Error: $COMPOSE_FILE not found"
    exit 1
fi

echo "🔄 Updating $COMPOSE_FILE to use pre-built image: $IMAGE_NAME"
echo ""

# Create backup
cp "$COMPOSE_FILE" "${COMPOSE_FILE}.backup"

# Replace build: ./ with image: zoom-bot:latest
# This uses Python to replace the build section with image section
python3 << PYTHON_SCRIPT
import re

compose_file = "$COMPOSE_FILE"
image_name = "$IMAGE_NAME"

with open(compose_file, 'r') as f:
    content = f.read()

# Pattern to match:
#   build: ./
#   platform: linux/amd64
# Replace with:
#   image: zoom-bot:latest

# Use regex to replace build section (multiline)
pattern = r'    build: \.\/\n    platform: linux/amd64'
replacement = f'    image: {image_name}'

new_content = re.sub(pattern, replacement, content)

with open(compose_file, 'w') as f:
    f.write(new_content)

print(f"✅ Updated {compose_file}")
print(f"   Replaced 'build: ./' with 'image: {image_name}'")
print(f"   Backup saved to: {compose_file}.backup")
PYTHON_SCRIPT

echo ""
echo "✅ Done! Now containers will use pre-built image"
echo ""
echo "To use:"
echo "   docker compose -f compose-50-bots.yaml up -d bot-1"

