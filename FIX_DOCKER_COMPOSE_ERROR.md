FIX DOCKER COMPOSE CONTAINERCONFIG ERROR
=========================================

PROBLEM:
--------
- Old image was removed
- Docker Compose trying to recreate container with old image
- KeyError: 'ContainerConfig' - Docker Compose can't inspect old container

SOLUTION:
---------
Stop and remove old container first, then rebuild:

SERVER PAR YEH COMMANDS RUN KAREIN:
------------------------------------

```bash
# 1. Stop and remove old container
docker-compose -f docker-compose.full.yml stop bot-server
docker-compose -f docker-compose.full.yml rm -f bot-server

# 2. Pull latest code
cd /path/to/meetingsdk-headless-linux-sample
git pull origin main

# 3. Rebuild bot server image
docker-compose -f docker-compose.full.yml build --no-cache bot-server

# 4. Start bot server with new image
docker-compose -f docker-compose.full.yml up -d bot-server

# 5. Verify it's running
docker-compose -f docker-compose.full.yml ps bot-server
docker-compose -f docker-compose.full.yml logs bot-server | tail -20
```

ALTERNATIVE (If above doesn't work):
-------------------------------------

```bash
# 1. Force remove container
docker rm -f zoom-bot-server-api

# 2. Remove old image (if exists)
docker rmi meetingsdk-headless-linux-sample_bot-server 2>/dev/null || true

# 3. Pull latest code
cd /path/to/meetingsdk-headless-linux-sample
git pull origin main

# 4. Rebuild
docker-compose -f docker-compose.full.yml build --no-cache bot-server

# 5. Start
docker-compose -f docker-compose.full.yml up -d bot-server
```

VERIFY:
-------
```bash
# Check container is running
docker ps | grep bot-server

# Check logs for new code
docker-compose -f docker-compose.full.yml logs bot-server | grep -i "Expected\|Request ID"
```

Should see:
- "📋 Expected compose file: compose-{meetingId}-{requestId}-bots.yaml" ✅

