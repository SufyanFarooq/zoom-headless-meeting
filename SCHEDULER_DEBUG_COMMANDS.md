SCHEDULER DEBUG COMMANDS
=========================

ISSUE:
------
- Scheduled meeting created but bots not joining
- Time display showing wrong time
- Scheduler might not be executing

DEBUG STEPS:
------------

1. CHECK SCHEDULER IS RUNNING:
```bash
docker-compose -f docker-compose.full.yml logs api | grep -i scheduler
```

Should see:
- "Starting scheduler"
- "Scheduler check at [UTC time]"
- "Found X due scheduled task(s)"

2. CHECK PENDING SCHEDULES:
```bash
docker-compose -f docker-compose.full.yml exec api node -e "
const { query } = require('./api/db');
query('SELECT id, meeting_id, scheduled_time_ist, status, NOW() as current_time FROM scheduled_tasks WHERE status = \\'pending\\' ORDER BY scheduled_time_ist ASC')
  .then(result => {
    console.log('Pending schedules:');
    result.rows.forEach(row => {
      console.log(\`ID: \${row.id}, Meeting: \${row.meeting_id}, Scheduled: \${row.scheduled_time_ist}, Current: \${row.current_time}, Status: \${row.status}\`);
    });
  });
"
```

3. CHECK SERVER TIME:
```bash
docker-compose -f docker-compose.full.yml exec api date -u
```

4. CHECK SCHEDULER LOGS IN REAL-TIME:
```bash
docker-compose -f docker-compose.full.yml logs -f api | grep -i "scheduler\|schedule\|due"
```

5. MANUALLY TRIGGER SCHEDULER (for testing):
```bash
docker-compose -f docker-compose.full.yml exec api node -e "
const scheduler = require('./api/workers/scheduler');
scheduler.checkAndExecuteSchedules().then(() => {
  console.log('Scheduler check completed');
  process.exit(0);
});
"
```

6. CHECK IF SCHEDULED TIME HAS PASSED:
```bash
docker-compose -f docker-compose.full.yml exec postgres psql -U postgres -d zoom_bots -c "
SELECT 
  id, 
  meeting_id, 
  scheduled_time_ist, 
  NOW() as current_time,
  scheduled_time_ist <= NOW() as is_due,
  EXTRACT(EPOCH FROM (NOW() - scheduled_time_ist)) as seconds_past
FROM scheduled_tasks 
WHERE status = 'pending'
ORDER BY scheduled_time_ist ASC;
"
```

FIXES APPLIED:
--------------
1. Improved UTC conversion
2. Better scheduler logging
3. Explicit timezone handling

NEXT STEPS:
-----------
1. Pull latest code
2. Restart API container
3. Check scheduler logs
4. Test with new schedule

