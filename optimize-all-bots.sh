#!/bin/bash

# Script to optimize all bots in compose file
# This will add optimizations to bots 2-10

echo "Optimizing compose-multiple-bots.yaml..."

# Backup original
cp compose-multiple-bots.yaml compose-multiple-bots.yaml.backup

# For each bot 2-10, we need to:
# 1. Add build-cache volume
# 2. Add logging disable environment variables
# 3. Change entrypoint to optimized script
# 4. Add resource limits

echo "✅ Backup created: compose-multiple-bots.yaml.backup"
echo "⚠️  Please manually update bots 2-10 using bot-1 as template"
echo ""
echo "Changes needed for each bot:"
echo "1. Add: - build-cache:/tmp/meeting-sdk-linux-sample/build (in volumes)"
echo "2. Add logging environment variables"
echo "3. Change entrypoint to: ./bin/entry-bot-optimized.sh"
echo "4. Add deploy.resources section"

