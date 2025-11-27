# Load Balancing Setup Guide

## Overview

This system implements load balancing between two servers:
- **Server 1 (Primary)**: 32 vCPUs, 128GB Memory - Used first
- **Server 2 (Secondary)**: 4 vCPUs, 16GB Memory - Used when Server 1 is full

## How It Works

1. **Priority-based Selection**: Server 1 has priority=1, Server 2 has priority=2
2. **Automatic Fallback**: When creating bots, the system:
   - First checks Server 1 for available capacity
   - If Server 1 is full, automatically uses Server 2
   - Only fails if both servers are full

## Setup Steps

### Step 1: Update Database Schema

Add the `priority` column to the `bot_servers` table:

```bash
# Option 1: Using psql
psql -h localhost -U postgres -d zoom_bots -f scripts/migrate-add-priority.sql

# Option 2: Run SQL directly
psql -h localhost -U postgres -d zoom_bots
```

Then run:
```sql
ALTER TABLE bot_servers ADD COLUMN IF NOT EXISTS priority INTEGER DEFAULT 100;
```

### Step 2: Register Both Servers

#### Option A: Using Setup Script (Recommended)

```bash
cd /path/to/meetingsdk-headless-linux-sample
chmod +x scripts/setup-load-balancing.sh
./scripts/setup-load-balancing.sh
```

The script will:
1. Update database schema
2. Ask for Server 1 and Server 2 URLs
3. Register both servers with proper priorities
4. Verify the setup

#### Option B: Manual Registration via API

```bash
# Register Server 1 (Primary)
curl -X POST http://localhost:3000/api/bot-servers \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "serverName": "server-1",
    "serverUrl": "http://server1-ip:3001",
    "capacity": 100,
    "priority": 1
  }'

# Register Server 2 (Secondary)
curl -X POST http://localhost:3000/api/bot-servers \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "serverName": "server-2",
    "serverUrl": "http://server2-ip:3001",
    "capacity": 10,
    "priority": 2
  }'
```

### Step 3: Verify Setup

Check registered servers:

```bash
curl -X GET http://localhost:3000/api/bot-servers \
  -H "Authorization: Bearer YOUR_TOKEN"
```

Expected output:
```json
{
  "success": true,
  "servers": [
    {
      "id": 1,
      "server_name": "server-1",
      "server_url": "http://server1-ip:3001",
      "capacity": 100,
      "current_load": 0,
      "priority": 1,
      "status": "active"
    },
    {
      "id": 2,
      "server_name": "server-2",
      "server_url": "http://server2-ip:3001",
      "capacity": 10,
      "current_load": 0,
      "priority": 2,
      "status": "active"
    }
  ]
}
```

## Capacity Calculation

Based on Docker resource limits per bot:
- **CPU**: 0.3 cores per bot
- **Memory**: 256MB per bot

### Server 1 (32 vCPUs, 128GB)
- CPU limit: 32 / 0.3 = ~106 bots
- Memory limit: 128GB / 256MB = ~512 bots
- **Recommended capacity**: 100 bots (CPU-limited, conservative)

### Server 2 (4 vCPUs, 16GB)
- CPU limit: 4 / 0.3 = ~13 bots
- Memory limit: 16GB / 256MB = ~64 bots
- **Recommended capacity**: 10 bots (CPU-limited, conservative)

## Testing Load Balancing

1. **Create bots that fit in Server 1**:
   ```bash
   # This should use Server 1
   curl -X POST http://localhost:3000/api/meetings \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer YOUR_TOKEN" \
     -d '{
       "meetingId": "123456789",
       "password": "test123",
       "membersCount": 50,
       "videoCount": 25,
       "audioCount": 25,
       "nameType": "Indian",
       "meetingType": "Normal Member"
     }'
   ```

2. **Fill Server 1** (create 100+ bots):
   - Server 1 will be used until capacity is reached

3. **Create more bots**:
   - When Server 1 is full, new requests will automatically use Server 2

## Monitoring

Check server status and load:

```bash
curl http://localhost:3000/api/bot-servers \
  -H "Authorization: Bearer YOUR_TOKEN"
```

Check individual server capacity:

```bash
# Server 1 capacity
curl http://server1-ip:3001/api/bots/capacity

# Server 2 capacity
curl http://server2-ip:3001/api/bots/capacity
```

## Troubleshooting

### Server 1 not being used first
- Check priority values: Server 1 should have priority=1
- Verify Server 1 has available capacity: `capacity - current_load >= required_bots`

### Server 2 not being used when Server 1 is full
- Check Server 2 status is 'active'
- Verify Server 2 has available capacity
- Check logs: `api/services/botService.js` logs server selection

### Database errors
- Ensure priority column exists: `\d bot_servers` in psql
- Run migration script if needed: `scripts/migrate-add-priority.sql`

## Code Changes

### Modified Files:
1. `database/schema.sql` - Added `priority` column
2. `api/services/botService.js` - Updated `selectBestServer()` to prioritize Server 1
3. `api/routes/bot-servers.js` - Added priority support in registration

### Key Logic:
```javascript
// In api/services/botService.js
// 1. Try Server 1 (priority=1) first
// 2. If Server 1 is full, try Server 2 (priority=2)
// 3. Fail only if both are full
```

## Notes

- Server priorities are: Lower number = Higher priority
- Server 1 (priority=1) is always checked first
- Server 2 (priority=2) is used as fallback
- Load is tracked per server in `current_load` field
- Capacity is checked before assigning bots to a server

