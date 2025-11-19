#!/usr/bin/env python3
"""
Script to update compose-50-bots.yaml with ZAK tokens from bot-zak-tokens.env
This properly handles YAML structure and adds ZAK tokens to each bot
"""

import re
import sys
import os
from datetime import datetime

COMPOSE_FILE = "compose-50-bots.yaml"
TOKENS_FILE = "bot-zak-tokens.env"

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
    
    # Create backup
    backup_file = f"{COMPOSE_FILE}.backup.{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    with open(COMPOSE_FILE, 'r') as f:
        content = f.read()
    
    with open(backup_file, 'w') as f:
        f.write(content)
    print(f"✅ Backup created: {backup_file}")
    
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
        # ZAK token should be placed AFTER RawVideo and RawAudio subcommands
        # Correct order: --config config.toml -> RawVideo -> RawAudio -> --zak
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
            
            # Strategy: Find the end of RawAudio section (--dir /dev) OR end of RawVideo (if no RawAudio)
            if re.search(r'"/dev"', line) or (re.search(r'--dir', line) and i + 1 < len(lines) and re.search(r'"/dev"', lines[i + 1])):
                # Found RawAudio end - insert ZAK after this
                new_lines.append(line)
                i += 1
                
                # Skip any remaining --zak entries before inserting
                while i < len(lines):
                    if '--zak' in lines[i]:
                        i += 1
                        if i < len(lines) and re.match(r'^\s+- "', lines[i]) and len(lines[i]) > 100:
                            i += 1
                        continue
                    elif re.match(r'^\s+(deploy|volumes|environment|entrypoint):', lines[i]):
                        break
                    i += 1
                
                # After removing all existing --zak, add the new one AFTER RawAudio
                new_lines.append('      - "--zak"')
                new_lines.append(f'      - "{tokens[current_bot]}"')
                continue
            # Fallback: If no RawAudio, insert after RawVideo video file line
            elif re.search(r'video-\d+\.mp4', line):
                # Check if this is the video file line (not --input)
                # And next significant line is deploy (no RawAudio)
                next_non_empty = i + 1
                while next_non_empty < len(lines) and not lines[next_non_empty].strip():
                    next_non_empty += 1
                
                if next_non_empty < len(lines) and re.match(r'^\s+deploy:', lines[next_non_empty]):
                    # This is video file line, next is deploy - insert ZAK here
                    new_lines.append(line)
                    i += 1
                    
                    # Skip any remaining --zak entries before inserting
                    while i < len(lines):
                        if '--zak' in lines[i]:
                            i += 1
                            if i < len(lines) and re.match(r'^\s+- "', lines[i]) and len(lines[i]) > 100:
                                i += 1
                            continue
                        elif re.match(r'^\s+(deploy|volumes|environment|entrypoint):', lines[i]):
                            break
                        i += 1
                    
                    # Insert ZAK token
                    new_lines.append('      - "--zak"')
                    new_lines.append(f'      - "{tokens[current_bot]}"')
                    continue
        
        new_lines.append(line)
        i += 1
    
    # Write updated content
    with open(COMPOSE_FILE, 'w') as f:
        f.write('\n'.join(new_lines))
    
    return True

def main():
    print("🔄 Updating compose file with ZAK tokens...")
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

