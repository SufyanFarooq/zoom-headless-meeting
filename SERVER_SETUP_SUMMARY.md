# Server Setup Summary - 3 Approaches

## Question: Do we need same code on both servers?

**Answer: NO!** Different servers need different files:

### Server 1 (Main Server) - Full Stack
- ✅ **ALL files** needed
- Database, API, Dashboard, Bot Server

### Server 2 (Bot Server Only) - Minimal
- ✅ **Only bot-related files** needed
- No database, no API, no dashboard

---

## Approach 1: Docker Compose (Current Setup) ✅

### Server 1 Setup
```bash
# All files needed
git clone <repo> /opt/zoom-headless-meeting
cd /opt/zoom-headless-meeting

# Create .env with all configs
cp .env.example .env

# Start full stack
docker compose -f docker-compose.full.yml up -d
```

**Files needed:**
- ✅ All project files
- ✅ Database schema
- ✅ API server code
- ✅ Dashboard UI
- ✅ Bot server code
- ✅ Bot build (build/, lib/)

### Server 2 Setup
```bash
# Only minimal files needed
# Option 1: Use prepared package
scp bot-server-only.tar.gz user@server2:/opt/
cd /opt && tar -xzf bot-server-only.tar.gz
cd zoom-headless-meeting

# Option 2: Manual copy
# Copy only: bot-server/, build/, lib/, videos/, profile-pics/, bin/

# Create minimal .env
cat > .env << EOF
BOT_SERVER_PORT=3001
SERVER_CAPACITY=10
BOT_PROJECT_DIR=/app/bot-project
HOST_PROJECT_PATH=/opt/zoom-headless-meeting
EOF

# Start bot server only
docker compose -f docker-compose.bot-server.yml up -d
```

**Files needed:**
- ✅ bot-server/ (API only)
- ✅ build/ (bot executable)
- ✅ lib/ (Zoom SDK)
- ✅ videos/, profile-pics/, bin/
- ✅ docker-compose.bot-server.yml
- ✅ Dockerfile.bot-server
- ❌ No database
- ❌ No API server
- ❌ No dashboard

### Create Bot Server Package
```bash
# On Server 1, create minimal package
./scripts/prepare-bot-server-package.sh

# This creates: bot-server-only.tar.gz
# Transfer to Server 2 and extract
```

### Register Servers
```bash
# Server 1 (auto-registered or manual)
curl -X POST http://SERVER1_IP:3000/api/bot-servers \
  -H "Content-Type: application/json" \
  -d '{
    "serverName": "server-1",
    "serverUrl": "http://SERVER1_IP:3001",
    "capacity": 100,
    "priority": 1
  }'

# Server 2
curl -X POST http://SERVER1_IP:3000/api/bot-servers \
  -H "Content-Type: application/json" \
  -d '{
    "serverName": "server-2",
    "serverUrl": "http://SERVER2_IP:3001",
    "capacity": 10,
    "priority": 2
  }'
```

**Pros:**
- ✅ Simple setup
- ✅ Works with existing code
- ✅ Easy to understand
- ✅ Server 2 needs minimal files

**Cons:**
- ❌ Manual scaling
- ❌ Manual load balancing
- ❌ No auto-healing

---

## Approach 2: Kubernetes (Recommended for Production) 🚀

### Architecture
```
Kubernetes Cluster:
├── API Server (1 pod) - Server 1 only
├── PostgreSQL (1 pod) - Server 1 only  
├── Bot Server (auto-scaled pods) - Can run on any node
└── Bot Pods (auto-scaled) - Distributed across nodes
```

### Setup
```bash
# 1. Build and push images
docker build -t your-registry/zoom-api:latest -f Dockerfile.api .
docker build -t your-registry/zoom-bot-server:latest -f Dockerfile.bot-server .
docker build -t your-registry/zoom-bot:latest -f Dockerfile .
docker push your-registry/zoom-api:latest
docker push your-registry/zoom-bot-server:latest
docker push your-registry/zoom-bot:latest

# 2. Deploy to Kubernetes
kubectl apply -f k8s/zoom-bot-deployment.yaml
kubectl apply -f k8s/zoom-bot-hpa.yaml

# 3. Auto-scaling configured!
# Bot servers scale automatically based on load
```

### Features
- ✅ **Auto-scaling**: HPA scales bot servers 2-10 pods based on CPU/Memory
- ✅ **Auto-load-balancing**: Kubernetes Service handles load balancing
- ✅ **Multi-node**: Pods run across multiple servers automatically
- ✅ **Health checks**: Auto-restart failed pods
- ✅ **Rolling updates**: Zero-downtime deployments

### Files Needed
- **All nodes**: Kubernetes manifests (k8s/*.yaml)
- **Registry**: Docker images pushed to registry
- **No manual file copying needed!**

**Pros:**
- ✅ Best for production
- ✅ Automatic scaling
- ✅ Multi-node support
- ✅ Self-healing
- ✅ No manual file management

**Cons:**
- ❌ Requires Kubernetes cluster
- ❌ More complex setup
- ❌ Learning curve

**See:** `KUBERNETES_SETUP.md` for full guide

---

## Approach 3: Hybrid (Docker Compose + Kubernetes)

- Server 1: Docker Compose (full stack)
- Server 2+: Kubernetes (bot servers only)

This gives you:
- Simple setup on Server 1
- Auto-scaling on Server 2+

---

## Comparison

| Feature | Docker Compose | Kubernetes |
|---------|---------------|------------|
| **Setup Complexity** | Simple | Medium |
| **File Management** | Manual copy | Automatic |
| **Scaling** | Manual | Automatic |
| **Load Balancing** | Priority-based | Built-in |
| **Multi-Node** | Manual | Automatic |
| **Best For** | Small/Medium | Production |

---

## Recommendation

### For Now (Quick Setup):
**Use Docker Compose:**
1. Server 1: Full stack (all files)
2. Server 2: Bot server only (minimal files)
3. Use `prepare-bot-server-package.sh` to create minimal package

### For Production (Long-term):
**Use Kubernetes:**
1. Better scalability
2. Auto-scaling
3. Multi-node support
4. Production-ready

---

## Quick Start Commands

### Docker Compose (Current)
```bash
# Server 1
cd /opt/zoom-headless-meeting
docker compose -f docker-compose.full.yml up -d

# Server 2 (minimal files)
cd /opt/zoom-headless-meeting
docker compose -f docker-compose.bot-server.yml up -d
```

### Kubernetes (Future)
```bash
kubectl apply -f k8s/
# That's it! Auto-scaling configured
```

---

## Summary

**Question:** Same code on both servers?
**Answer:** NO!
- Server 1: All files (DB + API + UI + Bots)
- Server 2: Minimal files (Bot server only)

**Best Approach:**
- **Now**: Docker Compose (simple)
- **Production**: Kubernetes (scalable)

See detailed guides:
- `MULTI_SERVER_SETUP.md` - Docker Compose setup
- `KUBERNETES_SETUP.md` - Kubernetes setup
- `LOAD_BALANCING_SETUP.md` - Load balancing details

