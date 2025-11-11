# Disk Space Error Fix - "no space left on device"

## Problem

Build process mein error:
```
no space left on device
```

**Cause:** Disk full ho gaya (10GB disk use kiya tha, 100 bots ke liye insufficient)

## Quick Fix

### Step 1: Check Disk Space

```bash
# Check current disk usage
df -h

# Check Docker disk usage
docker system df
```

### Step 2: Clean Up Docker (Immediate Fix)

```bash
# Stop all containers
docker compose -f compose-50-bots.yaml down

# Remove all unused Docker resources
docker system prune -a --volumes

# Remove build cache
docker builder prune -a

# Check space again
df -h
```

### Step 3: Increase Disk Size (Recommended)

**Option A: Resize Disk in GCP Console**

1. **Go to:** GCP Console → Compute Engine → Disks
2. **Find:** Your instance's disk
3. **Click:** "Edit" (pencil icon)
4. **Change:** Size from 10GB to **30GB**
5. **Save**
6. **Resize on instance:**
   ```bash
   sudo resize2fs /dev/sda1
   # Or for newer systems:
   sudo growpart /dev/sda1 1
   sudo resize2fs /dev/sda1
   ```

**Option B: Create New Instance with 30GB**

1. **Stop current instance**
2. **Create new instance** with 30GB disk
3. **Transfer code** again
4. **Deploy**

### Step 4: Build in Smaller Batches

Instead of building all 100 bots at once:

```bash
# Build 10 bots at a time
for i in {1..10}; do
    docker compose -f compose-50-bots.yaml build bot-$i
done

# Start them
docker compose -f compose-50-bots.yaml up -d bot-1 bot-2 bot-3 bot-4 bot-5 bot-6 bot-7 bot-8 bot-9 bot-10

# Clean up after each batch
docker system prune -f
```

## Complete Solution

### Immediate Actions

```bash
# 1. Stop everything
docker compose -f compose-50-bots.yaml down

# 2. Clean Docker
docker system prune -a --volumes -f
docker builder prune -a -f

# 3. Check space
df -h

# 4. If still low, remove old images
docker image prune -a -f
```

### Long-term Solution

**Increase disk to 30GB:**

1. **GCP Console** → Compute Engine → Disks
2. **Select disk** → Edit → **30GB**
3. **On instance:**
   ```bash
   sudo growpart /dev/sda1 1
   sudo resize2fs /dev/sda1
   df -h  # Verify
   ```

### Alternative: Build Fewer Bots

```bash
# Instead of 100, try 20-30 bots first
./generate-bots.sh 30
docker compose -f compose-50-bots.yaml build
docker compose -f compose-50-bots.yaml up -d
```

## Disk Space Requirements

| Bots | Disk Space Needed |
|------|-------------------|
| 10 bots | ~15GB |
| 30 bots | ~20GB |
| 50 bots | ~25GB |
| 100 bots | ~30GB+ |

## Prevention

1. **Always use 30GB disk** for 100 bots
2. **Clean Docker regularly:**
   ```bash
   docker system prune -f
   ```
3. **Monitor disk:**
   ```bash
   watch -n 5 'df -h'
   ```

