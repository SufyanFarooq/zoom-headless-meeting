#!/bin/bash

# Script to update bots 3-10 in compose file
# This will fix the display names issue

BOTS=(
  "3:Charlie"
  "4:Diana"
  "5:Eve"
  "6:Frank"
  "7:Grace"
  "8:Henry"
  "9:Iris"
  "10:Jack"
)

for bot_info in "${BOTS[@]}"; do
  BOT_NUM="${bot_info%%:*}"
  BOT_NAME="${bot_info#*:}"
  FULL_NAME="Bot-${BOT_NUM}-${BOT_NAME}"
  
  echo "Updating bot-${BOT_NUM} (${FULL_NAME})..."
done

echo "Please use the updated compose file with all bots fixed"

