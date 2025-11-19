#!/bin/bash

# Script to fix missing --dir value in compose-50-bots.yaml

COMPOSE_FILE="compose-50-bots.yaml"

if [ ! -f "$COMPOSE_FILE" ]; then
    echo "❌ Compose file not found: $COMPOSE_FILE"
    exit 1
fi

echo "🔧 Fixing missing --dir values in $COMPOSE_FILE..."
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

COMPOSE_FILE = "compose-50-bots.yaml"

try:
    with open(COMPOSE_FILE, 'r') as f:
        compose_data = yaml.safe_load(f)
    
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
        
        # Find --dir flag and check if value is missing
        for i, item in enumerate(command_list):
            if item == "--dir":
                # Check if next item exists and is a valid directory
                if i + 1 >= len(command_list) or command_list[i + 1] in ["--zak", "RawVideo", "RawAudio"] or command_list[i + 1].startswith("--"):
                    # Missing value, add "/dev"
                    command_list.insert(i + 1, "/dev")
                    fixed_count += 1
                    print(f"✅ Fixed {service_name}: Added missing --dir value")
                    break
                elif command_list[i + 1] != "/dev":
                    # Value exists but wrong, fix it
                    command_list[i + 1] = "/dev"
                    fixed_count += 1
                    print(f"✅ Fixed {service_name}: Corrected --dir value to /dev")
                    break
    
    if fixed_count == 0:
        print("✅ No missing --dir values found")
    else:
        # Write back to file
        with open(COMPOSE_FILE, 'w') as f:
            yaml.dump(compose_data, f, sort_keys=False, indent=2, default_flow_style=False)
        
        print("")
        print(f"✅ Fixed {fixed_count} bot(s) with missing --dir values")
        print(f"✅ File updated: {COMPOSE_FILE}")

except Exception as e:
    print(f"❌ Error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
PYTHON_SCRIPT

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ Fix Complete!"
    echo ""
    echo "💡 Verify the fix:"
    echo "   grep -A 2 '\"--dir\"' $COMPOSE_FILE"
    echo ""
    echo "💡 Test bot:"
    echo "   docker compose -f $COMPOSE_FILE up bot-1"
else
    echo ""
    echo "❌ Fix failed. Restore from backup:"
    echo "   cp $BACKUP_FILE $COMPOSE_FILE"
    exit 1
fi

