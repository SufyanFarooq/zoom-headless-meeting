# Docker Setup Guide

## Architecture

- **Dashboard Stack**: PostgreSQL + API Server + Dashboard UI
- **Bot Server**: Separate service for managing bots
- **Full Stack**: All services in one compose file

## Quick Start

### Option 1: Full Stack (Single Server)

```bash
# 1. Create .env file
cp .env.example .env
# Edit .env with your credentials

# 2. Start all services
docker compose -f docker-compose.full.yml up -d

# 3. Access dashboard
# http://localhost:8080
```

### Option 2: Separate Servers

**On Dashboard Server:**
```bash
docker compose -f docker-compose.dashboard.yml up -d
```

**On Bot Server(s):**
```bash
docker compose -f docker-compose.bot-server.yml up -d
```

## Environment Variables

Create `.env` file:

```env
# Database
DB_NAME=zoom_bots
DB_USER=postgres
DB_PASSWORD=your_password
DB_PORT=5432

# API Server
API_PORT=3000
DASHBOARD_PORT=8080

# Bot Server
BOT_SERVER_PORT=3001
SERVER_CAPACITY=100

# Zoom API
ZOOM_ACCOUNT_ID=your_account_id
ZOOM_CLIENT_ID=your_client_id
ZOOM_CLIENT_SECRET=your_client_secret
```

## Register Bot Server

After starting bot server, register it in database:

```bash
# Connect to database
docker exec -it zoom-dashboard-db psql -U postgres -d zoom_bots

# Register bot server
INSERT INTO bot_servers (server_name, server_url, capacity) 
VALUES ('server-1', 'http://bot-server-ip:3001', 100);
```

## Services

- **Dashboard UI**: http://localhost:8080
- **API Server**: http://localhost:3000
- **Bot Server API**: http://localhost:3001
- **PostgreSQL**: localhost:5432

## Volumes

- `postgres_data`: Database persistence
- `./dashboard`: Dashboard UI files
- `./profile-pics`: Names files (read-only)
- `/var/run/docker.sock`: Docker socket for bot management

## Scaling

To add more bot servers:

1. Deploy `docker-compose.bot-server.yml` on new server
2. Register server in database:
   ```sql
   INSERT INTO bot_servers (server_name, server_url, capacity) 
   VALUES ('server-2', 'http://new-server-ip:3001', 100);
   ```

## Troubleshooting

**Database not connecting:**
```bash
docker logs zoom-dashboard-api
```

**Bot server not responding:**
```bash
docker logs zoom-bot-server-api
```

**Check service status:**
```bash
docker compose -f docker-compose.full.yml ps
```

