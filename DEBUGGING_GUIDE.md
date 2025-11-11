# 🔍 Debugging Guide - Container Exit Issues

## Problem: Container Exits with Code 1

### Symptoms
- Container starts then immediately exits
- Exit code: 1
- No visible logs
- Error: "could not load cache"

### Root Cause
The build cache is corrupted or incomplete. The build directory exists but doesn't have the executable.

### Solution Applied

1. **Added Build Cache Cleanup**
   - Detects incomplete build directories
   - Cleans corrupted CMake cache
   - Forces rebuild if executable is missing

2. **Enabled Verbose Logging**
   - Build process now logs to stderr
   - Errors are visible in Docker logs
   - Build steps are logged

3. **Fixed Build Process**
   - Checks for executable before skipping build
   - Cleans cache if corrupted
   - Forces cmake configuration if cache missing

### How to Debug

#### Step 1: Check Container Status
```bash
docker ps -a | grep zoom-bot-1
```

#### Step 2: Check Logs
```bash
docker logs zoom-bot-1
```

#### Step 3: Check Build Status
```bash
# Check if executable exists
docker exec zoom-bot-1 test -f /tmp/meeting-sdk-linux-sample/build/zoomsdk

# Check build directory
docker exec zoom-bot-1 ls -la /tmp/meeting-sdk-linux-sample/build/
```

#### Step 4: Clean Build Cache (if needed)
```bash
# Remove build cache volume
docker volume rm meetingsdk-headless-linux-sample_build-cache

# Restart container (will rebuild)
docker compose -f compose-50-bots.yaml up -d bot-1
```

### Expected Build Process

1. **CMake Configuration** (first time only)
   - Downloads and installs vcpkg dependencies
   - Configures build system
   - Takes 5-10 minutes first time

2. **Application Build**
   - Compiles C++ source code
   - Links libraries
   - Creates executable

3. **Application Run**
   - Starts Zoom SDK
   - Joins meeting
   - Runs continuously

### Build Time Estimates

- **First Build**: 10-15 minutes (dependencies + build)
- **Subsequent Builds**: 2-5 minutes (if cache exists)
- **Clean Build**: 10-15 minutes (if cache removed)

### Common Issues

#### Issue: "could not load cache"
**Solution**: Clean build cache and rebuild
```bash
docker volume rm meetingsdk-headless-linux-sample_build-cache
docker compose -f compose-50-bots.yaml up -d bot-1
```

#### Issue: Build takes too long
**Solution**: Wait for first build to complete (10-15 minutes)

#### Issue: Executable not found
**Solution**: Check build logs for errors
```bash
docker logs zoom-bot-1 | grep -i "error\|fail"
```

### Verification Steps

After build completes, verify:

1. **Container is running**
   ```bash
   docker ps | grep zoom-bot-1
   ```

2. **Executable exists**
   ```bash
   docker exec zoom-bot-1 test -f /tmp/meeting-sdk-linux-sample/build/zoomsdk && echo "OK"
   ```

3. **Application is running**
   ```bash
   docker exec zoom-bot-1 ps aux | grep zoomsdk
   ```

4. **Bot joined meeting**
   - Check Zoom meeting participants
   - Look for bot name (Bot-1-Alice)

### Next Steps

Once build completes successfully:
1. Container should stay running
2. Bot should join meeting
3. Check Zoom meeting for bot presence
4. Monitor logs for any errors

---

**Note**: First build takes longer due to dependency installation. Subsequent builds are faster due to cache.

