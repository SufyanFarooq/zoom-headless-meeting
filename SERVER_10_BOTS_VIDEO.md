# 🚀 Server Deployment - 10 Bots with Video (GCP e2-standard-4)

## 📋 Server Specifications

- **Instance**: e2-standard-4
- **vCPUs**: 4 cores
- **Memory**: 16GB RAM
- **Previous**: 100 bots without video (successful)
- **Current**: 10 bots with video (testing)

## 📊 Expected Resources (10 Bots with Video)

| Resource | Expected | Available | Status |
|----------|----------|-----------|--------|
| **CPU** | 310-480% (3.1-4.8 cores) | 400% (4 cores) | ⚠️ Tight |
| **Memory** | 1.4-1.5GB | 16GB | ✅ Plenty |
| **Network** | ~33MB sent | Standard | ✅ OK |
| **Disk** | ~170KB (video) | 30GB | ✅ Plenty |

## 🚀 Server Deployment Steps

### Step 1: Connect to Server

```bash
# SSH to GCP instance
gcloud compute ssh zoom-bots-server --zone=us-east1-b

# Or using SSH key
ssh -i your-key.pem user@server-ip
```

### Step 2: Verify Current Setup

```bash
# Check Docker
docker --version
docker compose version

# Check disk space
df -h

# Check current resources
free -h
nproc
```

### Step 3: Transfer Code (if needed)

```bash
# On local machine
gcloud compute scp --recurse ./meetingsdk-headless-linux-sample zoom-bots-server:~/ --zone=us-east1-b

# Or using git
cd ~/meetingsdk-headless-linux-sample
git pull
```

### Step 4: Verify Video File

```bash
# On server
cd ~/meetingsdk-headless-linux-sample

# Check video file exists
ls -lh input-video.mp4

# If not, upload it
# On local machine:
gcloud compute scp input-video.mp4 zoom-bots-server:~/meetingsdk-headless-linux-sample/ --zone=us-east1-b
```

### Step 5: Verify Config

```bash
# Check config.toml
cat config.toml

# Should show:
# [RawVideo]
# # file="meeting-video.mp4"  # Disabled
# input="input-video.mp4"      # Enabled
```

### Step 6: Generate 10 Bots

```bash
# Generate compose file
./generate-bots.sh 10

# Verify
docker compose -f compose-50-bots.yaml config
```

### Step 7: Build (if needed)

```bash
# Build all 10 bots
docker compose -f compose-50-bots.yaml build

# Or build in background
nohup docker compose -f compose-50-bots.yaml build > build.log 2>&1 &
tail -f build.log
```

### Step 8: Start 10 Bots

```bash
# Start all bots
docker compose -f compose-50-bots.yaml up -d

# Check status
docker ps | grep zoom-bot | wc -l
# Should show: 10
```

### Step 9: Monitor Resources

```bash
# Real-time monitoring
watch -n 2 'echo "Bots: $(docker ps | grep zoom-bot | wc -l)/10" && echo "" && top -bn1 | head -5 && echo "" && free -h && echo "" && docker stats --no-stream | head -12'

# Or detailed script
cat > monitor.sh << 'EOF'
#!/bin/bash
while true; do
  clear
  echo "=== 10 BOTS - SERVER MONITORING ==="
  echo "Bots: $(docker ps | grep zoom-bot | wc -l)/10"
  echo ""
  echo "CPU & Memory:"
  top -bn1 | head -5
  echo ""
  echo "Disk:"
  df -h | grep /dev/sda1
  echo ""
  echo "Docker Stats:"
  docker stats --no-stream | head -12
  sleep 3
done
EOF
chmod +x monitor.sh
./monitor.sh
```

### Step 10: Check Logs

```bash
# All logs
docker compose -f compose-50-bots.yaml logs -f

# Specific bot
docker logs zoom-bot-1 -f

# Check video sending
docker compose -f compose-50-bots.yaml logs | grep -i "video" | head -20
```

## 📊 Resource Monitoring

### Expected Values

- **CPU**: 310-480% (3.1-4.8 cores out of 4)
- **Memory**: 1.4-1.5GB (out of 16GB)
- **Network**: ~33MB sent
- **Bots Running**: 10/10

### Warning Signs

- CPU > 600%: Too high, reduce bots
- Memory > 2GB: Check for leaks
- Bots < 10: Check logs for errors

## ✅ Success Criteria

- ✅ All 10 bots join meeting
- ✅ All bots show video
- ✅ CPU: 310-480% (acceptable)
- ✅ Memory: < 2GB
- ✅ No errors in logs
- ✅ Stable for 10+ minutes

## 🔄 Scaling to More Bots

### For 20 Bots:
- CPU: ~620-960% (need 2x servers or larger instance)
- Memory: ~3GB
- Recommendation: Use 2 servers (10 bots each)

### For 50 Bots:
- CPU: ~1550-2400% (need 4-6 servers)
- Memory: ~7.5GB
- Recommendation: Use 5 servers (10 bots each)

### For 100 Bots:
- CPU: ~3100-4800% (need 8-10 servers)
- Memory: ~15GB
- Recommendation: Use 10 servers (10 bots each) OR 1 large server (64 cores)

## 🛑 Stop/Management

```bash
# Stop all bots
docker compose -f compose-50-bots.yaml down

# Stop specific bot
docker compose -f compose-50-bots.yaml stop bot-1

# Restart all
docker compose -f compose-50-bots.yaml restart

# View logs
docker compose -f compose-50-bots.yaml logs -f

# Clean up
docker compose -f compose-50-bots.yaml down
docker system prune -f
```

## 📋 Troubleshooting

### High CPU Usage
```bash
# Check individual bots
docker stats zoom-bot-1 zoom-bot-2

# Reduce bots if needed
docker compose -f compose-50-bots.yaml stop bot-6 bot-7 bot-8 bot-9 bot-10
```

### Memory Issues
```bash
# Check memory usage
free -h
docker stats --no-stream

# Restart if needed
docker compose -f compose-50-bots.yaml restart
```

### Video Not Showing
```bash
# Check video file
docker exec zoom-bot-1 ls -lh /tmp/meeting-sdk-linux-sample/input-video.mp4

# Check video logs
docker logs zoom-bot-1 | grep -i "video"
```

## 🎯 Next Steps

1. ✅ Test 10 bots locally
2. ✅ Deploy 10 bots on server
3. ✅ Monitor for 10-15 minutes
4. ✅ Scale to 20-50 bots if stable
5. ✅ Optimize further if needed

