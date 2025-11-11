# Resize Disk on GCP Instance - Step by Step

## Current Status ✅

- ✅ Disk size increased to 30GB in GCP Console
- ⏳ Need to resize filesystem on instance

## Step-by-Step Resize

### Step 1: Check Current Disk Size (Before Resize)

```bash
# On your GCP instance (SSH terminal)
df -h
```

**Expected output:** Will show ~10GB (old size)

### Step 2: Resize the Filesystem

**For Debian/Ubuntu systems:**

```bash
# Method 1: Using growpart (recommended)
sudo growpart /dev/sda1 1
sudo resize2fs /dev/sda1

# Method 2: If growpart not available
sudo apt-get update
sudo apt-get install -y cloud-guest-utils
sudo growpart /dev/sda1 1
sudo resize2fs /dev/sda1
```

**For older systems:**

```bash
# Alternative method
sudo fdisk -l  # Check partition
sudo resize2fs /dev/sda1
```

### Step 3: Verify Resize

```bash
# Check disk size again
df -h
```

**Expected output:** Should now show ~30GB available

### Step 4: Clean Docker and Retry Build

```bash
# Clean up Docker
docker system prune -a --volumes -f
docker builder prune -a -f

# Check space
df -h
docker system df

# Retry build
docker compose -f compose-50-bots.yaml build
```

## Complete Commands (Copy-Paste)

```bash
# 1. Install resize tools (if needed)
sudo apt-get update
sudo apt-get install -y cloud-guest-utils

# 2. Resize partition
sudo growpart /dev/sda1 1

# 3. Resize filesystem
sudo resize2fs /dev/sda1

# 4. Verify
df -h

# 5. Clean Docker
docker system prune -a --volumes -f
docker builder prune -a -f

# 6. Check space
df -h
docker system df
```

## Troubleshooting

### If growpart command not found:

```bash
sudo apt-get update
sudo apt-get install -y cloud-guest-utils
```

### If resize fails:

```bash
# Check partition
sudo fdisk -l

# Manual resize
sudo resize2fs /dev/sda1
```

### If still showing old size:

1. **Reboot instance:**
   ```bash
   sudo reboot
   ```
2. **After reboot, try resize again**

## Expected Results

**Before resize:**
```
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1        10G  9.5G     0 100% /
```

**After resize:**
```
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1        30G  9.5G   19G  34% /
```

## Next Steps After Resize

1. ✅ Verify disk size: `df -h`
2. ✅ Clean Docker: `docker system prune -a --volumes -f`
3. ✅ Retry build: `docker compose -f compose-50-bots.yaml build`
4. ✅ Start bots: `docker compose -f compose-50-bots.yaml up -d`

