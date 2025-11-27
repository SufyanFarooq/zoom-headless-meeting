# Multi-Server Setup Guide

## Architecture Overview

### Server 1 (Main Server) - Full Stack
- ✅ PostgreSQL Database
- ✅ API Server (port 3000)
- ✅ Dashboard UI (port 8080)
- ✅ Bot Server API (port 3001) - Can also run bots
- ✅ All code and builds

### Server 2 (Bot Server Only) - Lightweight
- ✅ Bot Server API (port 3001) - Only runs bots
- ✅ Bot build files (zoomsdk executable)
- ✅ Docker & Docker Compose
- ❌ No Database
- ❌ No Dashboard UI
- ❌ No API Server

## File Requirements

### Server 1 (Full Stack) - Needs ALL Files
```
meetingsdk-headless-linux-sample/
├── api/                    # API server code
├── dashboard/              # Dashboard UI
├── database/               # Database schema
├── bot-server/             # Bot server API
├── src/                    # C++ source code
├── build/                  # Bot build (zoomsdk executable)
├── lib/                    # Zoom SDK libraries
├── videos/                 # Video files
├── profile-pics/           # Name files
├── bin/                    # Entry scripts
├── docker-compose.dashboard.yml
├── docker-compose.bot-server.yml
├── docker-compose.full.yml
├── Dockerfile
├── Dockerfile.api
├── Dockerfile.bot-server
├── package.json
└── .env                    # All environment variables
```

### Server 2 (Bot Server Only) - Minimal Files
```
meetingsdk-headless-linux-sample/
├── bot-server/             # Bot server API only
├── build/                  # Bot build (zoomsdk executable) - REQUIRED
├── lib/                    # Zoom SDK libraries - REQUIRED
├── videos/                 # Video files - REQUIRED
├── profile-pics/           # Name files - REQUIRED
├── bin/                    # Entry scripts - REQUIRED
├── src/                    # C++ source (optional, if rebuilding)
├── compose-50-bots.yaml   # Bot compose template
├── config.toml            # Bot config
├── docker-compose.bot-server.yml
├── Dockerfile.bot-server
├── package.json            # For bot server API
└── .env                    # Minimal env vars (see below)
```

## Setup Instructions

### Step 1: Setup Server 1 (Main Server)

```bash
# 1. Clone/upload all files to Server 1
cd /opt/zoom-headless-meeting
git clone <repo-url> .  # or upload files

# 2. Create .env file
cp .env.example .env
nano .env

# Required in .env:
DB_HOST=db
DB_PORT=5432
DB_NAME=zoom_bots
DB_USER=postgres
DB_PASSWORD=your_password
ZOOM_ACCOUNT_ID=your_account_id
ZOOM_CLIENT_ID=your_client_id
ZOOM_CLIENT_SECRET=your_secret
PORT=3000
BOT_SERVER_PORT=3001

# 3. Build bot image (if not already built)
docker build -t zoom-bot:latest .

# 4. Start full stack
docker compose -f docker-compose.full.yml up -d

# 5. Initialize database
docker exec -it zoom-dashboard-db psql -U postgres -d zoom_bots -f /app/database/schema.sql

# 6. Register Server 1's bot server
curl -X POST http://localhost:3000/api/bot-servers \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "serverName": "server-1",
    "serverUrl": "http://SERVER1_IP:3001",
    "capacity": 100,
    "priority": 1
  }'
```

### Step 2: Setup Server 2 (Bot Server Only)

#### Option A: Copy Only Required Files

```bash
# On Server 1, create minimal package
cd /opt/zoom-headless-meeting
tar -czf bot-server-only.tar.gz \
  bot-server/ \
  build/ \
  lib/ \
  videos/ \
  profile-pics/ \
  bin/ \
  compose-50-bots.yaml \
  config.toml \
  docker-compose.bot-server.yml \
  Dockerfile.bot-server \
  package.json \
  .dockerignore

# Transfer to Server 2
scp bot-server-only.tar.gz user@server2:/opt/

# On Server 2
cd /opt
tar -xzf bot-server-only.tar.gz
cd zoom-headless-meeting  # or create this directory

# Create minimal .env
cat > .env << EOF
BOT_SERVER_PORT=3001
SERVER_CAPACITY=10
BOT_PROJECT_DIR=/app/bot-project
HOST_PROJECT_PATH=/opt/zoom-headless-meeting
EOF

# Build bot server image
docker compose -f docker-compose.bot-server.yml build

# Start bot server
docker compose -f docker-compose.bot-server.yml up -d

# Verify it's running
curl http://localhost:3001/health
```

#### Option B: Git Clone (if using Git)

```bash
# On Server 2
cd /opt
git clone <repo-url> zoom-headless-meeting
cd zoom-headless-meeting

# Copy bot build from Server 1 (if not building locally)
# Option 1: Build locally
docker build -t zoom-bot:latest .

# Option 2: Copy build directory from Server 1
scp -r user@server1:/opt/zoom-headless-meeting/build ./build
scp -r user@server1:/opt/zoom-headless-meeting/lib ./lib

# Create minimal .env
cat > .env << EOF
BOT_SERVER_PORT=3001
SERVER_CAPACITY=10
BOT_PROJECT_DIR=/app/bot-project
HOST_PROJECT_PATH=/opt/zoom-headless-meeting
EOF

# Start bot server
docker compose -f docker-compose.bot-server.yml up -d
```

