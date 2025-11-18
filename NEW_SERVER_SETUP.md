# 🚀 Complete Server Setup Guide

## 📋 Prerequisites

### Server Requirements
- **OS**: Ubuntu 22.04 LTS (recommended)
- **CPU**: Minimum 4 cores (for ~13 bots), 65 cores (for 200+ bots)
- **RAM**: Minimum 16GB (for ~64 bots), 256GB (for 1000+ bots)
- **Storage**: Minimum 50GB free space
- **Docker**: Installed and running
- **Docker Compose**: v2.0+

---

## 🔧 Step 1: Install Dependencies

```bash
# Update system
sudo apt-get update
sudo apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose
sudo apt-get install docker-compose-plugin -y

# Verify installation
docker --version
docker compose version

# Add user to docker group (optional, to run without sudo)
sudo usermod -aG docker $USER
newgrp docker
```

---

## 📦 Step 2: Clone/Copy Project

### Option A: Git Clone
```bash
cd ~
git clone <your-repo-url> zoom-headless-meeting
cd zoom-headless-meeting
```

### Option B: Copy from Local Machine
```bash
# On your local machine
scp -r /path/to/project user@server:/home/user/zoom-headless-meeting

# On server
cd ~/zoom-headless-meeting
```

---

## 🔑 Step 3: Setup Zoom API Credentials

