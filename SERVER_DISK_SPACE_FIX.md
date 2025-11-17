# 🚨 Server Disk Space Fix Guide

## Problem
```
failed to solve: failed to extract layer ... no space left on device
```

This means your server's disk is full. Docker needs space to build images.

---

## ⚡ Quick Fix

### Option 1: Automated Cleanup (Recommended)

```bash
# Make script executable
chmod +x cleanup-docker-space.sh

# Run cleanup
./cleanup-docker-space.sh
```

This will:
- ✅ Stop all containers
- ✅ Remove unused images
- ✅ Remove build cache
- ✅ Remove unused volumes
- ✅ Free up disk space

### Option 2: Manual Commands

```bash
# Check current disk usage
df -h

# Check Docker usage
docker system df

# Stop all containers
docker stop $(docker ps -q)

# Remove all unused images
docker image prune -a -f

# Remove build cache
docker builder prune -a -f

# Full cleanup
docker system prune -a -f --volumes
```

---

## 🔍 Check Disk Space

```bash
# Quick check
./check-disk-space.sh

# Or manually
df -h
docker system df
```

---

## 🧹 Additional Cleanup

If Docker cleanup isn't enough:

### 1. Clean System Logs
```bash
# Remove logs older than 3 days
sudo journalctl --vacuum-time=3d

# Or limit log size
sudo journalctl --vacuum-size=500M
```

### 2. Remove Old Backups
```bash
# Find old backup files
find . -name "*.backup.*" -mtime +7 -ls

# Remove old backups (older than 7 days)
find . -name "*.backup.*" -mtime +7 -delete
```

### 3. Clean Docker Compose Build Cache
```bash
# Remove build cache volume
docker volume rm meetingsdk-headless-linux-sample_build-cache 2>/dev/null || true

# Or remove all unused volumes
docker volume prune -f
```

### 4. Remove Large Files
```bash
# Find largest files
du -sh /* 2>/dev/null | sort -h | tail -10

# Find large files in current directory
find . -type f -size +100M -ls
```

---

## 📊 Monitor Disk Space

```bash
# Watch disk usage
watch -n 5 df -h

# Check specific directory
du -sh /var/lib/docker
du -sh ~/.docker
```

---

## 🎯 Prevent Future Issues

### 1. Regular Cleanup
```bash
# Add to crontab (weekly cleanup)
0 2 * * 0 /path/to/cleanup-docker-space.sh
```

### 2. Limit Docker Logs
Create `/etc/docker/daemon.json`:
```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

### 3. Use Multi-stage Builds
Optimize Dockerfile to reduce image size.

### 4. Remove Unused Images After Build
```bash
# In your build script
docker compose build
docker compose up -d
docker image prune -f  # Remove unused images
```

---

## 🚨 Emergency: Still No Space

If cleanup doesn't help:

1. **Check what's using space:**
   ```bash
   du -sh /* 2>/dev/null | sort -h
   ```

2. **Remove specific large images:**
   ```bash
   docker images
   docker rmi <image-id>
   ```

3. **Stop all services temporarily:**
   ```bash
   docker compose down
   docker system prune -a -f --volumes
   ```

4. **Consider increasing disk size** (if using cloud/VPS)

---

## ✅ After Cleanup

Once space is freed:

```bash
# Rebuild your bots
docker compose -f compose-50-bots.yaml build

# Or rebuild specific bot
docker compose -f compose-50-bots.yaml build bot-1
```

---

## 💡 Pro Tips

1. **Monitor regularly:**
   ```bash
   # Add to ~/.bashrc
   alias disk='df -h && echo "" && docker system df'
   ```

2. **Set up alerts** for disk usage > 80%

3. **Use external storage** for Docker data if possible

4. **Clean up after each build** in CI/CD pipelines

---

## 📚 Related Commands

```bash
# Check Docker disk usage
docker system df

# Detailed Docker disk usage
docker system df -v

# Remove everything (nuclear option)
docker system prune -a -f --volumes

# Check specific directory size
du -sh /var/lib/docker
du -sh /tmp
```

---

## 🔗 Quick Reference

| Command | Purpose |
|---------|---------|
| `df -h` | Check disk space |
| `docker system df` | Check Docker usage |
| `docker system prune -a -f` | Remove all unused Docker resources |
| `docker builder prune -a -f` | Remove build cache |
| `journalctl --vacuum-time=3d` | Clean system logs |

---

**Run `./cleanup-docker-space.sh` first, then rebuild!** 🚀

