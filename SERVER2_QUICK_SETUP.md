# Server 2 Quick Setup - Extract aur Start

## Current Situation
- ✅ Package upload ho gaya: `~/bot-server-only.tar.gz` (253 MB)
- ✅ Server: `zoom-bots-server` (GCP)
- ✅ User: `sufyanmaviya400`

## Quick Commands (Copy-Paste)

### Step 1: Move aur Extract

```bash
# Create directory
sudo mkdir -p /opt/zoom-headless-meeting

# Move package to /opt
sudo mv ~/bot-server-only.tar.gz /opt/

# Extract
cd /opt
sudo tar -xzf bot-server-only.tar.gz

# Fix permissions
sudo chown -R $USER:$USER /opt/zoom-headless-meeting
cd /opt/zoom-headless-meeting
sudo chmod +x bin/*.sh

# Verify
ls -la
```

### Step 2: Create .env File

```bash
cd /opt/zoom-headless-meeting
cat > .env << 'EOF'
BOT_SERVER_PORT=3001
SERVER_CAPACITY=10
BOT_PROJECT_DIR=/app/bot-project
HOST_PROJECT_PATH=/opt/zoom-headless-meeting
EOF
```

### Step 3: Install Docker (if needed)

```bash
# Check if Docker installed
docker --version

# If not installed:
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Logout and login again
exit
# Then SSH again
```

### Step 4: Start Bot Server

```bash
cd /opt/zoom-headless-meeting
docker compose -f docker-compose.bot-server.yml up -d
```

### Step 5: Verify

```bash
# Check health
curl http://localhost:3001/health

# Check logs
docker compose -f docker-compose.bot-server.yml logs -f

# Check running containers
docker ps
```

### Step 6: Register on Server 1

```bash
curl -X POST http://SERVER1_IP:3000/api/bot-servers \
  -H "Content-Type: application/json" \
  -d '{
    "serverName": "server-2",
    "serverUrl": "http://35.227.36.166:3001",
    "capacity": 10,
    "priority": 2
  }'
```

---

## One-Line Setup (If script uploaded)

```bash
# If setup script is available
chmod +x setup-server2-extract.sh
./setup-server2-extract.sh
```

---

## Troubleshooting

### Permission Denied?
```bash
sudo chown -R $USER:$USER /opt/zoom-headless-meeting
```

### Docker Permission Error?
```bash
sudo usermod -aG docker $USER
# Logout and login
exit
```

### Package Not Found?
```bash
# Check where package is
ls -lh ~/bot-server-only.tar.gz
ls -lh /opt/bot-server-only.tar.gz

# If in home directory, move it
sudo mv ~/bot-server-only.tar.gz /opt/
```

### Extract Failed?
```bash
# Check disk space
df -h

# Check package integrity
file /opt/bot-server-only.tar.gz
tar -tzf /opt/bot-server-only.tar.gz | head -10
```

---

## Complete Command Sequence

Copy-paste ye sab commands:

```bash
# 1. Move and extract
sudo mkdir -p /opt/zoom-headless-meeting
sudo mv ~/bot-server-only.tar.gz /opt/
cd /opt
sudo tar -xzf bot-server-only.tar.gz
sudo chown -R $USER:$USER /opt/zoom-headless-meeting
cd /opt/zoom-headless-meeting
sudo chmod +x bin/*.sh

# 2. Create .env
cat > .env << 'EOF'
BOT_SERVER_PORT=3001
SERVER_CAPACITY=10
BOT_PROJECT_DIR=/app/bot-project
HOST_PROJECT_PATH=/opt/zoom-headless-meeting
EOF

# 3. Install Docker (if needed)
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    echo "Docker installed. Please logout and login again."
    exit
fi

# 4. Add to docker group (if not already)
if ! groups | grep -q docker; then
    sudo usermod -aG docker $USER
    echo "Added to docker group. Please logout and login again."
    exit
fi

# 5. Start bot server
docker compose -f docker-compose.bot-server.yml up -d

# 6. Verify
sleep 5
curl http://localhost:3001/health
```

---

## Summary

**Current Location:** `~/bot-server-only.tar.gz`  
**Target Location:** `/opt/zoom-headless-meeting/`

**Quick Commands:**
```bash
sudo mkdir -p /opt/zoom-headless-meeting
sudo mv ~/bot-server-only.tar.gz /opt/
cd /opt && sudo tar -xzf bot-server-only.tar.gz
sudo chown -R $USER:$USER /opt/zoom-headless-meeting
cd /opt/zoom-headless-meeting
cat > .env << 'EOF'
BOT_SERVER_PORT=3001
SERVER_CAPACITY=10
BOT_PROJECT_DIR=/app/bot-project
HOST_PROJECT_PATH=/opt/zoom-headless-meeting
EOF
docker compose -f docker-compose.bot-server.yml up -d
```

