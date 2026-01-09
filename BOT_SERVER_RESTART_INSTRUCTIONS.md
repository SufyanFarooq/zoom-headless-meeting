BOT SERVER RESTART INSTRUCTIONS
================================

ISSUE:
------
Logs show old code is running:
- Old log: "📋 Using compose file: /app/bot-project/compose-87603104813-bots.yaml"
- Old log: "📋 Meeting ID: 87603104813 - Containers: zoom-bot-87603104813-1"

New code should show:
- "📋 Expected compose file: compose-87603104813-{requestId}-bots.yaml"
- "📋 Meeting ID: 87603104813, Request ID: {requestId}"

SOLUTION:
---------

1. PULL LATEST CODE:
```bash
cd /path/to/meetingsdk-headless-linux-sample
git pull origin main
```

2. RESTART BOT SERVER:
```bash
docker-compose -f docker-compose.full.yml restart bot-server
```

3. VERIFY RESTART:
```bash
docker-compose -f docker-compose.full.yml logs bot-server | tail -20
```

Should see:
- "Bot server listening on port 3001"
- No old error messages

4. TEST SCHEDULED MEETING:
- Create a new scheduled meeting
- Wait for scheduled time
- Check logs:
```bash
docker-compose -f docker-compose.full.yml logs bot-server | grep -i "compose\|request\|Expected"
```

Should see:
- "📋 Expected compose file: compose-{meetingId}-{requestId}-bots.yaml" ✅
- "📋 Request ID: {requestId}" ✅
- "Command to execute: docker-compose -f \"/app/bot-project/compose-{meetingId}-{requestId}-bots.yaml\"" ✅

5. CHECK TASK STATUS:
```bash
docker-compose -f docker-compose.full.yml exec postgres psql -U postgres -d zoom_bots -c "
SELECT id, meeting_id, scheduled_time_ist, status, executed_at, NOW() 
FROM scheduled_tasks 
WHERE status = 'pending' 
ORDER BY id DESC 
LIMIT 5;
"
```

IMPORTANT:
----------
- Bot server MUST be restarted after code changes
- Old code was using: `compose-{meetingId}-bots.yaml` (missing requestId)
- New code uses: `compose-{meetingId}-{requestId}-bots.yaml` (with requestId)

