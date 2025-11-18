# 🔧 Server Build Issues - Complete Fix Guide

## Issues Fixed

### Issue 1: vcpkg cli11 Build Failure ✅

**Problem:**
- vcpkg failing to build `cli11:x64-linux`
- Build errors: `BUILD_FAILED`
- CMake configuration fails

**Solution Applied:**
1. ✅ Removed `cli11` from `vcpkg.json` (no longer needed)
2. ✅ Added `libcli11-dev` to Dockerfile (system package)
3. ✅ CMakeLists.txt now prefers system CLI11 first
4. ✅ entry-bot-optimized.sh falls back to cmake without vcpkg if preset fails

**How It Works:**
- CMake tries to find CLI11 in system paths first (`/usr/include`, etc.)
- Only falls back to vcpkg if system package not found
- If vcpkg preset fails, retries without vcpkg toolchain

---

### Issue 2: OpenCV Library Not Found ✅

**Problem:**
- `libopencv_videoio.so.406: cannot open shared object file`
- Runtime error: exit code 127
- Bots failing to start

**Solution Applied:**
1. ✅ Enhanced LD_LIBRARY_PATH detection
2. ✅ Multiple detection methods:
   - Find any `libopencv_*.so*` file
   - Check for specific versions (406, 4.5, 4.8, etc.)
   - Use pkg-config as fallback
3. ✅ Shows diagnostic info if libraries not found

---

## Files Changed

1. **vcpkg.json**: Removed `cli11` dependency
2. **Dockerfile**: Added `libcli11-dev` package
3. **CMakeLists.txt**: Prefers system CLI11, fallback to vcpkg
4. **bin/entry-bot-optimized.sh**: 
   - Fallback cmake without vcpkg if preset fails
   - Enhanced OpenCV library detection

---

## Next Steps on Server

### Step 1: Rebuild Docker Image (Required)

```bash
# Rebuild with no cache to get latest changes
docker compose -f compose-50-bots.yaml build --no-cache bot-1
```

### Step 2: Run Bot

```bash
# Run the bot
docker compose -f compose-50-bots.yaml up bot-1
```

### Step 3: Check Logs

If OpenCV still not found, check logs for:
```
Found OpenCV libraries in: /path/to/libs
```

Or if not found:
```
Warning: Could not find OpenCV library directory
Searching for OpenCV libraries...
```

---

## Troubleshooting

### If vcpkg still fails:

The script will automatically retry without vcpkg toolchain. Check logs for:
```
CMake with preset failed, trying without vcpkg toolchain...
```

### If OpenCV still not found:

1. **Check what OpenCV libraries are installed:**
   ```bash
   docker exec zoom-bot-1 find /usr/lib -name "*opencv*" -type f
   ```

2. **Check library version:**
   ```bash
   docker exec zoom-bot-1 ls -la /usr/lib/x86_64-linux-gnu/libopencv*
   ```

3. **Manual fix (if needed):**
   ```bash
   # In entry-bot-optimized.sh, add specific path:
   export LD_LIBRARY_PATH="/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH"
   ```

---

## Expected Behavior

After rebuild:
1. ✅ CMake should find CLI11 from system package
2. ✅ vcpkg will only build jwt-cpp and picojson
3. ✅ OpenCV libraries should be found automatically
4. ✅ Bot should start successfully

---

## Verification

Check build logs for:
- `Found CLI11 via system package: /usr/include`
- `Found OpenCV libraries in: /usr/lib/x86_64-linux-gnu`
- No vcpkg cli11 build errors
- Bot starts without library errors

---

**Rebuild required for changes to take effect!** 🚀

