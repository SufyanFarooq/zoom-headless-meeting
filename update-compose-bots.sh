#!/bin/bash

# Script to update all bots in compose file
# This will update bots 3-10 to use the new entrypoint format

BOTS=(3 4 5 6 7 8 9 10)
NAMES=("Charlie" "Diana" "Eve" "Frank" "Grace" "Henry" "Iris" "Jack")

for i in "${!BOTS[@]}"; do
    BOT_NUM=${BOTS[$i]}
    BOT_NAME="Bot-${BOT_NUM}-${NAMES[$i]}"
    
    echo "Updating bot-$BOT_NUM with name $BOT_NAME"
    
    # This would need sed or similar to update the file
    # For now, manual update is needed
done

echo "Please manually update bots 3-10 in compose-multiple-bots.yaml"
echo "Use bot-1 and bot-2 as templates"

