FIX BOT SERVER REBUILD ERROR
=============================

SAME ERROR - ContainerConfig issue
----------------------------------

SOLUTION - Step by step:
------------------------

```bash
# 1. Stop and remove old container (IMPORTANT!)
docker-compose -f docker-compose.full.yml stop bot-server
docker-compose -f docker-compose.full.yml rm -f bot-server

# 2. Force remove if still exists
docker rm -f zoom-bot-server-api 2>/dev/null || true

# 3. Pull latest code
cd /path/to/meetingsdk-headless-linux-sample
git pull origin main

# 4. Rebuild bot server image
docker-compose -f docker-compose.full.yml build --no-cache bot-server

# 5. Start bot server
docker-compose -f docker-compose.full.yml up -d bot-server

# 6. Verify
docker-compose -f docker-compose.full.yml ps bot-server
docker-compose -f docker-compose.full.yml logs bot-server | tail -20
```

ALTERNATIVE - All in one command:
----------------------------------

```bash
cd /path/to/meetingsdk-headless-linux-sample && \
docker rm -f zoom-bot-server-api 2>/dev/null; \
git pull origin main && \
docker-compose -f docker-compose.full.yml build --no-cache bot-server && \
docker-compose -f docker-compose.full.yml up -d bot-server
```

VERIFY FIXES:
-------------

After restart, test scheduled meeting:
- videoCount: 0, audioCount: 10 → Should create exactly 10 bots
- container_ids array should have NO duplicates

Check logs:
```bash
docker-compose -f docker-compose.full.yml logs bot-server | grep -i "container\|video\|audio"
```

