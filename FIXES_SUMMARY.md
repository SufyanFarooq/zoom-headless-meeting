# Fixes for SQLCipher Errors and Connection Issues

## ✅ All Fixes Applied

### 1. **Isolated Data Directories** ✅
- Each bot now has its own isolated data directory
- Prevents SQLCipher database conflicts
- Location: `/tmp/meeting-sdk-linux-sample/bot-data/zoom-bot-{N}/`

### 2. **Database Cleanup on Startup** ✅
- Zoom SDK database files are cleaned before each bot starts
- Prevents corruption from previous runs
- Removes any existing database files

### 3. **Startup Staggering** ✅
- Each bot starts 2 seconds after the previous one
- Prevents rate limiting from Zoom's API
- Bot 1: immediate, Bot 2: 2s delay, Bot 3: 4s delay, etc.

### 4. **Container Name Environment Variable** ✅
- Each bot receives `CONTAINER_NAME` for unique identification
- Used to create unique data directories

## 🚀 How to Test

1. **Regenerate the compose file** (already done):
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

## 📊 Expected Results

- ✅ **No SQLCipher errors**: Each bot has isolated database files
- ✅ **Reduced authentication errors**: Staggered startup prevents rate limiting
- ✅ **Better connection success rate**: Clean database files prevent corruption
- ✅ **More bots connecting**: Should see closer to 50 bots in the meeting

## 🔍 Monitoring Commands

```bash
# Count successful connections
docker compose -f compose-50-bots.yaml logs | grep "✅ connected" | wc -l

# Check for SQLCipher errors (should be zero or minimal)
docker compose -f compose-50-bots.yaml logs | grep -i "sqlcipher" | wc -l

# Check for authentication errors (should be reduced)
docker compose -f compose-50-bots.yaml logs | grep "authentication failed" | wc -l

# Check for connection failures (should be reduced)
docker compose -f compose-50-bots.yaml logs | grep "failed to connect" | wc -l

# Count total bots running
docker ps | grep zoom-bot | wc -l
```

## 📝 Notes

- **Startup time**: Total startup time for 50 bots is ~100 seconds (2 seconds per bot)
- **Data isolation**: Each bot's data is stored in: `/tmp/meeting-sdk-linux-sample/bot-data/zoom-bot-{N}/`
- **Database cleanup**: Database files are cleaned on every startup
- **Staggering**: Prevents rate limiting by spacing out authentication requests

## 🔧 Files Modified

1. **`bin/entry-bot-optimized.sh`**:
   - Added isolated data directory setup
   - Added database cleanup function
   - Set `HOME`, `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_CACHE_HOME` per bot

2. **`generate-bots.sh`**:
   - Added startup delay calculation
   - Added `CONTAINER_NAME` environment variable
   - Added delay command to stagger bot launches

## 📈 Success Metrics

Before fixes:
- Only 38/50 bots connecting
- Multiple SQLCipher errors
- Authentication errors (error 5)
- Connection failures (MeetingFailCode 1 and 5)

After fixes (expected):
- 45-50/50 bots connecting
- Minimal or no SQLCipher errors
- Reduced authentication errors
- Fewer connection failures

