#!/usr/bin/env python3
"""
Script to update compose-50-bots.yaml with ZAK tokens from bot-zak-tokens.env
This properly handles YAML structure and adds ZAK tokens to each bot
"""

import re
import sys
import os
from datetime import datetime

# Get script directory to ensure we use absolute paths
# Try to get script location, fallback to current working directory
try:
    SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
except NameError:
    SCRIPT_DIR = os.getcwd()

# Use current working directory (where script is executed from)
# This ensures files are found when run from container
WORK_DIR = os.getcwd()

# Get compose file name from command line argument or use default
if len(sys.argv) > 1:
    arg = sys.argv[1]
    if os.path.isabs(arg) and os.path.exists(arg):
        COMPOSE_FILE = arg
        WORK_DIR = os.path.dirname(arg)
    elif os.path.exists(arg):
        COMPOSE_FILE = os.path.abspath(arg)
        WORK_DIR = os.path.dirname(COMPOSE_FILE)
    else:
        COMPOSE_FILE = os.path.join(WORK_DIR, arg)
else:
    COMPOSE_FILE = os.path.join(WORK_DIR, "compose-50-bots.yaml")

TOKENS_FILE = os.path.join(WORK_DIR, "bot-zak-tokens.env")
NAME_OFFSET = int(os.environ.get("NAME_OFFSET", "0") or "0")

def load_tokens():
    """Load ZAK tokens from env file"""
    tokens = {}
    if not os.path.exists(TOKENS_FILE):
        print(f"❌ Tokens file not found: {TOKENS_FILE}")
        return tokens
    
    with open(TOKENS_FILE, 'r') as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                key, value = line.split('=', 1)
                if 'ZAK_TOKEN' in key:
                    bot_num = re.search(r'BOT(\d+)', key)
                    if bot_num:
                        tokens[int(bot_num.group(1))] = value
    
    return tokens

def update_compose_file(tokens):
    """Update compose file with ZAK tokens (optimized batch processing)"""
    if not os.path.exists(COMPOSE_FILE):
        print(f"❌ Compose file not found: {COMPOSE_FILE}")
        return False
    
    # Read compose file (single read for efficiency)
    with open(COMPOSE_FILE, 'r') as f:
        content = f.read()
    
    # Process all bots in a single pass (more efficient than multiple passes)
    lines = content.split('\n')
    new_lines = []
    i = 0
    current_bot = None
    updated_count = 0
    
    while i < len(lines):
        line = lines[i]
        
        # Detect bot section start
        # Support formats:
        # - bot-{number}: (old format)
        # - bot-{meetingId}-{number}: (previous format)
        # - bot-{meetingId}-{requestId}-{number}: (new format with REQUEST_ID)
        # Pattern: bot- followed by any characters, ending with -{number}:
        bot_match = re.match(r'^\s*bot-.*-(\d+):', line)
        if bot_match:
            # Extract bot number (last number in the bot name)
            current_bot = int(bot_match.group(1))  # The (\d+) at the end captures the bot number
            new_lines.append(line)
            i += 1
            continue
        
        # In bot section, FIRST remove ALL existing --zak entries, THEN insert at correct position
        # ZAK token should be placed BEFORE RawVideo/RawAudio subcommands
        # IMPORTANT: --zak is a global option, must come BEFORE subcommands
        # Correct order: --config config.toml -> --zak -> RawVideo -> RawAudio
        if current_bot is not None:
            zak_bot_num = NAME_OFFSET + current_bot
            if tokens.get(zak_bot_num):
                if '--zak' in line:
                    i += 1
                    if i < len(lines) and re.match(r'^\s+- "', lines[i]) and len(lines[i]) > 100:
                        i += 1
                    continue
                elif re.match(r'^\s+- "', line) and len(line) > 100 and i > 0 and '--zak' not in lines[i-1]:
                    if 'eyJ' in line:
                        i += 1
                        continue
                if re.search(r'config\.toml', line):
                    new_lines.append(line)
                    i += 1
                    while i < len(lines):
                        if '--zak' in lines[i]:
                            i += 1
                            if i < len(lines) and re.match(r'^\s+- "', lines[i]) and len(lines[i]) > 100:
                                i += 1
                            continue
                        elif re.search(r'RawVideo|RawAudio', lines[i]):
                            break
                        elif re.match(r'^\s+(deploy|volumes|environment|entrypoint):', lines[i]):
                            break
                        i += 1
                    config_indent = re.match(r'^(\s+)-\s+config\.toml', line)
                    base_indent = config_indent.group(1) if config_indent else "    "
                    item_indent = base_indent
                    new_lines.append(f'{item_indent}- "--zak"')
                    new_lines.append(f'{item_indent}- "{tokens[zak_bot_num]}"')
                    updated_count += 1
                    continue
            
        if current_bot is not None and tokens.get(NAME_OFFSET + current_bot):
            # Also ensure --dir /dev exists for RawAudio
            # Skip if line already contains /dev (combined format like "RawAudio --file x.pcm --dir /dev")
            if re.search(r'--dir', line) and not re.search(r'/dev', line):
                new_lines.append(line)
                i += 1
                if i < len(lines) and re.search(r'["\']?/dev["\']?', lines[i]):
                    new_lines.append(lines[i])
                    i += 1
                else:
                    new_lines.append('      - "/dev"')
                continue
        
        new_lines.append(line)
        i += 1
    
    # Write updated content (single write for efficiency)
    with open(COMPOSE_FILE, 'w') as f:
        f.write('\n'.join(new_lines))
    
    print(f"   Updated {updated_count} bots with ZAK tokens")
    return True

def main():
    print("🔄 Updating compose file with ZAK tokens...")
    print(f"   Compose file: {COMPOSE_FILE}")
    print(f"   Tokens file: {TOKENS_FILE}")
    if NAME_OFFSET > 0:
        print(f"   Name offset: {NAME_OFFSET} (2nd+ batch → BOT{NAME_OFFSET+1}, BOT{NAME_OFFSET+2}...)")
    print("")
    
    import time
    start_time = time.time()
    
    tokens = load_tokens()
    if not tokens:
        print("❌ No tokens found")
        return 1
    
    print(f"✅ Found {len(tokens)} ZAK tokens")
    print("")
    
    if update_compose_file(tokens):
        elapsed = time.time() - start_time
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print(f"✅ Compose file updated successfully! ({elapsed:.2f}s)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("")
        print("💡 Test bots:")
        compose_filename = os.path.basename(COMPOSE_FILE)
        print(f"   docker compose -f {compose_filename} up --build bot-1")
        return 0
    else:
        return 1

if __name__ == "__main__":
    sys.exit(main())

