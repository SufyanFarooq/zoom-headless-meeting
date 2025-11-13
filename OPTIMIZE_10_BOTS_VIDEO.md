# 🚀 Optimize & Scale 10 Bots with Video

## 📊 Current Resource Usage (10 Bots with Video)

### Expected Resources:
- **CPU**: 310-480% (3.1-4.8 cores)
- **Memory**: 1.4-1.5GB total
- **Network**: ~33MB sent
- **Per Bot**: ~31-48% CPU, ~140-150MB RAM

## 🎯 Optimization Strategies

### 1. Reduce Resource Limits (Current: 1 CPU, 2GB RAM per bot)

**Current Limits:**
```yaml
limits:
  cpus: '1.0'
  memory: 2G
reservations:
  cpus: '0.2'
  memory: 512M
```

**Optimized Limits:**
```yaml
limits:
  cpus: '0.5'      # Reduced from 1.0
  memory: 256M     # Reduced from 2G
reservations:
  cpus: '0.1'      # Reduced from 0.2
  memory: 128M      # Reduced from 512M
```

**Expected Savings:**
- CPU: 50% reduction per bot
- Memory: 87% reduction per bot
- Total: ~155-240% CPU, ~1.3GB RAM for 10 bots

### 2. Video Optimization (Already Done ✅)
- Resolution: 720p (1280x720)
- Frame Rate: 15 FPS
- File Size: 170KB
- Status: Optimal

### 3. Container Optimization

**Add to compose file:**
```yaml
environment:
  - QT_LOGGING_RULES=*.debug=false;*.warning=false;*.info=false;*.critical=false
  - QT_QPA_PLATFORM=offscreen
  - G_MESSAGES_DEBUG=
  - OPENCV_VIDEOIO_DEBUG=0  # Disable OpenCV debug
  - OPENCV_LOG_LEVEL=ERROR   # Only errors
```

### 4. System-Level Optimization

**CPU Governor:**
```bash
# Set to performance mode (if available)
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

**Docker Daemon:**
```json
{
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 64000,
      "Soft": 64000
    }
  }
}
```

## 📈 Scaling Projections

### For 20 Bots (Optimized):
- **CPU**: 310-480% (3.1-4.8 cores)
- **Memory**: ~2.6GB
- **Server**: e2-standard-4 (4 cores, 16GB) - ✅ Sufficient

### For 50 Bots (Optimized):
- **CPU**: 775-1200% (7.75-12 cores)
- **Memory**: ~6.5GB
- **Server**: e2-standard-4 - ⚠️ Tight (need 2 servers or larger)

### For 100 Bots (Optimized):
- **CPU**: 1550-2400% (15.5-24 cores)
- **Memory**: ~13GB
- **Server**: Need 2-3 e2-standard-4 OR 1 e2-standard-16

## 🔧 Implementation Steps

### Step 1: Update Resource Limits

Edit `generate-bots.sh`:
```bash
limits:
  cpus: '0.5'
  memory: 256M
reservations:
  cpus: '0.1'
  memory: 128M
```

### Step 2: Regenerate Compose File
```bash
./generate-bots.sh 10
```

### Step 3: Rebuild & Test
```bash
docker compose -f compose-50-bots.yaml down
docker compose -f compose-50-bots.yaml build
docker compose -f compose-50-bots.yaml up -d
```

### Step 4: Monitor
```bash
docker stats
```

## 📊 Resource Comparison

| Configuration | CPU/Bot | Memory/Bot | Total CPU (10) | Total Memory (10) |
|---------------|---------|------------|----------------|-------------------|
| **Current** | 31-48% | 140-150MB | 310-480% | 1.4-1.5GB |
| **Optimized** | 15-24% | 128-130MB | 150-240% | 1.3GB |
| **Savings** | 50% | 13% | 50% | 13% |

## 🎯 Scaling Recommendations

### Immediate (10-20 bots):
- ✅ Current setup works
- ✅ Optimize resource limits
- ✅ Single server sufficient

### Medium (50 bots):
- Use 2 servers (25 bots each)
- OR 1 larger server (e2-standard-8)
- Load balancing recommended

### Large (100 bots):
- Use 3-4 servers (25-33 bots each)
- OR 1 large server (e2-standard-16)
- Consider Kubernetes for orchestration

## 📝 Next Steps

1. ✅ Check current resources
2. ⏳ Optimize resource limits
3. ⏳ Test with optimized limits
4. ⏳ Scale to 20 bots
5. ⏳ Monitor and adjust

