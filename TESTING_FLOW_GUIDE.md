# 🧪 Testing Flow Guide - Complete Testing Process

## 📋 Table of Contents
1. [Single Bot Testing](#1-single-bot-testing)
2. [Multiple Bots Testing](#2-multiple-bots-testing)
3. [Verification Steps](#3-verification-steps)
4. [Debugging Guide](#4-debugging-guide)
5. [Common Issues](#5-common-issues)

---

## 1. Single Bot Testing

### Step 1: Generate Compose File
```bash
# Generate compose file for 1 bot
./generate-bots.sh 1
```

### Step 2: Start Single Bot
```bash
# Start bot-1
docker compose -f compose-50-bots.yaml up -d bot-1
```

### Step 3: Check Status
```bash
# Check if container is running
docker ps | grep zoom-bot-1

# Check logs
docker logs zoom-bot-1

# Check if bot joined meeting
docker logs zoom-bot-1 | grep -i "join\|meeting\|success"
```

### Step 4: Verify in Zoom Meeting
- Open Zoom meeting in browser/app
- Check participants list
- Look for "Bot-1-Alice" in participants

### Step 5: Stop Bot
```bash
# Stop single bot
docker compose -f compose-50-bots.yaml stop bot-1

# Remove container
docker compose -f compose-50-bots.yaml rm -f bot-1
```

---

## 2. Multiple Bots Testing

### Step 1: Generate Compose File
```bash
# Generate compose file for N bots (e.g., 10, 50, 100)
./generate-bots.sh 10
```

### Step 2: Start All Bots
```bash
# Start all bots
docker compose -f compose-50-bots.yaml up -d

# Or start specific number
docker compose -f compose-50-bots.yaml up -d --scale bot-1=10
```

### Step 3: Check Status
```bash
# Count running bots
docker ps | grep zoom-bot | wc -l

# List all running bots
docker ps | grep zoom-bot

# Check resource usage
docker stats --no-stream | grep zoom-bot | head -10
```

### Step 4: Monitor Logs
```bash
# View logs of specific bot
docker logs zoom-bot-1
docker logs zoom-bot-5
docker logs zoom-bot-10

# View all logs
docker compose -f compose-50-bots.yaml logs -f

# View logs of specific bot with follow
docker logs -f zoom-bot-1
```

### Step 5: Verify in Zoom Meeting
- Open Zoom meeting
- Check participants count
- Verify all bot names (Bot-1-Alice, Bot-2-Bob, etc.)
- Check if all bots are visible

### Step 6: Stop All Bots
```bash
# Stop all bots
docker compose -f compose-50-bots.yaml down

# Or stop specific bots
docker compose -f compose-50-bots.yaml stop bot-1 bot-2 bot-3
```

---

## 3. Verification Steps

### ✅ Container Status Check
```bash
# Check running containers
docker ps | grep zoom-bot

# Check all containers (including stopped)
docker ps -a | grep zoom-bot

# Check container status
docker inspect zoom-bot-1 --format='{{.State.Status}}'
```

### ✅ Application Status Check
```bash
# Check if application is running inside container
docker exec zoom-bot-1 ps aux | grep zoomsdk

# Check if executable exists
docker exec zoom-bot-1 test -f /tmp/meeting-sdk-linux-sample/build/zoomsdk && echo "OK" || echo "Missing"

# Check build directory
docker exec zoom-bot-1 ls -la /tmp/meeting-sdk-linux-sample/build/
```

### ✅ Resource Usage Check
```bash
# Check CPU and memory usage
docker stats --no-stream | grep zoom-bot

# Check total resource usage
docker stats --no-stream | grep zoom-bot | awk '{cpu+=$3; mem+=$4} END {print "CPU: " cpu "% Memory: " mem}'
```

### ✅ Network Check
```bash
# Check network connectivity
docker exec zoom-bot-1 ping -c 3 us05web.zoom.us

# Check DNS resolution
docker exec zoom-bot-1 nslookup us05web.zoom.us
```

### ✅ Zoom Meeting Verification
1. **Join Meeting**: Open Zoom meeting URL in browser
2. **Check Participants**: Look for bot names in participants list
3. **Count Participants**: Verify number of bots joined
4. **Check Audio/Video**: Verify bots are connected (if enabled)

---

## 4. Debugging Guide

### 🔍 Check Logs
```bash
# View recent logs
docker logs zoom-bot-1 --tail 50

# View all logs
docker logs zoom-bot-1

# Follow logs in real-time
docker logs -f zoom-bot-1

# View logs with timestamps
docker logs zoom-bot-1 -t
```

### 🔍 Check Container Exit Code
```bash
# Check exit code
docker inspect zoom-bot-1 --format='{{.State.ExitCode}}'

# Check restart count
docker inspect zoom-bot-1 --format='{{.RestartCount}}'

# Check container status
docker inspect zoom-bot-1 --format='{{.State.Status}}'
```

### 🔍 Check Build Status
```bash
# Check if build directory exists
docker exec zoom-bot-1 ls -la /tmp/meeting-sdk-linux-sample/build/

# Check if executable exists
docker exec zoom-bot-1 test -f /tmp/meeting-sdk-linux-sample/build/zoomsdk && echo "OK" || echo "Missing"

# Check build logs
docker logs zoom-bot-1 | grep -i "build\|cmake\|error"
```

### 🔍 Check Configuration
```bash
# Check environment variables
docker exec zoom-bot-1 env | grep -E "CLIENT_ID|CLIENT_SECRET|JOIN_URL|DISPLAY_NAME"

# Check command arguments
docker inspect zoom-bot-1 --format='{{.Config.Cmd}}'
```

### 🔍 Enable Debug Logging
```bash
# Temporarily enable logging (edit entry-bot-optimized.sh)
# Change: exec ./"$BUILD"/zoomsdk "$@" > /dev/null 2>&1
# To: exec ./"$BUILD"/zoomsdk "$@" 2>&1 | tee /tmp/meeting-sdk-linux-sample/out/debug.log

# Then check logs
docker exec zoom-bot-1 cat /tmp/meeting-sdk-linux-sample/out/debug.log
```

---

## 5. Common Issues

### ❌ Issue: Container Exits Immediately
**Symptoms:**
- Container starts then exits
- Exit code: 1 or 143
- No logs visible

**Debug Steps:**
```bash
# Check exit code
docker inspect zoom-bot-1 --format='{{.State.ExitCode}}'

# Check logs
docker logs zoom-bot-1

# Check if executable exists
docker exec zoom-bot-1 test -f /tmp/meeting-sdk-linux-sample/build/zoomsdk
```

**Solutions:**
1. Check build status
2. Verify configuration
3. Enable debug logging
4. Check application logs

### ❌ Issue: Container Restarts Continuously
**Symptoms:**
- Container keeps restarting
- Restart count increasing
- High CPU usage

**Debug Steps:**
```bash
# Check restart count
docker inspect zoom-bot-1 --format='{{.RestartCount}}'

# Check restart policy
docker inspect zoom-bot-1 --format='{{.HostConfig.RestartPolicy.Name}}'

# Check logs
docker logs zoom-bot-1 --tail 100
```

**Solutions:**
1. Change restart policy to `no` temporarily
2. Fix application crash
3. Check resource limits
4. Verify configuration

### ❌ Issue: Bots Not Joining Meeting
**Symptoms:**
- Containers running
- No bots in Zoom meeting
- No join messages in logs

**Debug Steps:**
```bash
# Check logs for join messages
docker logs zoom-bot-1 | grep -i "join\|meeting\|auth"

# Check network connectivity
docker exec zoom-bot-1 ping -c 3 us05web.zoom.us

# Check configuration
docker exec zoom-bot-1 env | grep JOIN_URL
```

**Solutions:**
1. Verify JOIN_URL is correct
2. Check network connectivity
3. Verify CLIENT_ID and CLIENT_SECRET
4. Check Zoom meeting settings

### ❌ Issue: High Resource Usage
**Symptoms:**
- High CPU usage (>100%)
- High memory usage
- System slowdown

**Debug Steps:**
```bash
# Check resource usage
docker stats --no-stream | grep zoom-bot

# Check per-container usage
docker stats --no-stream zoom-bot-1
```

**Solutions:**
1. Reduce number of bots
2. Adjust resource limits
3. Disable recording/video
4. Optimize application

---

## 6. Quick Testing Commands

### 🚀 Quick Start (1 Bot)
```bash
./generate-bots.sh 1
docker compose -f compose-50-bots.yaml up -d bot-1
docker logs -f zoom-bot-1
```

### 🚀 Quick Start (10 Bots)
```bash
./generate-bots.sh 10
docker compose -f compose-50-bots.yaml up -d
docker ps | grep zoom-bot | wc -l
```

### 🚀 Quick Start (50 Bots)
```bash
./generate-bots.sh 50
docker compose -f compose-50-bots.yaml up -d
docker stats --no-stream | grep zoom-bot | head -10
```

### 🛑 Quick Stop
```bash
# Stop all bots
docker compose -f compose-50-bots.yaml down

# Stop specific bot
docker compose -f compose-50-bots.yaml stop bot-1
```

### 📊 Quick Status Check
```bash
# Count running bots
docker ps | grep zoom-bot | wc -l

# Check resource usage
docker stats --no-stream | grep zoom-bot | head -5

# Check logs
docker logs zoom-bot-1 --tail 20
```

---

## 7. Testing Checklist

### ✅ Pre-Testing
- [ ] Docker is running
- [ ] Compose file generated
- [ ] Configuration verified (CLIENT_ID, CLIENT_SECRET, JOIN_URL)
- [ ] Zoom meeting is active

### ✅ During Testing
- [ ] Containers start successfully
- [ ] Bots join meeting
- [ ] Bot names visible in Zoom
- [ ] Resource usage acceptable
- [ ] No errors in logs

### ✅ Post-Testing
- [ ] Containers stop cleanly
- [ ] Resources released
- [ ] Logs reviewed
- [ ] Issues documented

---

## 8. Best Practices

1. **Start Small**: Test with 1 bot first, then scale up
2. **Monitor Resources**: Check CPU/memory usage regularly
3. **Check Logs**: Review logs for errors
4. **Verify in Zoom**: Always check Zoom meeting to confirm bots joined
5. **Clean Up**: Stop containers after testing
6. **Document Issues**: Note any problems for debugging

---

## 9. Example Testing Flow

```bash
# 1. Generate compose file
./generate-bots.sh 5

# 2. Start bots
docker compose -f compose-50-bots.yaml up -d

# 3. Wait a few seconds
sleep 10

# 4. Check status
docker ps | grep zoom-bot | wc -l

# 5. Check logs
docker logs zoom-bot-1 --tail 20

# 6. Check resource usage
docker stats --no-stream | grep zoom-bot

# 7. Verify in Zoom meeting (manually)

# 8. Stop bots
docker compose -f compose-50-bots.yaml down
```

---

**Happy Testing! 🚀**

