SCHEDULER CONTAINER CREATION CHECK
===================================

VERIFICATION:
-------------

YES, scheduled meetings mein bhi containers banne chahiye!

CODE FLOW:
----------

SCHEDULED MEETING FLOW:
1. Scheduler runs every minute
2. Checks for due scheduled tasks
3. Calls createBots() - SAME function as unscheduled meetings
4. Creates containers with meeting ID and timestamp
5. Stores container_ids in meetings table
6. Same process as quick/unscheduled meetings

COMPARISON:
-----------

UNSCHEDULED MEETING:
- POST /api/meetings
- Calls createBots()
- Creates containers: zoom-bot-{meetingId}-{timestamp}-{number}
- Stores container_ids

SCHEDULED MEETING:
- Scheduler executes at scheduled time
- Calls createBots() - SAME function
- Creates containers: zoom-bot-{meetingId}-{timestamp}-{number}
- Stores container_ids
- Creates meeting record in meetings table

ISSUE DIAGNOSIS:
----------------

If containers not being created for scheduled meetings:

1. CHECK SCHEDULER IS RUNNING:
```bash
docker-compose -f docker-compose.full.yml logs api | grep -i "scheduler\|schedule"
```

2. CHECK IF TASK EXECUTED:
```bash
docker-compose -f docker-compose.full.yml exec postgres psql -U postgres -d zoom_bots -c "
SELECT id, meeting_id, scheduled_time_ist, status, executed_at, NOW() as current_time
FROM scheduled_tasks 
WHERE id = 11;
"
```

3. CHECK MEETING RECORD CREATED:
```bash
docker-compose -f docker-compose.full.yml exec postgres psql -U postgres -d zoom_bots -c "
SELECT id, meeting_id, container_ids, status, started_at
FROM meetings 
WHERE meeting_id = '87603104813'
ORDER BY started_at DESC;
"
```

4. CHECK SCHEDULER ERROR LOGS:
```bash
docker-compose -f docker-compose.full.yml logs api | grep -A 10 "Error executing scheduled task"
```

5. CHECK CONTAINERS:
```bash
docker ps | grep "zoom-bot-87603104813"
```

POSSIBLE ISSUES:
----------------

1. SCHEDULER NOT RUNNING:
   - Check if scheduler.start() called
   - Check cron job is active

2. SCHEDULED TIME NOT ARRIVED:
   - Check if scheduled_time_ist <= NOW()
   - Verify timezone is correct

3. createBots() FAILING:
   - Check error logs
   - Verify bot server is accessible
   - Check meeting ID and password are valid

4. ERROR BEING CAUGHT:
   - Check scheduler error logs
   - Task might be marked as 'failed'

DEBUGGING:
----------

Check scheduler execution:
```bash
# Real-time scheduler logs
docker-compose -f docker-compose.full.yml logs -f api | grep -i "scheduler\|schedule\|createBots"
```

Check specific scheduled task:
```bash
# Check task details
docker-compose -f docker-compose.full.yml exec postgres psql -U postgres -d zoom_bots -c "
SELECT 
  id,
  meeting_id,
  scheduled_time_ist,
  status,
  executed_at,
  NOW() as current_time,
  scheduled_time_ist <= NOW() as is_due
FROM scheduled_tasks 
WHERE id = 11;
"
```

Check if meeting was created:
```bash
# Check meetings table
docker-compose -f docker-compose.full.yml exec postgres psql -U postgres -d zoom_bots -c "
SELECT * FROM meetings WHERE meeting_id = '87603104813' ORDER BY started_at DESC LIMIT 5;
"
```

