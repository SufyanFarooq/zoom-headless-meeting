FIX SCHEDULER BOT COUNT - 15 BOTS INSTEAD OF 10
================================================

PROBLEM:
--------
Scheduled: videoCount: 0, audioCount: 10, total: 10
But: video_count: 5, audio_count: 10, total: 15 bots joining

ROOT CAUSE:
-----------
Scheduler is using fallback (50/50 split) instead of using video_count: 0

SOLUTION:
---------

STEP 1: Check scheduled_tasks table
------------------------------------
```bash
docker-compose -f docker-compose.full.yml exec postgres psql -U postgres -d zoom_bots -c "
SELECT 
  id,
  meeting_id,
  members_count,
  video_count,
  audio_count,
  status
FROM scheduled_tasks 
WHERE meeting_id = '87603104813'
ORDER BY id DESC
LIMIT 5;
"
```

If video_count is NULL or 5 → Data not saved correctly
If video_count is 0 → Scheduler code issue

STEP 2: Restart API Container
------------------------------
```bash
cd /path/to/meetingsdk-headless-linux-sample
git pull origin main
docker-compose -f docker-compose.full.yml restart api
```

STEP 3: Check Scheduler Logs
----------------------------
```bash
docker-compose -f docker-compose.full.yml logs api | grep -i "Scheduler calling createBots" | tail -5
```

Should see:
- videoCount: 0 ✅
- audioCount: 10 ✅

STEP 4: If Still Wrong - Rebuild API Image
-------------------------------------------
```bash
docker-compose -f docker-compose.full.yml stop api
docker-compose -f docker-compose.full.yml rm -f api
docker-compose -f docker-compose.full.yml build --no-cache api
docker-compose -f docker-compose.full.yml up -d api
```

STEP 5: Test New Scheduled Meeting
-----------------------------------
Create new scheduled meeting:
- videoCount: 0
- audioCount: 10
- Wait for scheduled time
- Check meetings table - should show video_count: 0

IMPORTANT:
----------
- API container restart is CRITICAL (scheduler code update hua hai)
- If scheduled_tasks has NULL values, old scheduled meetings will still use fallback
- Only NEW scheduled meetings will use correct logic

