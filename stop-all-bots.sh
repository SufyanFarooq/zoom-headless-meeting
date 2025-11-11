#!/bin/bash

# Script to stop all running Zoom bots

echo "🛑 Stopping all Zoom bots..."

# Stop all containers with zoom-bot prefix
docker ps -a | grep zoom-bot | awk '{print $1}' | xargs -r docker stop

echo "✅ All bots stopped!"

