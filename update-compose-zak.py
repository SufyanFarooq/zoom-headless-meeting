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
COMPOSE_FILE = os.path.join(WORK_DIR, "compose-50-bots.yaml")
TOKENS_FILE = os.path.join(WORK_DIR, "bot-zak-tokens.env")

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
    """Update compose file with ZAK tokens"""
    if not os.path.exists(COMPOSE_FILE):
        print(f"❌ Compose file not found: {COMPOSE_FILE}")
        return False
    
    # Read compose file
    with open(COMPOSE_FILE, 'r') as f:
        content = f.read()
    
    # Process each bot
    lines = content.split('\n')
    new_lines = []
    i = 0
    current_bot = None
    
    while i < len(lines):
        line = lines[i]
        
        # Detect bot section start
        bot_match = re.match(r'^\s*bot-(\d+):', line)
        if bot_match:
            current_bot = int(bot_match.group(1))
            new_lines.append(line)
            i += 1
            continue
        
        # In bot section, FIRST remove ALL existing --zak entries, THEN insert at correct position
        # ZAK token should be placed BEFORE RawVideo/RawAudio subcommands
        # IMPORTANT: --zak is a global option, must come BEFORE subcommands
        # Correct order: --config config.toml -> --zak -> RawVideo -> RawAudio
        if current_bot and tokens.get(current_bot):
            # Skip ALL existing --zak entries and their tokens (remove them)
            if '--zak' in line:
                # Skip --zak line
                i += 1
                # Skip token line (long JWT token > 100 chars)
                if i < len(lines) and re.match(r'^\s+- "', lines[i]) and len(lines[i]) > 100:
                    i += 1
                continue
            # Skip orphaned JWT tokens (long tokens without --zak flag before them)
            elif re.match(r'^\s+- "', line) and len(line) > 100 and i > 0 and '--zak' not in lines[i-1]:
                # Check if this is a JWT token (starts with eyJ)
                if 'eyJ' in line:
                    i += 1
                    continue
            
            # Strategy: Find config.toml and insert --zak right after it (BEFORE subcommands)
            if re.search(r'config\.toml', line):
                # Found config.toml, insert --zak after it (BEFORE RawVideo/RawAudio)
                new_lines.append(line)
                i += 1
                
                # Skip any existing --zak entries
                while i < len(lines):
                    if '--zak' in lines[i]:
                        i += 1
                        if i < len(lines) and re.match(r'^\s+- "', lines[i]) and len(lines[i]) > 100:
                            i += 1
                        continue
                    # Stop if we hit RawVideo or RawAudio (subcommands)
                    elif re.search(r'RawVideo|RawAudio', lines[i]):
                        break
                    # Stop if we hit deploy or other sections
                    elif re.match(r'^\s+(deploy|volumes|environment|entrypoint):', lines[i]):
                        break
                    i += 1
                
                # Detect indentation from config.toml line
                config_indent = re.match(r'^(\s+)-\s+config\.toml', line)
                if config_indent:
                    base_indent = config_indent.group(1)  # exact spaces before "- config.toml"
                else:
                    base_indent = "    "  # fallback to 4 spaces (correct format)

                item_indent = base_indent  # same indent as other list items

                # write zak
                new_lines.append(f'{item_indent}- "--zak"')
                new_lines.append(f'{item_indent}- "{tokens[current_bot]}"')
                # end write zak
                # end of zak insertion
                continue
            
            # Also ensure --dir /dev exists for RawAudio
            if re.search(r'--dir', line):
                # Found --dir, check if /dev exists
                new_lines.append(line)
                i += 1
                
                if i < len(lines) and re.search(r'"/dev"', lines[i]):
                    # /dev exists
                    new_lines.append(lines[i])
                    i += 1
                else:
                    # /dev missing, add it
                    new_lines.append('      - "/dev"')
                continue
        
        new_lines.append(line)
        i += 1
    
    # Write updated content
    with open(COMPOSE_FILE, 'w') as f:
        f.write('\n'.join(new_lines))
    
    return True

def main():
    print("🔄 Updating compose file with ZAK tokens...")
    print(f"   Compose file: {COMPOSE_FILE}")
    print(f"   Tokens file: {TOKENS_FILE}")
    print("")
    
    tokens = load_tokens()
    if not tokens:
        print("❌ No tokens found")
        return 1
    
    print(f"✅ Found {len(tokens)} ZAK tokens")
    print("")
    
    if update_compose_file(tokens):
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("✅ Compose file updated successfully!")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("")
        print("💡 Test bots:")
        print("   docker compose -f compose-50-bots.yaml up --build bot-1")
        return 0
    else:
        return 1

if __name__ == "__main__":
    sys.exit(main())

