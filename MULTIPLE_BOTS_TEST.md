# 🧪 Multiple Bots Testing Guide

## ✅ Single Bot Success!

Single bot successfully joined the meeting! Now testing multiple bots.

## 🚀 Quick Commands

### Start 10 Bots
```bash
# Generate compose file
./generate-bots.sh 10

# Start all bots
docker compose -f compose-50-bots.yaml up -d

# Check status
docker ps | grep zoom-bot | wc -l
```

### Start 50 Bots
```bash
# Generate compose file
./generate-bots.sh 50

# Start all bots
docker compose -f compose-50-bots.yaml up -d

# Check status
docker ps | grep zoom-bot | wc -l
```

## 📊 Monitoring Commands

### Check Running Bots
```bash
# Count running bots
docker ps | grep zoom-bot | wc -l

# List all running bots
docker ps | grep zoom-bot

# Check specific bot
docker ps | grep zoom-bot-1
```

### Check Logs
```bash
# View logs of specific bot
docker logs zoom-bot-1
docker logs zoom-bot-5
docker logs zoom-bot-10

# View all logs
docker compose -f compose-50-bots.yaml logs -f

# View logs with follow
docker logs -f zoom-bot-1
```

### Check Resource Usage
```bash
# Check resource usage
docker stats --no-stream | grep zoom-bot | head -10

# Check specific bot
docker stats --no-stream zoom-bot-1
```

### Check Build Status
```bash
# Check if executable exists
docker exec zoom-bot-1 test -f /tmp/meeting-sdk-linux-sample/build/zoomsdk && echo "OK"

# Check build directory
docker exec zoom-bot-1 ls -la /tmp/meeting-sdk-linux-sample/build/
```

## ✅ Verification Steps

### 1. Container Status
- [ ] All containers started successfully
- [ ] No containers exited with errors
- [ ] All containers are running

### 2. Build Status
- [ ] Build completed successfully
- [ ] Executable exists
- [ ] No build errors

### 3. Application Status
- [ ] Application initialized
- [ ] Authorization successful
- [ ] Meeting joined successfully

### 4. Zoom Meeting Verification
- [ ] Open Zoom meeting
- [ ] Check participants count
- [ ] Verify bot names (Bot-1-Alice, Bot-2-Bob, etc.)
- [ ] All bots visible in participants list

## 📈 Expected Results

### 10 Bots
- **CPU Usage**: ~70-100% (0.7-1 core)
- **Memory Usage**: ~900 MB - 1.5 GB
- **Build Time**: 2-5 minutes (if cache exists)
- **Join Time**: 1-2 minutes per bot

### 50 Bots
- **CPU Usage**: ~350-400% (3.5-4 cores)
- **Memory Usage**: ~4.5-7.5 GB
- **Build Time**: 2-5 minutes (if cache exists)
- **Join Time**: 1-2 minutes per bot

## 🛑 Stop Commands

### Stop All Bots
```bash
# Stop all bots
docker compose -f compose-50-bots.yaml down

# Stop specific bots
docker compose -f compose-50-bots.yaml stop bot-1 bot-2 bot-3
```

### Stop and Remove
```bash
# Stop and remove containers
docker compose -f compose-50-bots.yaml down

# Stop and remove with volumes
docker compose -f compose-50-bots.yaml down -v
```

## 🔍 Troubleshooting

### Issue: Some Bots Not Joining
```bash
# Check logs of specific bot
docker logs zoom-bot-1 | grep -i "error\|fail\|join"

# Check if bot is running
docker ps | grep zoom-bot-1
```

### Issue: High Resource Usage
```bash
# Check resource usage
docker stats --no-stream | grep zoom-bot

# Check specific bot
docker stats --no-stream zoom-bot-1
```

### Issue: Build Failures
```bash
# Check build logs
docker logs zoom-bot-1 | grep -i "build\|cmake\|error"

# Check build directory
docker exec zoom-bot-1 ls -la /tmp/meeting-sdk-linux-sample/build/
```

## 📝 Testing Checklist

### Pre-Testing
- [ ] Single bot tested successfully
- [ ] Compose file generated
- [ ] Configuration verified
- [ ] Zoom meeting active

### During Testing
- [ ] All containers started
- [ ] Build completed successfully
- [ ] Bots joining meeting
- [ ] Resource usage acceptable

### Post-Testing
- [ ] All bots visible in Zoom
- [ ] No errors in logs
- [ ] Resource usage within limits
- [ ] Containers running stable

## 🎯 Next Steps

1. **Test 10 Bots**: Start with 10 bots to verify everything works
2. **Scale to 50**: Once 10 bots work, scale to 50
3. **Monitor Resources**: Check CPU/memory usage
4. **Verify in Zoom**: Confirm all bots joined
5. **Optimize**: Adjust resource limits if needed

---

**Happy Testing! 🚀**

