FIX SCHEDULER - CODE NOT UPDATED ON SERVER
==========================================

PROBLEM:
--------
- Database has correct data: video_count: 0, audio_count: 10 ✅
- But scheduler still creating 15 bots (5 video + 10 audio) ❌
- Reason: Server has OLD scheduler code

SOLUTION:
---------

STEP 1: Pull Latest Code
--------------------------
```bash
cd /path/to/meetingsdk-headless-linux-sample
git pull origin main
```

STEP 2: Restart API Container
------------------------------
```bash
docker-compose -f docker-compose.full.yml restart api
```

STEP 3: Verify Scheduler Code Updated
--------------------------------------
```bash
# Check scheduler logs for next execution
docker-compose -f docker-compose.full.yml logs api | grep -i "Scheduler calling createBots" | tail -3
```

Should see:
- videoCount: 0 ✅
- audioCount: 10 ✅

STEP 4: Test with New Scheduled Meeting
----------------------------------------
Create a new scheduled meeting:
- videoCount: 0
- audioCount: 10
- Wait for scheduled time
- Check meetings table - should show video_count: 0, audio_count: 10

STEP 5: If Still Wrong - Rebuild API
------------------------------------
```bash
docker-compose -f docker-compose.full.yml stop api
docker-compose -f docker-compose.full.yml rm -f api
docker-compose -f docker-compose.full.yml build --no-cache api
docker-compose -f docker-compose.full.yml up -d api
```

IMPORTANT:
----------
- Old scheduled meetings (already executed) won't change
- Only NEW scheduled meetings will use correct logic
- Make sure to pull code FIRST before restarting

