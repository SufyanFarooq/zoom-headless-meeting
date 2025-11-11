# SQLCipher and Connection Error Fixes

## 🔍 Issues Identified

When running 50 bots, only 38 bots showed up in the meeting with the following errors:

1. **SQLCipher Errors**:
   - `sqlcipher_page_cipher: hmac check failed for pgno=1`
   - `sqlite3Codec: error decrypting page 1 data: 1`
   - `sqlcipher_codec_ctx_set_error 1`

2. **Authentication Errors**:
   - `authentication failed because the Zoom SDK encountered an unknown error: 5`

3. **Meeting Connection Failures**:
   - `failed to connect to the meeting with MeetingFailCode 1`
   - `failed to connect to the meeting with MeetingFailCode 5`

## 🎯 Root Causes

1. **Database Conflicts**: Multiple bots were trying to access the same Zoom SDK database files, causing SQLCipher encryption/decryption failures
2. **Rate Limiting**: Too many simultaneous authentication requests to Zoom's API
3. **Database Corruption**: Corrupted database files from previous runs

## ✅ Solutions Implemented

### 1. Isolated Data Directories
- Each bot now has its own isolated data directory
- Set `HOME`, `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, and `XDG_CACHE_HOME` per bot
- Prevents database file conflicts between bots

**Location**: `bin/entry-bot-optimized.sh`
```bash
BOT_ID="${CONTAINER_NAME:-zoom-bot-$(hostname)}"
BOT_DATA_DIR="/tmp/meeting-sdk-linux-sample/bot-data/${BOT_ID}"
export HOME="${BOT_DATA_DIR}"
export XDG_CONFIG_HOME="${BOT_DATA_DIR}/.config"
```

### 2. Database Cleanup on Startup
- Clean Zoom SDK database files before each bot starts
- Removes any corrupted database files from previous runs
- Prevents SQLCipher errors from corrupted data

**Location**: `bin/entry-bot-optimized.sh`
```bash
clean_zoom_database() {
  rm -rf "${BOT_DATA_DIR}/.config/zoomus" 2>/dev/null
  rm -rf "${BOT_DATA_DIR}/.local/share/zoomus" 2>/dev/null
  rm -rf "${BOT_DATA_DIR}/.cache/zoomus" 2>/dev/null
}
```

### 3. Startup Staggering
- Each bot starts 2 seconds after the previous one
- Prevents rate limiting from Zoom's API
- Reduces authentication errors

**Location**: `generate-bots.sh`
```bash
STARTUP_DELAY=$(( (i - 1) * 2 ))
```

### 4. Container Name Environment Variable
- Pass `CONTAINER_NAME` to each bot for unique identification
- Used to create unique data directories

**Location**: `generate-bots.sh`
```yaml
environment:
  - CONTAINER_NAME=zoom-bot-${BOT_NUM}
```

## 🚀 How to Apply Fixes

1. **Regenerate the compose file**:
   ```bash
   ./generate-bots.sh 50
   ```

2. **Stop existing bots**:
   ```bash
   docker compose -f compose-50-bots.yaml down
   ```

3. **Start bots with fixes**:
   ```bash
   docker compose -f compose-50-bots.yaml up -d
   ```

4. **Monitor logs**:
   ```bash
   docker compose -f compose-50-bots.yaml logs -f
   ```

## 📊 Expected Improvements

- ✅ **No more SQLCipher errors**: Each bot has isolated database files
- ✅ **Reduced authentication errors**: Staggered startup prevents rate limiting
- ✅ **Better connection success rate**: Clean database files prevent corruption issues
- ✅ **More bots connecting**: Should see closer to 50 bots in the meeting

## 🔍 Monitoring

Check for improvements:
```bash
# Count successful connections
docker compose -f compose-50-bots.yaml logs | grep "✅ connected" | wc -l

# Check for SQLCipher errors (should be zero)
docker compose -f compose-50-bots.yaml logs | grep -i "sqlcipher" | wc -l

# Check for authentication errors (should be reduced)
docker compose -f compose-50-bots.yaml logs | grep "authentication failed" | wc -l
```

## 📝 Notes

- Each bot's data is stored in: `/tmp/meeting-sdk-linux-sample/bot-data/zoom-bot-{N}/`
- Database files are cleaned on every startup
- Startup delays: Bot 1 starts immediately, Bot 2 after 2s, Bot 3 after 4s, etc.
- Total startup time for 50 bots: ~100 seconds (2 seconds per bot)

