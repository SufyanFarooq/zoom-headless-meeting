DEBUG SCHEDULER BOT COUNT ISSUE
================================

PROBLEM:
--------
Scheduled 10 bots (video: 0, audio: 10) but 15 bots joined (video: 5, audio: 10)

POSSIBLE CAUSES:
----------------

1. API CONTAINER NOT RESTARTED
   - Old scheduler code still running
   - Fix: Restart API container

2. DATABASE HAS OLD DATA
   - video_count/audio_count not saved correctly
   - Fix: Check database, verify data

3. SCHEDULER USING FALLBACK
   - video_count is NULL/undefined in database
   - Fix: Check database schema

DEBUG STEPS:
------------

1. CHECK SCHEDULER LOGS:
```bash
docker-compose -f docker-compose.full.yml logs api | grep -i "Scheduler calling createBots\|videoCount\|audioCount" | tail -20
```

Should see:
- "videoCount: 0" ✅
- "audioCount: 10" ✅

If you see:
- "videoCount: 5" ❌ → Old code running or database issue

2. CHECK DATABASE DATA:
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

Should see:
- video_count: 0 ✅
- audio_count: 10 ✅

If you see:
- video_count: NULL or 5 ❌ → Data not saved correctly

3. CHECK MEETING RECORD:
```bash
docker-compose -f docker-compose.full.yml exec postgres psql -U postgres -d zoom_bots -c "
SELECT 
  id,
  meeting_id,
  members_count,
  video_count,
  audio_count
FROM meetings 
WHERE meeting_id = '87603104813'
ORDER BY started_at DESC
LIMIT 3;
"
```

FIX:
----

1. RESTART API CONTAINER:
```bash
docker-compose -f docker-compose.full.yml restart api
```

2. CHECK LOGS AGAIN:
```bash
docker-compose -f docker-compose.full.yml logs api | grep -i "Scheduler calling createBots" | tail -5
```

3. CREATE NEW SCHEDULED MEETING:
- videoCount: 0
- audioCount: 10
- Check if correct count

4. IF STILL WRONG, CHECK DATABASE:
```bash
# Check latest scheduled task
docker-compose -f docker-compose.full.yml exec postgres psql -U postgres -d zoom_bots -c "
SELECT * FROM scheduled_tasks ORDER BY id DESC LIMIT 1;
"
```

