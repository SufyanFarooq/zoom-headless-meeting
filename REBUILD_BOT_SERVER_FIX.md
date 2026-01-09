REBUILD BOT SERVER - FIX SCHEDULED MEETINGS
============================================

PROBLEM:
--------
Bot server old code use kar raha hai kyunki:
- Dockerfile.bot-server code ko image mein COPY karta hai
- CMD: `node bot-server/api.js` copied code use karta hai
- Volume mount (`.:/app/bot-project`) alag path par hai
- So volume mount copied code ko override nahi karta

SOLUTION:
---------
Image rebuild karna hoga!

SERVER PAR YEH COMMANDS RUN KAREIN:
------------------------------------

```bash
# 1. Pull latest code
cd /path/to/meetingsdk-headless-linux-sample
git pull origin main

# 2. REBUILD BOT SERVER IMAGE (important!)
docker-compose -f docker-compose.full.yml build --no-cache bot-server

# 3. Restart bot server with new image
docker-compose -f docker-compose.full.yml up -d bot-server

# 4. Verify new code is running
docker-compose -f docker-compose.full.yml logs bot-server | tail -20
```

VERIFY:
-------
Logs mein yeh dikhna chahiye:
- "📋 Expected compose file: compose-{meetingId}-{requestId}-bots.yaml" ✅
- "📋 Request ID: {requestId}" ✅
- "Command to execute: docker-compose -f \"/app/bot-project/compose-{meetingId}-{requestId}-bots.yaml\"" ✅

NOT OLD FORMAT:
- ❌ "📋 Using compose file: /app/bot-project/compose-87603104813-bots.yaml"
- ❌ "docker-compose -f compose-87603104813-bots.yaml"

TEST:
-----
1. Ek naya scheduled meeting create karein
2. Scheduled time par check karein:
```bash
docker-compose -f docker-compose.full.yml logs bot-server | grep -i "Expected\|Request ID\|Command to execute"
```

ALTERNATIVE (If rebuild takes too long):
-----------------------------------------
Agar rebuild time zyada le raha hai, to container ke andar directly file update kar sakte hain:

```bash
# Copy updated file into running container
docker cp bot-server/api.js zoom-bot-server-api:/app/bot-server/api.js

# Restart container
docker-compose -f docker-compose.full.yml restart bot-server
```

But rebuild is better long-term solution!