### Step 3: Register Server 2

```bash
# On Server 1 (or any machine with API access)
curl -X POST http://SERVER1_IP:3000/api/bot-servers \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "serverName": "server-2",
    "serverUrl": "http://SERVER2_IP:3001",
    "capacity": 10,
    "priority": 2
  }'
```

## Environment Variables

### Server 1 (.env) - Full Stack
```env
# Database
DB_HOST=db
DB_PORT=5432
DB_NAME=zoom_bots
DB_USER=postgres
DB_PASSWORD=your_password

# API Server
PORT=3000
NODE_ENV=production

# Bot Server (on same server)
BOT_SERVER_PORT=3001
SERVER_CAPACITY=100

# Zoom API
ZOOM_ACCOUNT_ID=your_account_id
ZOOM_CLIENT_ID=your_client_id
ZOOM_CLIENT_SECRET=your_secret

# Paths
HOST_PROJECT_PATH=/opt/zoom-headless-meeting
```

### Server 2 (.env) - Bot Server Only
```env
# Bot Server
BOT_SERVER_PORT=3001
SERVER_CAPACITY=10
BOT_PROJECT_DIR=/app/bot-project
HOST_PROJECT_PATH=/opt/zoom-headless-meeting

# No database, API, or Zoom credentials needed!
# Bot server receives credentials from API server
```

## How It Works

1. **User creates meeting** → Dashboard on Server 1
2. **API Server** (Server 1) selects best server:
   - Checks Server 1 capacity first (priority=1)
   - If full, uses Server 2 (priority=2)
3. **API Server calls Bot Server**:
   - `POST http://SERVER1_IP:3001/api/bots/create` (Server 1)
   - `POST http://SERVER2_IP:3001/api/bots/create` (Server 2)
4. **Bot Server creates Docker containers**:
   - Uses `zoom-bot:latest` image
   - Runs bots with provided credentials
5. **Load tracking**:
   - API Server updates `current_load` in database
   - Only Server 1 has database access

## Verification

### Check Server 1
```bash
# API Server
curl http://SERVER1_IP:3000/health

# Bot Server
curl http://SERVER1_IP:3001/health

# Dashboard
curl http://SERVER1_IP:8080
```

### Check Server 2
```bash
# Bot Server only
curl http://SERVER2_IP:3001/health

# Capacity
curl http://SERVER2_IP:3001/api/bots/capacity
```

### Check Load Balancing
```bash
# List all servers
curl http://SERVER1_IP:3000/api/bot-servers \
  -H "Authorization: Bearer YOUR_TOKEN"
```

## Kubernetes Alternative

Yes! Kubernetes is a better option for production. Here's why:

### Benefits:
- ✅ Automatic load balancing
- ✅ Auto-scaling (add/remove pods based on load)
- ✅ Health checks and auto-restart
- ✅ Rolling updates
- ✅ Better resource management
- ✅ Service discovery

### Kubernetes Architecture:

```yaml
# api-deployment.yaml - Server 1 only
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api-server
  template:
    metadata:
      labels:
        app: api-server
    spec:
      containers:
      - name: api
        image: zoom-api:latest
        ports:
        - containerPort: 3000
        env:
        - name: DB_HOST
          value: postgres-service
        - name: PORT
          value: "3000"

---
# bot-server-deployment.yaml - Can run on multiple nodes
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bot-server
spec:
  replicas: 2  # Can scale up
  selector:
    matchLabels:
      app: bot-server
  template:
    metadata:
      labels:
        app: bot-server
    spec:
      containers:
      - name: bot-server
        image: zoom-bot-server:latest
        ports:
        - containerPort: 3001
        volumeMounts:
        - name: docker-sock
          mountPath: /var/run/docker.sock
      volumes:
      - name: docker-sock
        hostPath:
          path: /var/run/docker.sock
```

### Kubernetes Setup (Optional)

See `k8s/` directory for Kubernetes manifests:
- `api-deployment.yaml` - API server deployment
- `bot-server-deployment.yaml` - Bot server deployment
- `postgres-deployment.yaml` - Database
- `services.yaml` - Service definitions

## Troubleshooting

### Server 2 can't create bots
- Check: `build/zoomsdk` exists and is executable
- Check: `lib/zoomsdk/` directory exists
- Check: Docker socket mounted: `/var/run/docker.sock`
- Check: `zoom-bot:latest` image exists: `docker images zoom-bot`

### Server 2 not receiving requests
- Verify Server 2 is registered in database
- Check Server 2 URL is accessible from Server 1
- Check firewall allows port 3001
- Verify priority: Server 1 = 1, Server 2 = 2

### Bot build missing on Server 2
```bash
# Option 1: Build on Server 2
docker build -t zoom-bot:latest .

# Option 2: Copy from Server 1
scp -r user@server1:/opt/zoom-headless-meeting/build ./build
scp -r user@server1:/opt/zoom-headless-meeting/lib ./lib
```

## Summary

- **Server 1**: Full stack (DB + API + UI + Bots) - All files needed
- **Server 2**: Bot server only - Minimal files (bot-server/, build/, lib/, videos/, etc.)
- **Load Balancing**: Automatic via priority system
- **Kubernetes**: Better option for production scaling

