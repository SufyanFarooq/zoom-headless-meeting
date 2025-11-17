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
        
        # In bot section, look for --config config.toml
        if current_bot and tokens.get(current_bot):
            # Check if this is the config.toml line
            if re.search(r'config\.toml', line):
                new_lines.append(line)
                i += 1
                
                # Check if ZAK already exists in next few lines
                zak_found = False
                j = i
                # Look ahead up to 10 lines for --zak or long JWT tokens
                while j < min(i + 10, len(lines)) and not zak_found:
                    # Check for --zak flag
                    if '--zak' in lines[j]:
                        zak_found = True
                        # Skip --zak line
                        j += 1
                        # Skip token line (long JWT token > 100 chars)
                        if j < len(lines) and re.match(r'^\s+- "', lines[j]) and len(lines[j]) > 100:
                            j += 1
                        # Now insert correct ZAK token
                        new_lines.append('      - "--zak"')
                        new_lines.append(f'      - "{tokens[current_bot]}"')
                        i = j
                        continue
                    # Check for orphaned JWT tokens (long tokens without --zak flag)
                    elif re.match(r'^\s+- "', lines[j]) and len(lines[j]) > 100:
                        # This is likely an orphaned token, skip it
                        j += 1
                        # Check if there's another token after it (duplicate)
                        if j < len(lines) and re.match(r'^\s+- "', lines[j]) and len(lines[j]) > 100:
                            j += 1  # Skip duplicate too
                        # Insert correct ZAK token
                        new_lines.append('      - "--zak"')
                        new_lines.append(f'      - "{tokens[current_bot]}"')
                        i = j
                        continue
                    # If we hit deploy or another section, stop looking
                    elif re.match(r'^\s+(deploy|volumes|environment|entrypoint):', lines[j]):
                        break
                    j += 1
                
                if not zak_found:
                    # Add ZAK token after config.toml
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

