# 🧪 10 Bots Local Test (With Video)

## 📋 Configuration

- **Video File**: `input-video.mp4` (170KB, 720p @ 15fps)
- **Recording**: Disabled (audio & video)
- **Video Sending**: Enabled
- **All Bots**: Same video file

## 🚀 Local Test Steps

### Step 1: Verify Setup

```bash
# Check video file exists
ls -lh input-video.mp4

# Check config
cat config.toml | grep -A 3 RawVideo

# Verify compose file
docker compose -f compose-50-bots.yaml config
```

### Step 2: Build (if needed)

```bash
# Build all 10 bots
docker compose -f compose-50-bots.yaml build

# Or build specific bot
docker compose -f compose-50-bots.yaml build bot-1
```

### Step 3: Start 10 Bots

```bash
# Start all bots
docker compose -f compose-50-bots.yaml up -d

# Check status
docker ps | grep zoom-bot | wc -l
# Should show: 10
```

### Step 4: Monitor Resources

```bash
# Real-time stats
docker stats

# Or specific monitoring
watch -n 2 'docker ps | grep zoom-bot | wc -l && docker stats --no-stream | head -12'
```

### Step 5: Check Logs

```bash
# All logs
docker compose -f compose-50-bots.yaml logs -f

# Specific bot
docker logs zoom-bot-1 -f

# Check for video sending
docker compose -f compose-50-bots.yaml logs | grep -i "video"
```

### Step 6: Verify in Zoom Meeting

1. Open Zoom meeting
2. Check participants list (should show 10 bots)
3. Verify all bots have video enabled
4. Check video is playing

## 📊 Expected Resources (10 Bots)

| Resource | Expected | Warning | Critical |
|----------|----------|---------|----------|
| **CPU** | 310-480% | 600% | > 800% |
| **Memory** | 1.4-1.5GB | 2GB | > 2.5GB |
| **Network** | ~33MB sent | 50MB | > 100MB |
| **Bots Running** | 10/10 | 8-9/10 | < 8/10 |

## ✅ Success Indicators

- ✅ All 10 bots join meeting
- ✅ All bots show video
- ✅ CPU: 310-480%
- ✅ Memory: ~1.5GB
- ✅ No errors in logs

## 🛑 Stop Test

```bash
# Stop all bots
docker compose -f compose-50-bots.yaml down

# Clean up (optional)
docker system prune -f
```

## 📋 Troubleshooting

### Bots not joining
```bash
# Check logs
docker compose -f compose-50-bots.yaml logs | grep -i error

# Check config
docker exec zoom-bot-1 cat /tmp/meeting-sdk-linux-sample/config.toml
```

### Video not showing
```bash
# Check video file in container
docker exec zoom-bot-1 ls -lh /tmp/meeting-sdk-linux-sample/input-video.mp4

# Check video sending logs
docker logs zoom-bot-1 | grep -i "video"
```

### High CPU/Memory
```bash
# Check individual bot resources
docker stats zoom-bot-1 zoom-bot-2 zoom-bot-3

# Reduce bots if needed
docker compose -f compose-50-bots.yaml up -d bot-1 bot-2 bot-3
```

## 🚀 Next: Server Deployment

After successful local test, proceed to server deployment.

