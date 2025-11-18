#!/bin/bash

# Script to fix duplicate --zak entries in compose-50-bots.yaml
# Removes all duplicate --zak entries and keeps only one

COMPOSE_FILE="compose-50-bots.yaml"

if [ ! -f "$COMPOSE_FILE" ]; then
    echo "❌ Compose file not found: $COMPOSE_FILE"
    exit 1
fi

echo "🔧 Fixing duplicate --zak entries in $COMPOSE_FILE..."
echo ""

# Create backup
BACKUP_FILE="${COMPOSE_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$COMPOSE_FILE" "$BACKUP_FILE"
echo "✅ Backup created: $BACKUP_FILE"
echo ""

# Use Python for reliable YAML manipulation
python3 << 'PYTHON_SCRIPT'
import yaml
import sys
import re

COMPOSE_FILE = "compose-50-bots.yaml"

try:
    with open(COMPOSE_FILE, 'r') as f:
        content = f.read()
    
    # Parse YAML
    compose_data = yaml.safe_load(content)
    
    if not compose_data or 'services' not in compose_data:
        print("❌ Invalid compose file format")
        sys.exit(1)
    
    fixed_count = 0
    
    # Process each bot service
    for service_name, service_config in compose_data['services'].items():
        if not service_name.startswith('bot-'):
            continue
        
        if 'command' not in service_config:
            continue
        
        command_list = service_config['command']
        
        # Find all --zak entries and their indices
        zak_indices = []
        for i, item in enumerate(command_list):
            if item == "--zak":
                zak_indices.append(i)
        
        # If more than one --zak found, remove duplicates
        if len(zak_indices) > 1:
            print(f"🔧 Fixing {service_name}: Found {len(zak_indices)} --zak entries")
            
            # Keep only the first --zak entry, remove all others
            # Remove from end to start to preserve indices
            for idx in reversed(zak_indices[1:]):
                # Remove both --zak and the token after it
                if idx + 1 < len(command_list):
                    command_list.pop(idx + 1)  # Remove token
                command_list.pop(idx)  # Remove --zak
            
            fixed_count += 1
            print(f"   ✅ Removed {len(zak_indices) - 1} duplicate(s), kept first one")
    
    if fixed_count == 0:
        print("✅ No duplicate --zak entries found")
    else:
        # Write back to file
        with open(COMPOSE_FILE, 'w') as f:
            yaml.dump(compose_data, f, sort_keys=False, indent=2, default_flow_style=False)
        
        print("")
        print(f"✅ Fixed {fixed_count} bot(s) with duplicate --zak entries")
        print(f"✅ File updated: {COMPOSE_FILE}")

except Exception as e:
    print(f"❌ Error: {e}")
    sys.exit(1)
PYTHON_SCRIPT

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ Fix Complete!"
    echo ""
    echo "💡 Verify the fix:"
    echo "   grep -n '\"--zak\"' $COMPOSE_FILE"
    echo ""
    echo "💡 Test bot:"
    echo "   docker compose -f $COMPOSE_FILE up bot-1"
else
    echo ""
    echo "❌ Fix failed. Restore from backup:"
    echo "   cp $BACKUP_FILE $COMPOSE_FILE"
    exit 1
fi

