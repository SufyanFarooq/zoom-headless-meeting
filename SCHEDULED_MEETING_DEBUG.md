SCHEDULED MEETING DEBUG GUIDE
==============================

VERIFICATION:
-------------

YES, scheduled meetings mein bhi containers banne chahiye!

CODE CONFIRMATION:
------------------

SCHEDULED MEETING (scheduler.js line 77):
- Calls: createBots() - SAME function
- Creates: zoom-bot-{meetingId}-{requestId}-{number}
- Stores: container_ids in meetings table

UNSCHEDULED MEETING (meetings.js line 50):
- Calls: createBots() - SAME function  
- Creates: zoom-bot-{meetingId}-{requestId}-{number}
- Stores: container_ids in meetings table

Both use EXACTLY the same createBots() function!

ISSUE DIAGNOSIS:
----------------

If containers not being created, check:

1. SCHEDULER EXECUTION:
```bash
# Check if scheduler is running
docker-compose -f docker-compose.full.yml logs api | grep -i "scheduler\|schedule" | tail -30
```

Should see:
- "Starting scheduler"
- "Scheduler check at [UTC time]"
- "Found X due scheduled task(s)"
- "Executing scheduled task X"

2. CHECK SCHEDULED TASK STATUS:
```bash
docker-compose -f docker-compose.full.yml exec postgres psql -U postgres -d zoom_bots -c "
SELECT 
  id,
  meeting_id,
  scheduled_time_ist,
  status,
  executed_at,
  NOW() as current_time,
  scheduled_time_ist <= NOW() as is_due,
  EXTRACT(EPOCH FROM (NOW() - scheduled_time_ist)) as seconds_past
FROM scheduled_tasks 
WHERE id = 11;
"
```

3. CHECK IF MEETING RECORD CREATED:
```bash
docker-compose -f docker-compose.full.yml exec postgres psql -U postgres -d zoom_bots -c "
SELECT 
  id,
  meeting_id,
  container_ids,
  status,
  started_at,
  bot_server_id
FROM meetings 
WHERE meeting_id = '87603104813'
ORDER BY started_at DESC;
"
```

4. CHECK SCHEDULER ERROR LOGS:
```bash
docker-compose -f docker-compose.full.yml logs api | grep -A 20 "Error executing scheduled task"
```

5. CHECK CONTAINERS:
```bash
docker ps | grep "zoom-bot-87603104813"
docker ps -a | grep "zoom-bot-87603104813"
```

6. CHECK createBots CALL:
```bash
docker-compose -f docker-compose.full.yml logs api | grep -A 10 "Scheduler calling createBots"
```

POSSIBLE ISSUES:
----------------

1. SCHEDULER NOT RUNNING:
   - Check: docker-compose -f docker-compose.full.yml logs api | grep "Starting scheduler"
   - Fix: Restart API container

2. SCHEDULED TIME NOT ARRIVED:
   - Check: scheduled_time_ist <= NOW() should be true
   - Issue: Timezone conversion wrong
   - Fix: Verify UTC time is correct

3. createBots() FAILING:
   - Check error logs
   - Verify bot server accessible
   - Check meeting ID/password valid

4. ERROR BEING CAUGHT:
   - Task marked as 'failed'
   - Check error logs for details

QUICK DEBUG COMMANDS:
---------------------

# Check scheduler status
docker-compose -f docker-compose.full.yml exec api node -e "
const scheduler = require('./api/workers/scheduler');
console.log('Scheduler running:', scheduler.isRunning);
"

# Check pending schedules
docker-compose -f docker-compose.full.yml exec postgres psql -U postgres -d zoom_bots -c "
SELECT id, meeting_id, scheduled_time_ist, status, NOW() FROM scheduled_tasks WHERE status='pending';
"

# Check scheduler logs in real-time
docker-compose -f docker-compose.full.yml logs -f api | grep -i scheduler

