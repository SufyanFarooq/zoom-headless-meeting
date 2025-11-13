# 🚀 Scale 10 to 100 Bots - Optimization Guide

## 📊 Current Status (10 Bots with Video)

### Actual Resource Usage:
- **CPU**: ~50% per bot (500% total for 10 bots)
- **Memory**: ~128MB per bot (1.3GB total for 10 bots)
- **Network**: ~2-3MB per bot (25MB total for 10 bots)

### Optimized Limits Applied:
- **CPU Limit**: 0.6 per bot (was 1.0)
- **Memory Limit**: 256MB per bot (was 2GB)
- **Savings**: 40% CPU, 87% Memory

## 📈 Scaling Roadmap

### Phase 1: 10 Bots (Current) ✅
- **Resources**: 500% CPU, 1.3GB RAM
- **Server**: e2-standard-4 (4 cores, 16GB)
- **Status**: ⚠️ Tight but working
- **Action**: Monitor and optimize

### Phase 2: 20 Bots
- **Resources**: ~1000% CPU, 2.6GB RAM
- **Server Options**:
  - **Option A**: 2x e2-standard-4 (10 bots each)
  - **Option B**: 1x e2-standard-8 (8 cores, 32GB)
- **Cost**: ~$200/month (2 servers) or ~$200/month (1 larger)
- **Recommendation**: 2 servers for redundancy

### Phase 3: 50 Bots
- **Resources**: ~2500% CPU, 6.5GB RAM
- **Server Options**:
  - **Option A**: 3x e2-standard-4 (17 bots each)
  - **Option B**: 1x e2-standard-16 (16 cores, 64GB)
- **Cost**: ~$300/month (3 servers) or ~$400/month (1 large)
- **Recommendation**: 3 servers for better distribution

### Phase 4: 100 Bots
- **Resources**: ~5000% CPU, 13GB RAM
- **Server Options**:
  - **Option A**: 5x e2-standard-4 (20 bots each)
  - **Option B**: 1x e2-standard-32 (32 cores, 128GB)
- **Cost**: ~$500/month (5 servers) or ~$800/month (1 large)
- **Recommendation**: 5 servers for scalability

## 🎯 Optimization Strategies

### 1. Resource Limits (Already Applied ✅)
```yaml
limits:
  cpus: '0.6'      # Optimized from 1.0
  memory: 256M     # Optimized from 2G
```

### 2. Video Settings (Already Optimized ✅)
- Resolution: 720p (1280x720)
- Frame Rate: 15 FPS
- File Size: 170KB

### 3. Container Optimization
- Disable unnecessary logging
- Use minimal base images
- Shared volumes for video file

### 4. System Optimization
- CPU governor: performance mode
- Docker daemon tuning
- Network optimization

## 📋 Step-by-Step Scaling

### Scale to 20 Bots:

**On Current Server:**
```bash
# Test with 15 bots first
./generate-bots.sh 15
docker compose -f compose-50-bots.yaml build
docker compose -f compose-50-bots.yaml up -d

# Monitor
docker stats
```

**If Stable, Add Second Server:**
```bash
# On server 2, deploy 10 bots
./generate-bots.sh 10
docker compose -f compose-50-bots.yaml up -d
```

### Scale to 50 Bots:

**Option 1: Multiple Servers (Recommended)**
- Server 1: 17 bots
- Server 2: 17 bots
- Server 3: 16 bots

**Option 2: Single Large Server**
- 1x e2-standard-16 (16 cores, 64GB)
- Deploy all 50 bots

### Scale to 100 Bots:

**Recommended: 5 Servers**
- Each server: 20 bots
- Load balanced
- Redundancy

## 💰 Cost Comparison

| Bots | Servers | Monthly Cost | Setup |
|------|---------|--------------|-------|
| 10 | 1x e2-standard-4 | ~$100 | Current |
| 20 | 2x e2-standard-4 | ~$200 | Easy |
| 50 | 3x e2-standard-4 | ~$300 | Medium |
| 100 | 5x e2-standard-4 | ~$500 | Complex |

## 🔧 Quick Commands

### Generate Bots:
```bash
./generate-bots.sh 20  # For 20 bots
./generate-bots.sh 50  # For 50 bots
```

### Deploy:
```bash
docker compose -f compose-50-bots.yaml build
docker compose -f compose-50-bots.yaml up -d
```

### Monitor:
```bash
# Resource usage
docker stats

# Bot count
docker ps | grep zoom-bot | wc -l

# Logs
docker compose -f compose-50-bots.yaml logs -f
```

## ⚠️ Important Notes

1. **Start Small**: Always test with fewer bots first
2. **Monitor Closely**: Watch CPU, memory, network
3. **Scale Gradually**: 10 → 20 → 50 → 100
4. **Keep Backups**: Save working configurations
5. **Test Stability**: Run for 30+ minutes before scaling

## 📊 Success Metrics

- ✅ CPU < 80% per server
- ✅ Memory < 80% per server
- ✅ All bots connected
- ✅ Video streaming stable
- ✅ No errors in logs

