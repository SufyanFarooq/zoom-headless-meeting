# 🔴 Container Exit Issue - Debugging Summary

## Problem
Container exits immediately with code 1 after starting.

## Error Messages
```
CMake Error: CMake was unable to find a build program corresponding to "Unix Makefiles". CMAKE_MAKE_PROGRAM is not set.
CMake Error: CMAKE_C_COMPILER not set, after EnableLanguage
CMake Error: CMAKE_CXX_COMPILER not set, after EnableLanguage
ERROR: Build failed - executable not found at build/zoomsdk
```

## Root Cause
The build process is failing because:
1. **CMake can't find make/build tools** - CMAKE_MAKE_PROGRAM not set
2. **Compilers not found** - CMAKE_C_COMPILER and CMAKE_CXX_COMPILER not set
3. **Build cache corrupted** - Build directory exists but incomplete

## Current Status
- ✅ Logging enabled - can see build errors
- ✅ Build cache cleanup added - detects incomplete builds
- ❌ Build still failing - CMake can't find build tools

## Solutions Applied

### 1. Enabled Verbose Logging
- Build process now logs to stderr
- Errors visible in Docker logs
- Can see build steps

### 2. Added Build Cache Cleanup
- Detects incomplete build directories
- Cleans corrupted CMake cache
- Forces rebuild if executable missing

### 3. Fixed Build Process
- Checks for executable before skipping build
- Cleans cache if corrupted
- Forces cmake configuration if cache missing

## Next Steps

### Option 1: Rebuild Docker Image
```bash
# Rebuild image to ensure build tools are installed
docker compose -f compose-50-bots.yaml build --no-cache bot-1

# Start container
docker compose -f compose-50-bots.yaml up -d bot-1
```

### Option 2: Check Build Tools in Container
```bash
# Check if build tools exist
docker run --rm meetingsdk-headless-linux-sample-bot-1 which make g++ cmake

# Check build-essential
docker run --rm meetingsdk-headless-linux-sample-bot-1 dpkg -l | grep build-essential
```

### Option 3: Use Different Build Directory
The build cache volume might be causing issues. Try building without cache:
```bash
# Remove build cache volume
docker volume rm meetingsdk-headless-linux-sample_build-cache

# Start container (will rebuild)
docker compose -f compose-50-bots.yaml up -d bot-1
```

### Option 4: Check Dockerfile
Verify that build-essential is installed in the Dockerfile:
```dockerfile
RUN apt-get install -y build-essential cmake
```

## Debugging Commands

### Check Container Status
```bash
docker ps -a | grep zoom-bot-1
```

### Check Logs
```bash
docker logs zoom-bot-1
docker logs zoom-bot-1 | grep -i "error\|fail"
```

### Check Build Directory
```bash
docker exec zoom-bot-1 ls -la /tmp/meeting-sdk-linux-sample/build/
docker exec zoom-bot-1 test -f /tmp/meeting-sdk-linux-sample/build/zoomsdk
```

### Check Build Tools
```bash
docker exec zoom-bot-1 which make g++ cmake
docker exec zoom-bot-1 make --version
docker exec zoom-bot-1 g++ --version
```

## Expected Behavior

### First Build (10-15 minutes)
1. CMake configuration
2. vcpkg dependency installation
3. Application compilation
4. Executable creation

### Subsequent Builds (2-5 minutes)
1. Check if executable exists
2. Skip build if exists
3. Run application

## Current Issue

The build is failing at the CMake configuration stage because:
- CMake can't find make/build tools
- Compilers not detected
- Build cache might be corrupted

## Recommendation

1. **Rebuild Docker image** to ensure build tools are installed
2. **Remove build cache volume** to start fresh
3. **Check Dockerfile** to verify build-essential is installed
4. **Monitor logs** to see if build completes

---

**Status**: Build failing - CMake can't find build tools
**Next Action**: Rebuild Docker image or check build tools installation