### 3.1 Get API Credentials
1. Go to [Zoom Marketplace](https://marketplace.zoom.us/)
2. Create a **Server-to-Server OAuth App**
3. Get:
   - **Account ID**
   - **Client ID**
   - **Client Secret**

### 3.2 Enable Required Scopes
In Zoom Marketplace app settings, enable:
- `user:read:admin`
- `user:write:admin`
- `user:write`

### 3.3 Set Environment Variables (Optional)
```bash
export ACCOUNT_ID="your_account_id"
export CLIENT_ID="your_client_id"
export CLIENT_SECRET="your_client_secret"
```

Or create `.env` file:
```bash
cat > .env << EOF
ACCOUNT_ID=your_account_id
CLIENT_ID=your_client_id
CLIENT_SECRET=your_client_secret
EOF
```

---

## 👥 Step 4: Create Zoom Users

### 4.1 Create Users List
```bash
# Create users.txt file
cat > profile-pics/users.txt << EOF
bot1@yourdomain.com
bot2@yourdomain.com
bot3@yourdomain.com
...
EOF
```

### 4.2 Run User Creation Script
```bash
chmod +x create-zoom-users.sh
./create-zoom-users.sh \
  YOUR_ACCOUNT_ID \
  YOUR_CLIENT_ID \
  YOUR_CLIENT_SECRET
```

**Note**: Users will receive activation emails. They need to be **active** before generating ZAK tokens.

---

## 🖼️ Step 5: Upload Profile Pictures

### 5.1 Prepare Profile Pictures
```bash
# Create profile-pics directory
mkdir -p profile-pics

# Add profile pictures (JPG/PNG)
# Name them: bot1.jpg, bot2.jpg, bot3.jpg, etc.
# Place in profile-pics/ directory
```

### 5.2 Upload Profile Pictures
```bash
chmod +x upload-profile-picture.sh
chmod +x update-profile-pictures.sh

# Upload all profile pictures
./update-profile-pictures.sh \
  YOUR_ACCOUNT_ID \
  YOUR_CLIENT_ID \
  YOUR_CLIENT_SECRET
```

---

## 🎫 Step 6: Generate ZAK Tokens

### 6.1 Generate ZAK Tokens for All Bots
```bash
chmod +x get-access-token.sh
chmod +x get-zak-token.sh
chmod +x auto-setup-bots.sh

# Generate ZAK tokens for all bots
./auto-setup-bots.sh \
  YOUR_ACCOUNT_ID \
  YOUR_CLIENT_ID \
  YOUR_CLIENT_SECRET
```

This will:
- Generate ZAK tokens for all users in `profile-pics/users.txt`
- Save tokens to `bot-zak-tokens.env`
- Update `compose-50-bots.yaml` with ZAK tokens

### 6.2 Verify Tokens
```bash
cat bot-zak-tokens.env
```

---

## 🎥 Step 7: Prepare Video Files

### 7.1 Create Videos Directory
```bash
mkdir -p videos
```

### 7.2 Add Video Files
```bash
# Copy your video files
# Name them: video-1.mp4, video-2.mp4, ..., video-10.mp4
# Place in videos/ directory

# Recommended video specs:
# - Resolution: 320x180 (or match SDK preferred)
# - FPS: 10-15
# - Codec: H.264 baseline
# - Format: yuv420p
# - Bitrate: 250 kbps
```

### 7.3 Verify Videos
```bash
ls -lh videos/
```

---

## ⚙️ Step 8: Configure Compose File

### 8.1 Update Meeting URL
Edit `compose-50-bots.yaml`:
```yaml
# Update JOIN_URL for each bot
- JOIN_URL=https://zoom.us/j/YOUR_MEETING_ID?pwd=YOUR_PASSWORD
```

### 8.2 Update API Credentials
```yaml
# Update CLIENT_ID and CLIENT_SECRET
- CLIENT_ID=your_client_id
- CLIENT_SECRET=your_client_secret
```

### 8.3 Adjust Resource Limits (if needed)
```yaml
deploy:
  resources:
    limits:
      cpus: '0.3'      # Adjust based on server capacity
      memory: 256M     # Adjust based on server capacity
```

---

## 🚀 Step 9: Build and Test

### 9.1 Build Docker Image
```bash
# Build for first bot (will build image)
docker compose -f compose-50-bots.yaml build bot-1
```

### 9.2 Test Single Bot
```bash
# Run one bot to test
docker compose -f compose-50-bots.yaml up bot-1

# Check logs
docker logs zoom-bot-1

# Stop bot
docker compose -f compose-50-bots.yaml stop bot-1
```

### 9.3 Verify Bot Joined Meeting
- Check Zoom meeting - bot should appear
- Verify profile picture is showing
- Verify mic icon is visible
- Verify video is playing

---

## 📊 Step 10: Check Resources and Scale

### 10.1 Check Server Resources
```bash
chmod +x check-server-resources.sh
./check-server-resources.sh
```

This will show:
- CPU cores and usage
- Memory available
- Disk space
- Bot capacity estimates

### 10.2 Scale Bots
```bash
chmod +x scale-bots.sh

# Scale to desired number of bots
./scale-bots.sh 20   # Scale to 20 bots
./scale-bots.sh 50   # Scale to 50 bots
./scale-bots.sh 100  # Scale to 100 bots
```

---

## 🎯 Step 11: Run All Bots

### 11.1 Run All Bots in Background
```bash
docker compose -f compose-50-bots.yaml up -d
```

### 11.2 Check Status
```bash
# List running containers
docker ps

# Check logs for specific bot
docker logs zoom-bot-1

# Check all logs
docker compose -f compose-50-bots.yaml logs -f
```

### 11.3 Monitor Resources
```bash
# Real-time resource monitoring
docker stats

# Or continuous monitoring
watch -n 1 docker stats
```

---

## 🛠️ Step 12: Troubleshooting

### Common Issues

#### Issue 1: Build Fails with OOM
**Solution**: Increase memory limit in `compose-50-bots.yaml`
```yaml
memory: 512M  # Change from 256M
```

#### Issue 2: GLIBC Mismatch
**Solution**: Script auto-detects and rebuilds. If persists:
```bash
docker volume rm meetingsdk-headless-linux-sample_build-cache
docker compose -f compose-50-bots.yaml build --no-cache bot-1
```

#### Issue 3: OpenCV Library Not Found
**Solution**: Script auto-creates symlinks. Check logs for details.

#### Issue 4: ZAK Token Expired
**Solution**: Regenerate ZAK tokens:
```bash
./auto-setup-bots.sh ACCOUNT_ID CLIENT_ID CLIENT_SECRET
```

#### Issue 5: Bot Not Joining
**Solution**: Check:
- Meeting URL is correct
- Meeting is active
- ZAK token is valid
- Bot user is active (not pending)

---

## 📝 Step 13: Maintenance

### Daily Operations

#### Start All Bots
```bash
docker compose -f compose-50-bots.yaml up -d
```

#### Stop All Bots
```bash
docker compose -f compose-50-bots.yaml down
```

#### Restart All Bots
```bash
docker compose -f compose-50-bots.yaml restart
```

#### Update Code
```bash
# Pull latest changes
git pull

# Rebuild and restart
docker compose -f compose-50-bots.yaml up -d --build
```

### Monitoring

#### Check Resource Usage
```bash
./check-server-resources.sh
docker stats --no-stream
```

#### Check Disk Space
```bash
df -h
./check-disk-space.sh  # If available
```

#### Clean Up Docker
```bash
./cleanup-docker-space.sh  # If available
```

---

## 📚 Quick Reference Commands

```bash
# Check resources
./check-server-resources.sh

# Scale bots
./scale-bots.sh <number>

# Run bots
docker compose -f compose-50-bots.yaml up -d

# Stop bots
docker compose -f compose-50-bots.yaml down

# View logs
docker compose -f compose-50-bots.yaml logs -f

# Monitor resources
docker stats

# Check specific bot
docker logs zoom-bot-1

# Restart specific bot
docker compose -f compose-50-bots.yaml restart bot-1
```

---

## ✅ Setup Checklist

- [ ] Server with Ubuntu 22.04
- [ ] Docker and Docker Compose installed
- [ ] Project code copied to server
- [ ] Zoom API credentials obtained
- [ ] API scopes enabled
- [ ] Zoom users created and activated
- [ ] Profile pictures uploaded
- [ ] ZAK tokens generated
- [ ] Video files prepared
- [ ] Compose file configured
- [ ] Single bot tested successfully
- [ ] Resources checked
- [ ] Bots scaled to desired number
- [ ] All bots running and verified

---

## 🎉 Success!

Once all steps are complete, your bots should be:
- ✅ Joining the meeting
- ✅ Showing profile pictures
- ✅ Displaying mic icons
- ✅ Playing video
- ✅ Running within resource limits

---

## 📞 Support

If you encounter issues:
1. Check logs: `docker logs zoom-bot-1`
2. Check resources: `./check-server-resources.sh`
3. Verify ZAK tokens: `cat bot-zak-tokens.env`
4. Check meeting URL and credentials

---

**Last Updated**: 2025-01-18

