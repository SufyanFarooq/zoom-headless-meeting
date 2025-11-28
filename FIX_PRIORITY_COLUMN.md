# Fix Priority Column - Quick Guide

## Problem
`priority` column database me nahi hai, isliye Server 2 register nahi ho raha.

## Solution: Add Priority Column

### Method 1: Using SQL File (Easiest)

```bash
# Server 1 par
docker exec -i zoom-dashboard-db psql -U postgres -d zoom_bots < scripts/add-priority-column.sql
```

### Method 2: Manual SQL Commands

```bash
# Database me connect karein
docker exec -it zoom-dashboard-db psql -U postgres -d zoom_bots

# Priority column add karein
ALTER TABLE bot_servers ADD COLUMN IF NOT EXISTS priority INTEGER DEFAULT 100;

# Server 1 ko priority 1 dein
UPDATE bot_servers SET priority = 1 WHERE server_name = 'server-1';

# Verify
SELECT id, server_name, server_url, capacity, current_load, priority, status 
FROM bot_servers;

# Ab Server 2 register karein (priority column ke saath)
INSERT INTO bot_servers (server_name, server_url, capacity, priority, status)
VALUES ('server-2', 'http://35.227.36.166:3001', 10, 2, 'active')
ON CONFLICT (server_name) 
DO UPDATE SET 
  server_url = EXCLUDED.server_url,
  capacity = EXCLUDED.capacity,
  priority = EXCLUDED.priority,
  status = 'active';

# Verify both servers
SELECT * FROM bot_servers ORDER BY priority;
\q
```

## Complete Steps

### Step 1: Add Priority Column

```sql
ALTER TABLE bot_servers ADD COLUMN IF NOT EXISTS priority INTEGER DEFAULT 100;
```

### Step 2: Set Server 1 Priority

```sql
UPDATE bot_servers SET priority = 1 WHERE server_name = 'server-1';
```

### Step 3: Register Server 2

```sql
INSERT INTO bot_servers (server_name, server_url, capacity, priority, status)
VALUES ('server-2', 'http://35.227.36.166:3001', 10, 2, 'active')
ON CONFLICT (server_name) 
DO UPDATE SET 
  server_url = EXCLUDED.server_url,
  capacity = EXCLUDED.capacity,
  priority = EXCLUDED.priority,
  status = 'active';
```

### Step 4: Verify

```sql
SELECT id, server_name, server_url, capacity, current_load, priority, status 
FROM bot_servers 
ORDER BY priority;
```

Expected output:
```
 id | server_name |       server_url       | capacity | current_load | priority | status 
----+-------------+------------------------+----------+--------------+----------+--------
  1 | server-1    | http://bot-server:3001 |      500 |            0 |        1 | active
  2 | server-2    | http://35.227.36.166:3001 |       10 |            0 |        2 | active
```

## Quick Copy-Paste Commands

```bash
# Database me connect
docker exec -it zoom-dashboard-db psql -U postgres -d zoom_bots

# Copy-paste ye sab:
ALTER TABLE bot_servers ADD COLUMN IF NOT EXISTS priority INTEGER DEFAULT 100;
UPDATE bot_servers SET priority = 1 WHERE server_name = 'server-1';
INSERT INTO bot_servers (server_name, server_url, capacity, priority, status)
VALUES ('server-2', 'http://35.227.36.166:3001', 10, 2, 'active')
ON CONFLICT (server_name) 
DO UPDATE SET 
  server_url = EXCLUDED.server_url,
  capacity = EXCLUDED.capacity,
  priority = EXCLUDED.priority,
  status = 'active';
SELECT * FROM bot_servers ORDER BY priority;
\q
```

