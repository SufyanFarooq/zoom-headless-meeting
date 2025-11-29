#!/bin/bash

# Automated script to:
# 1. Read emails from users.txt
# 2. Generate ZAK tokens for each (sequential or parallel)
# 3. Update compose file automatically

set -e

if [ $# -lt 3 ]; then
    echo "Usage: $0 <account_id> <client_id> <client_secret> [users_file] [parallel_jobs]"
    echo ""
    echo "Example:"
    echo "  $0 kOjrXedBRwGlbGiCyzQOyQ 9bk9CyXgSgqggGe5InpVMA OiftYuJ6cM6QtDbex64P4T6MM5q1JEBS"
    echo ""
    echo "Optional:"
    echo "  users_file (default: profile-pics/users.txt)"
    echo "  parallel_jobs (default: 0 = sequential, use 10-20 for parallel)"
    echo ""
    echo "For large batches (50+ bots), use parallel generation:"
    echo "  $0 ... profile-pics/users.txt 20"
    exit 1
fi

ACCOUNT_ID="$1"
CLIENT_ID="$2"
CLIENT_SECRET="$3"
USERS_FILE="${4:-profile-pics/users.txt}"
PARALLEL_JOBS="${5:-0}"

if [ ! -f "$USERS_FILE" ]; then
    echo "❌ Error: Users file not found: $USERS_FILE"
    exit 1
fi

# Count emails to determine if parallel is beneficial
EMAIL_COUNT=$(grep -c "@" "$USERS_FILE" 2>/dev/null || echo "0")

# Auto-enable parallel for large batches
if [ "$PARALLEL_JOBS" -eq 0 ] && [ "$EMAIL_COUNT" -ge 50 ]; then
    PARALLEL_JOBS=10
    echo "💡 Auto-enabling parallel generation (10 jobs) for $EMAIL_COUNT emails"
fi

echo "🚀 Automated Bot Setup with ZAK Tokens"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$PARALLEL_JOBS" -gt 0 ]; then
    echo "   Mode: Parallel ($PARALLEL_JOBS jobs)"
else
    echo "   Mode: Sequential"
fi
echo ""

# Get access token
echo "Step 1: Getting access token..."
ACCESS_TOKEN=$(./get-access-token.sh "$ACCOUNT_ID" "$CLIENT_ID" "$CLIENT_SECRET" 2>/dev/null | grep -A1 "Access Token:" | tail -1 | tr -d ' ')
if [ -z "$ACCESS_TOKEN" ]; then
    echo "❌ Failed to get access token"
    exit 1
fi
echo "✅ Access token obtained"
echo ""

# Generate ZAK tokens (parallel or sequential)
if [ "$PARALLEL_JOBS" -gt 0 ]; then
    echo "Step 2: Generating ZAK tokens in parallel ($PARALLEL_JOBS jobs)..."
    echo ""
    
    # Use parallel script
    if [ -f "./generate-zak-tokens-parallel.sh" ]; then
        chmod +x ./generate-zak-tokens-parallel.sh
        if ! ./generate-zak-tokens-parallel.sh "$ACCOUNT_ID" "$CLIENT_ID" "$CLIENT_SECRET" "$USERS_FILE" "$PARALLEL_JOBS"; then
            echo "❌ Parallel token generation failed"
            exit 1
        fi
        # Parallel script generates bot-zak-tokens.env, now continue to compose file update
        TOKENS_FILE="bot-zak-tokens.env"
        if [ ! -f "$TOKENS_FILE" ]; then
            echo "❌ Error: Tokens file not generated: $TOKENS_FILE"
            exit 1
        fi
        echo ""
        echo "✅ Parallel token generation complete, continuing to compose file update..."
        echo ""
    else
        echo "⚠️  Parallel script not found, falling back to sequential"
        PARALLEL_JOBS=0
    fi
fi

# Sequential generation (if not using parallel or parallel script not found)
if [ "$PARALLEL_JOBS" -eq 0 ]; then
    echo "Step 2: Generating ZAK tokens (sequential)..."
    echo ""

TOKENS_FILE="bot-zak-tokens.env"
echo "# ZAK Tokens for bots (auto-generated on $(date))" > "$TOKENS_FILE"
echo "" >> "$TOKENS_FILE"

BOT_NUM=1
# Use regular arrays (bash 3.2 compatible)
# Track successful bots separately to prevent misalignment
BOT_TOKENS=()
BOT_EMAILS=()
BOT_NUMS=()  # Track which bot numbers succeeded

while IFS= read -r LINE || [ -n "$LINE" ]; do
    # Skip empty lines and comments
    [[ -z "$LINE" || "$LINE" =~ ^# ]] && continue
    
    # users.txt should only contain emails (one per line)
    # If line contains @, it's an email
    if [[ "$LINE" =~ @ ]]; then
        EMAIL=$(echo "$LINE" | awk '{print $1}')  # Get email (first word, in case there's extra text)
        
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "[$BOT_NUM/$EMAIL_COUNT] Bot $BOT_NUM: $EMAIL (with profile)"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        # Generate ZAK token
        echo "   ⏳ Generating ZAK token..."
        ZAK_OUTPUT=$(./get-zak-token.sh "$EMAIL" "$ACCESS_TOKEN" 2>&1)
        ZAK_TOKEN=$(echo "$ZAK_OUTPUT" | grep -A1 "ZAK Token:" | tail -1 | tr -d ' ')
        
        if [ -z "$ZAK_TOKEN" ] || [ ${#ZAK_TOKEN} -lt 50 ]; then
            echo "❌ Failed to generate ZAK token for $EMAIL"
            echo "$ZAK_OUTPUT" | tail -3
            echo "⚠️  Skipping bot-$BOT_NUM (will not be added to compose file)"
            echo ""
            BOT_NUM=$((BOT_NUM + 1))
            continue
        fi
        
        # Only add to arrays if token generation succeeded
        BOT_TOKENS+=("$ZAK_TOKEN")
        BOT_EMAILS+=("$EMAIL")
        BOT_NUMS+=("$BOT_NUM")
        
        echo "✅ ZAK token generated"
        echo ""
        
        # Save to tokens file
        echo "BOT${BOT_NUM}_ZAK_TOKEN=$ZAK_TOKEN" >> "$TOKENS_FILE"
        echo "BOT${BOT_NUM}_EMAIL=$EMAIL" >> "$TOKENS_FILE"
        echo "" >> "$TOKENS_FILE"
    else
        # Empty line or non-email line = guest bot (no ZAK token)
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Bot $BOT_NUM: (guest, no email)"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "ℹ️  Guest bot - no ZAK token needed"
        echo ""
    fi
    
    BOT_NUM=$((BOT_NUM + 1))
done < "$USERS_FILE"

TOTAL_BOTS=$((BOT_NUM - 1))
SUCCESSFUL_BOTS=${#BOT_TOKENS[@]}

if [ $SUCCESSFUL_BOTS -eq 0 ]; then
    echo "❌ No ZAK tokens generated successfully"
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Generated ZAK tokens for $SUCCESSFUL_BOTS bots (out of $TOTAL_BOTS total)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
fi

# Update compose file
echo "Step 3: Updating compose file..."
# Use COMPOSE_FILE from environment if set, otherwise default to compose-50-bots.yaml
COMPOSE_FILE="${COMPOSE_FILE:-compose-50-bots.yaml}"

if [ ! -f "$COMPOSE_FILE" ]; then
    echo "❌ Compose file not found: $COMPOSE_FILE"
    echo "   💡 Set COMPOSE_FILE environment variable to specify compose file name"
    exit 1
fi

echo "   Using compose file: $COMPOSE_FILE"

# Update each bot in compose file
# Iterate over bots that successfully got tokens
i=0
while [ $i -lt $SUCCESSFUL_BOTS ]; do
    BOT_NUM="${BOT_NUMS[$i]}"
    ZAK_TOKEN="${BOT_TOKENS[$i]}"
    EMAIL="${BOT_EMAILS[$i]}"
    
    if [ -z "$ZAK_TOKEN" ]; then
        echo "⚠️  Skipping bot-${BOT_NUM} (no ZAK token)"
        i=$((i + 1))
        continue
    fi
    
    # Always use Python script for reliable YAML manipulation
    echo "🔄 Updating ZAK token for bot-${BOT_NUM}..."
    
    # Check if yaml module is available
    if ! python3 -c "import yaml" 2>/dev/null; then
        echo "⚠️  Python yaml module not found. Installing PyYAML..."
        pip3 install PyYAML >/dev/null 2>&1 || {
            echo "❌ Failed to install PyYAML. Please install manually:"
            echo "   pip3 install PyYAML"
            echo "   OR: python3 -m pip install PyYAML"
            echo ""
            echo "   Falling back to update-compose-zak.py script..."
            python3 update-compose-zak.py "$COMPOSE_FILE" 2>/dev/null || {
                echo "⚠️  Could not auto-update bot-${BOT_NUM} in compose file"
                echo "   Manual update needed:"
                echo "   Bot-${BOT_NUM}: Update --zak token to \"${ZAK_TOKEN}\""
            }
            i=$((i + 1))
            continue
        }
    fi
    
    # Use Python script to remove all duplicates and update
    # Pass COMPOSE_FILE to Python script via environment
    COMPOSE_FILE="$COMPOSE_FILE" BOT_NUM=$BOT_NUM ZAK_TOKEN="$ZAK_TOKEN" python3 << PYTHON_UPDATE_SCRIPT
import yaml
import sys
import os
import re

COMPOSE_FILE = os.environ.get('COMPOSE_FILE', 'compose-50-bots.yaml')
BOT_NUM = int(os.environ.get('BOT_NUM', '0'))
ZAK_TOKEN = os.environ.get('ZAK_TOKEN', '')

if not ZAK_TOKEN or BOT_NUM == 0:
    sys.exit(1)

try:
    with open(COMPOSE_FILE, 'r') as f:
        compose_data = yaml.safe_load(f)
    
    if not compose_data or 'services' not in compose_data:
        sys.exit(1)
    
    # Try multiple formats: bot-{NUM}, bot-{MEETING_ID}-{NUM}, bot-{MEETING_ID}-{REQUEST_ID}-{NUM}
    service_name = f"bot-{BOT_NUM}"
    # Check if service exists with meeting ID + request ID format
    found_service = None
    for svc_name in compose_data['services'].keys():
        # Match: bot-{NUM}, bot-{MEETING_ID}-{NUM}, or bot-{MEETING_ID}-{REQUEST_ID}-{NUM}
        if svc_name == service_name or svc_name.endswith(f"-{BOT_NUM}"):
            found_service = svc_name
            break
    
    if not found_service:
        sys.exit(1)
    
    service_name = found_service
    
    command_list = compose_data['services'][service_name].get('command', [])
    
    # Remove ALL existing --zak entries and their tokens (including orphaned tokens)
    # Also preserve config.toml - never remove it!
    new_command = []
    i = 0
    while i < len(command_list):
        if command_list[i] == "--zak":
            # Skip --zak and the token after it
            i += 2
            continue
        # Check for orphaned JWT tokens (long tokens starting with eyJ without --zak flag)
        # BUT: Skip only if it's NOT config.toml (config.toml must be preserved)
        elif isinstance(command_list[i], str) and len(command_list[i]) > 100 and command_list[i].startswith("eyJ"):
            # This is likely an orphaned ZAK token, skip it
            # BUT check: if previous item was --config, this might be a corrupted entry
            if i > 0 and command_list[i-1] == "--config":
                # This is a corrupted entry where ZAK token replaced config.toml
                # Restore config.toml
                new_command.append("config.toml")
                i += 1
                continue
            # Otherwise, skip the orphaned token
            i += 1
            continue
        new_command.append(command_list[i])
        i += 1
    
    # Find position to insert --zak (BEFORE RawVideo/RawAudio subcommands)
    # IMPORTANT: --zak is a global option, must come BEFORE subcommands
    # Correct order: --config config.toml -> --zak -> RawVideo -> RawAudio
    insert_idx = -1
    
    # Strategy: Find config.toml and insert --zak right after it (BEFORE any subcommands)
    # IMPORTANT: config.toml MUST exist - if not found, something is wrong
    config_toml_idx = -1
    for idx, item in enumerate(new_command):
        if item == "config.toml":
            config_toml_idx = idx
            insert_idx = idx + 1
            break
    
    # If config.toml not found, try to find --config and add config.toml after it
    if config_toml_idx == -1:
        for idx, item in enumerate(new_command):
            if item == "--config":
                # Insert config.toml after --config
                new_command.insert(idx + 1, "config.toml")
                insert_idx = idx + 2
                break
    
    # Also ensure --dir /dev exists for RawAudio (if RawAudio is present)
    # But do this AFTER inserting --zak to avoid duplicates
    # We'll handle this separately after --zak insertion
    
    if insert_idx != -1:
        # Insert --zak flag first, then token
        new_command.insert(insert_idx, "--zak")
        new_command.insert(insert_idx + 1, ZAK_TOKEN)
        
        # Now ensure --dir /dev exists for RawAudio (if present)
        if "RawAudio" in new_command:
            raw_audio_idx = -1
            for idx, item in enumerate(new_command):
                if item == "RawAudio":
                    raw_audio_idx = idx
                    break
            
            if raw_audio_idx >= 0:
                # Remove ALL duplicate --dir entries first
                # Find all --dir entries after RawAudio
                dir_indices = []
                for idx in range(raw_audio_idx, len(new_command)):
                    if new_command[idx] == "--dir":
                        dir_indices.append(idx)
                
                # Remove all duplicate --dir entries (keep only the first one)
                # Remove from end to start to preserve indices
                for dir_idx in reversed(dir_indices[1:]):
                    # Remove --dir and its value
                    if dir_idx + 1 < len(new_command):
                        new_command.pop(dir_idx + 1)  # Remove value
                    new_command.pop(dir_idx)  # Remove --dir
                
                # Now check if --dir exists (after removing duplicates)
                dir_found = False
                dir_idx = -1
                for idx in range(raw_audio_idx, len(new_command)):
                    if new_command[idx] == "--dir":
                        dir_found = True
                        dir_idx = idx
                        break
                
                if dir_found and dir_idx >= 0:
                    # --dir found, check if /dev exists
                    if dir_idx + 1 >= len(new_command) or new_command[dir_idx + 1] != "/dev":
                        # /dev missing, add it
                        new_command.insert(dir_idx + 1, "/dev")
                elif not dir_found:
                    # --dir not found, find dev-null.pcm and add --dir /dev after it
                    for idx in range(raw_audio_idx, len(new_command)):
                        if new_command[idx] == "dev-null.pcm":
                            new_command.insert(idx + 1, "--dir")
                            new_command.insert(idx + 2, "/dev")
                            break
        
        # Instead of using yaml.dump() which creates nested structures,
        # use line-by-line replacement like update-compose-zak.py does
        with open(COMPOSE_FILE, 'r') as f:
            lines = f.readlines()
        
        new_lines = []
        i = 0
        in_bot_section = False
        in_command_section = False
        
        while i < len(lines):
            line = lines[i]
            
            # Detect bot service start - handle bot-{NUM}, bot-{MEETING_ID}-{NUM}, or bot-{MEETING_ID}-{REQUEST_ID}-{NUM} formats
            # Match: bot-{NUM}:, bot-{MEETING_ID}-{NUM}:, or bot-{MEETING_ID}-{REQUEST_ID}-{NUM}:
            # Pattern: bot- followed by optional digits-dashes, ending with -{BOT_NUM}:
            if re.match(r'^\s*bot-(\d+-)*' + str(BOT_NUM) + r':', line) or re.match(r'^\s*bot-\d+-\d+-' + str(BOT_NUM) + r':', line):
                in_bot_section = True
                new_lines.append(line)
                i += 1
                continue
            
            # Detect end of bot service - handle both formats
            if in_bot_section and re.match(r'^\s+(bot-|\w+):', line):
                # Check if this is still the same bot (handle both formats)
                if not (re.match(r'^\s*bot-(\d+-)*' + str(BOT_NUM) + r':', line) or re.match(r'^\s*bot-\d+-\d+-' + str(BOT_NUM) + r':', line)):
                    in_bot_section = False
                    in_command_section = False
                in_bot_section = False
                in_command_section = False
            
            # Detect command section
            if in_bot_section and re.match(r'^\s+command:', line):
                in_command_section = True
                new_lines.append(line)
                i += 1

                # Detect indentation of next line
                if i < len(lines) and re.match(r'^(\s+)- ', lines[i]):
                    indent_str = re.match(r'^(\s+)- ', lines[i]).group(1)
                else:
                    indent_str = '      '  # fallback: 6 spaces

                # Write new command list
                for cmd_item in new_command:
                    cmd_str = str(cmd_item)
                    if '"' in cmd_str or (' ' in cmd_str and not cmd_str.startswith('--')):
                        escaped = cmd_str.replace('"', '\\"')
                        new_lines.append(indent_str + '- "' + escaped + '"\n')
                    else:
                        new_lines.append(indent_str + '- ' + cmd_str + '\n')

                # Skip old commands
                while i < len(lines):
                    if re.match(r'^\s+(deploy|volumes|environment|entrypoint|restart|stop_grace_period):', lines[i]):
                        break
                    i += 1
                continue
            
            if not in_command_section:
                new_lines.append(line)
            
            i += 1
        
        # Write the updated file
        with open(COMPOSE_FILE, 'w') as f:
            f.writelines(new_lines)
        
        print("   ✅ Updated ZAK token (removed duplicates)")
    else:
        sys.exit(1)
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
PYTHON_UPDATE_SCRIPT
    
    if [ $? -ne 0 ]; then
        # Fallback: Use update-compose-zak.py script
        echo "   Using update-compose-zak.py script..."
        python3 update-compose-zak.py "$COMPOSE_FILE" 2>/dev/null || {
            echo "⚠️  Could not auto-update bot-${BOT_NUM} in compose file"
            echo "   Manual update needed:"
            echo "   Bot-${BOT_NUM}: Update --zak token to \"${ZAK_TOKEN}\""
        }
    fi
    
    i=$((i + 1))
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Setup Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📝 Summary:"
echo "   - ZAK tokens generated: $SUCCESSFUL_BOTS (out of $TOTAL_BOTS bots)"
echo "   - Tokens saved to: $TOKENS_FILE"
echo "   - Compose file: $COMPOSE_FILE (updated)"
echo ""
echo "💡 Next: Review compose file and test:"
echo "   docker compose -f $COMPOSE_FILE up --build bot-1"

