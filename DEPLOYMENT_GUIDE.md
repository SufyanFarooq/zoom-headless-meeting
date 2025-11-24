# Server Deployment Guide

Complete guide for deploying the Zoom Bot Dashboard with APIs and scheduler to production server.

## Prerequisites

1. **Server Requirements:**
   - Linux server (Ubuntu/Debian recommended)
   - Docker & Docker Compose installed
   - At least 4GB RAM, 20GB disk space
   - Ports 80, 3000, 3001, 5432 available

2. **Required Files:**
   - All project files (API, Dashboard, Database, Docker configs)
   - `.env` file with credentials
   - Docker images or build context

## Deployment Methods

### Method 1: Git-based Deployment (Recommended)

```bash
# On server
cd /opt/zoom-bot-dashboard
git pull origin main

# Rebuild and restart
docker compose -f docker-compose.full.yml down
docker compose -f docker-compose.full.yml up -d --build

# Check status
docker compose -f docker-compose.full.yml ps
docker compose -f docker-compose.full.yml logs -f
```

### Method 2: Manual File Transfer

#### Step 1: Prepare Files on Local Machine

```bash
# Create deployment package
tar -czf zoom-bot-dashboard.tar.gz \
  api/ \
  dashboard/ \
  database/ \
  bot-server/ \
  docker-compose.full.yml \
  docker-compose.dashboard.yml \
  docker-compose.bot-server.yml \
  Dockerfile.api \
  Dockerfile.bot-server \
  .dockerignore \
  .env.example \
  package.json \
  nginx.conf \
  start.sh
```

#### Step 2: Transfer to Server

```bash
# Using SCP
scp zoom-bot-dashboard.tar.gz user@server-ip:/opt/

# Or using SFTP/FileZilla
# Upload to /opt/ directory
```

#### Step 3: Extract and Setup on Server

```bash
# SSH into server
ssh user@server-ip

# Extract files
cd /opt
tar -xzf zoom-bot-dashboard.tar.gz
cd zoom-bot-dashboard

# Create .env file
cp .env.example .env
nano .env  # Edit with your credentials
```

#### Step 4: Configure .env File

```env
# Database
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your_secure_password
POSTGRES_DB=zoom_bots
DATABASE_URL=postgresql://postgres:your_secure_password@db:5432/zoom_bots

# Zoom API Credentials
ZOOM_ACCOUNT_ID=your_account_id
ZOOM_CLIENT_ID=your_client_id
ZOOM_CLIENT_SECRET=your_client_secret

# Bot Server (if separate)
HOST_PROJECT_PATH=/opt/zoom-bot-dashboard

# API Port
PORT=3000
```

#### Step 5: Initialize Database

```bash
# Start only database first
docker compose -f docker-compose.full.yml up -d db

# Wait for database to be ready
sleep 10

# Initialize schema
docker exec -i zoom-dashboard-db psql -U postgres -d zoom_bots < database/schema.sql

# Verify
docker exec zoom-dashboard-db psql -U postgres -d zoom_bots -c "\dt"
```

#### Step 6: Build and Start Services

```bash
# Build and start all services
docker compose -f docker-compose.full.yml up -d --build

# Check status
docker compose -f docker-compose.full.yml ps

# View logs
docker compose -f docker-compose.full.yml logs -f
```

#### Step 7: Register Bot Server

```bash
# Register bot server in database
curl -X POST http://localhost:3000/api/bot-servers \
  -H "Content-Type: application/json" \
  -d '{
    "serverName": "server-1",
    "serverUrl": "http://localhost:3001",
    "capacity": 100
  }'
```

#### Step 8: Verify Deployment

```bash
# Check API health
curl http://localhost:3000/health

# Check dashboard
curl http://localhost:8080

# Check scheduler
docker logs zoom-dashboard-api | grep "Starting scheduler"

# Check database
docker exec zoom-dashboard-db psql -U postgres -d zoom_bots -c "SELECT COUNT(*) FROM scheduled_tasks;"
```

## Service Management

### Start Services
```bash
docker compose -f docker-compose.full.yml up -d
```

### Stop Services
```bash
docker compose -f docker-compose.full.yml down
```

### Restart Services
```bash
docker compose -f docker-compose.full.yml restart
```

### View Logs
```bash
# All services
docker compose -f docker-compose.full.yml logs -f

# Specific service
docker compose -f docker-compose.full.yml logs -f api
docker compose -f docker-compose.full.yml logs -f bot-server
```

### Update Code
```bash
# Pull latest code
git pull

# Rebuild and restart
docker compose -f docker-compose.full.yml up -d --build

# Or restart specific service
docker compose -f docker-compose.full.yml up -d --build api
```

## Database Management

### Backup Database
```bash
docker exec zoom-dashboard-db pg_dump -U postgres zoom_bots > backup_$(date +%Y%m%d).sql
```

### Restore Database
```bash
docker exec -i zoom-dashboard-db psql -U postgres zoom_bots < backup_20251124.sql
```

### Access Database
```bash
docker exec -it zoom-dashboard-db psql -U postgres -d zoom_bots
```

## Troubleshooting

### Check Service Status
```bash
docker compose -f docker-compose.full.yml ps
docker ps -a
```

### Check Logs for Errors
```bash
docker compose -f docker-compose.full.yml logs | grep -i error
docker logs zoom-dashboard-api | tail -50
```

### Restart Failed Service
```bash
docker compose -f docker-compose.full.yml restart api
docker compose -f docker-compose.full.yml restart bot-server
```

### Check Ports
```bash
netstat -tulpn | grep -E '3000|3001|5432|8080'
```

### Check Disk Space
```bash
df -h
docker system df
```

### Clean Docker Resources
```bash
docker system prune -a --volumes
```

## Production Checklist

- [ ] `.env` file configured with secure credentials
- [ ] Database schema initialized
- [ ] Bot server registered in database
- [ ] All services running (`docker compose ps`)
- [ ] API health check passing (`/health`)
- [ ] Dashboard accessible
- [ ] Scheduler running (check logs)
- [ ] Firewall rules configured
- [ ] SSL/HTTPS configured (if needed)
- [ ] Backup strategy in place

## Multi-Server Setup

If bot server is on separate machine:

1. **On API Server:**
   - Deploy API, Dashboard, Database
   - Update `.env` with database credentials

2. **On Bot Server:**
   - Deploy bot-server code
   - Update `docker-compose.bot-server.yml`
   - Start bot server API

3. **Register Bot Server:**
   ```bash
   # From API server
   curl -X POST http://api-server:3000/api/bot-servers \
     -H "Content-Type: application/json" \
     -d '{
       "serverName": "bot-server-1",
       "serverUrl": "http://bot-server-ip:3001",
       "capacity": 100
     }'
   ```

## Monitoring

### Check Scheduler
```bash
docker logs zoom-dashboard-api | grep -E "Scheduler|Executing scheduled"
```

### Check Bot Creation
```bash
docker logs zoom-dashboard-api | grep -E "createBots|videoCount|audioCount"
```

### Check Database Queries
```bash
docker logs zoom-dashboard-api | grep "Executed query"
```

## Updates

When updating code:

1. **Backup database** (important!)
2. Pull/transfer new code
3. Rebuild containers: `docker compose -f docker-compose.full.yml up -d --build`
4. Check logs for errors
5. Verify scheduler is running
6. Test creating a meeting

## Support

For issues:
1. Check logs: `docker compose -f docker-compose.full.yml logs`
2. Check service status: `docker compose -f docker-compose.full.yml ps`
3. Verify `.env` configuration
4. Check database connectivity
5. Verify bot server registration

