# GCP Next Steps - After Server Setup

## Current Status ✅

- ✅ GCP instance created
- ✅ SSH connection established
- ✅ Ready for Docker installation

## Step-by-Step Next Steps

### Step 1: Install Docker (5 minutes)

**Copy and paste these commands one by one:**

```bash
# Update system packages
sudo apt-get update
sudo apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Logout and login again (important!)
exit
```

**Reconnect via SSH** (click SSH button again in GCP console)

**Verify installation:**

```bash
docker --version
docker-compose --version
docker run hello-world
```

Expected output:
- Docker version 24.x or higher
- Docker Compose version 2.x or higher
- "Hello from Docker!" message

---

### Step 2: Transfer Code (5 minutes)

**Option A: Using Git (Recommended if repo is accessible)**

```bash
cd ~
git clone <your-repo-url> meetingsdk-headless-linux-sample
cd meetingsdk-headless-linux-sample
```

**Option B: Using gcloud scp (from your local machine)**

```bash
# On your local machine (not on server)
gcloud compute scp --recurse ./meetingsdk-headless-linux-sample zoom-bots-server:~/ --zone=us-east1-b
```

**Option C: Using Browser Upload**

1. **In SSH browser window**, click **"UPLOAD FILE"** button (top bar)
2. **Select** your project folder (zip it first)
3. **Upload** to home directory
4. **Extract:**
```bash
cd ~
unzip meetingsdk-headless-linux-sample.zip
cd meetingsdk-headless-linux-sample
```

**Option D: Using rsync (from local machine)**

```bash
# On your local machine
rsync -avz -e "gcloud compute ssh --zone=us-east1-b" ./meetingsdk-headless-linux-sample/ zoom-bots-server:~/meetingsdk-headless-linux-sample/
```

---

### Step 3: Verify Code is Present

```bash
# Check if files are there
ls -la

# Should see:
# - generate-bots.sh
# - Dockerfile
# - src/
# - bin/
# - etc.

# Verify generate-bots.sh exists
ls -la generate-bots.sh
```

---

### Step 4: Deploy 100 Bots (20-30 minutes)

**Option A: Using Automated Script (Recommended)**

```bash
# Make script executable
chmod +x GCP_QUICK_START.sh

# Run deployment
./GCP_QUICK_START.sh 100
```

**Option B: Manual Deployment**

```bash
# Generate compose file for 100 bots
./generate-bots.sh 100

# Build Docker images (takes 15-20 minutes)
docker compose -f compose-50-bots.yaml build

# Start all bots
docker compose -f compose-50-bots.yaml up -d

# Check status
docker compose -f compose-50-bots.yaml ps
```

---

### Step 5: Monitor Deployment

**Check if bots are starting:**

```bash
# Count running containers
docker ps | grep zoom-bot | wc -l

# Should gradually increase from 0 to 100

# View logs
docker compose -f compose-50-bots.yaml logs -f

# Check specific bot
docker logs zoom-bot-1 -f

# Check resource usage
docker stats --no-stream | head -20
```

**Watch for:**
- ✅ "✅ configure" messages
- ✅ "✅ initialize" messages
- ✅ "✅ authorize" messages
- ⚠️ Any error messages

---

### Step 6: Verify Bots are Working

**Check in Zoom Meeting:**
1. Open your Zoom meeting
2. Check participants count
3. Should see bots joining (Bot-1-Alice, Bot-2-Bob, etc.)

**Check via Logs:**

```bash
# Count successful authentications
docker compose -f compose-50-bots.yaml logs | grep "✅ authorize" | wc -l

# Count connected bots
docker compose -f compose-50-bots.yaml logs | grep "✅ connected" | wc -l

# Check for errors
docker compose -f compose-50-bots.yaml logs | grep -i error | tail -20
```

---

## Quick Command Reference

### Essential Commands

```bash
# Check running bots
docker ps | grep zoom-bot

# Count running bots
docker ps | grep zoom-bot | wc -l

# View all logs
docker compose -f compose-50-bots.yaml logs -f

# View specific bot logs
docker logs zoom-bot-1 -f

# Check resource usage
docker stats

# Stop all bots
docker compose -f compose-50-bots.yaml down

# Start all bots
docker compose -f compose-50-bots.yaml up -d

# Restart all bots
docker compose -f compose-50-bots.yaml restart
```

### Monitoring Commands

```bash
# System resources
free -h
top
htop  # (install: sudo apt-get install htop)

# Docker resources
docker stats --no-stream
docker system df

# Check disk space
df -h
```

---

## Troubleshooting

### Docker Not Found After Installation

```bash
# If "docker: command not found" after logout/login
# Try:
newgrp docker

# Or reconnect via SSH
```

### Build Fails

```bash
# Check memory
free -h

# If low memory, add swap
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Retry build
docker compose -f compose-50-bots.yaml build
```

### Bots Not Starting

```bash
# Check logs for errors
docker compose -f compose-50-bots.yaml logs | grep -i error

# Check specific bot
docker logs zoom-bot-1 --tail 50

# Restart failed bot
docker compose -f compose-50-bots.yaml restart bot-1
```

### Out of Disk Space

```bash
# Check disk
df -h

# Clean Docker
docker system prune -a

# Remove unused images
docker image prune -a
```

---

## Expected Timeline

- **Docker installation:** 5 minutes
- **Code transfer:** 5 minutes
- **Build process:** 15-20 minutes (first time)
- **Bot startup:** 2-5 minutes
- **Total:** ~30-40 minutes

---

## Success Indicators

You'll know it's working when you see:

1. **In logs:**
   ```
   ✅ configure
   ✅ initialize
   ✅ authorize
   ✅ join a meeting
   ⏳ connecting to the meeting
   ✅ connected
   ```

2. **In Zoom meeting:**
   - Bots appearing in participants list
   - Names like: Bot-1-Alice, Bot-2-Bob, etc.

3. **In Docker:**
   ```bash
   docker ps | grep zoom-bot | wc -l
   # Should show: 100
   ```

---

## Next Actions

1. ✅ **Install Docker** (Step 1 above)
2. ✅ **Transfer code** (Step 2 above)
3. ✅ **Deploy bots** (Step 4 above)
4. ✅ **Monitor** (Step 5 above)
5. ✅ **Verify in Zoom** (Step 6 above)

---

## Quick Copy-Paste Commands

**Complete setup in one go:**

```bash
# 1. Install Docker
sudo apt-get update && sudo apt-get upgrade -y
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
echo "✅ Docker installed. Please logout and login again, then continue with code transfer."
```

**After reconnecting:**

```bash
# 2. Transfer code (choose one method from Step 2)
# 3. Deploy
cd ~/meetingsdk-headless-linux-sample
./generate-bots.sh 100
docker compose -f compose-50-bots.yaml build
docker compose -f compose-50-bots.yaml up -d
docker compose -f compose-50-bots.yaml ps
```

---

## Support

If you encounter issues:
1. Check logs: `docker compose -f compose-50-bots.yaml logs`
2. Check resources: `free -h`, `df -h`
3. Review troubleshooting section above
4. Check GCP instance status in console

