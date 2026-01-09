#!/bin/bash
echo "=== CHECKING SCHEDULED TASK STATUS (ALL STATUSES) ==="
docker-compose -f docker-compose.full.yml exec postgres psql -U postgres -d zoom_bots -c "
SELECT 
  id,
  meeting_id,
  scheduled_time_ist,
  status,
  executed_at,
  NOW() as current_time,
  CASE 
    WHEN executed_at IS NOT NULL THEN 'EXECUTED'
    WHEN status = 'failed' THEN 'FAILED'
    WHEN status = 'pending' THEN 'PENDING'
    ELSE 'UNKNOWN'
  END as task_state
FROM scheduled_tasks 
WHERE meeting_id = '87603104813'
ORDER BY id DESC;
"

echo ""
echo "=== CHECKING MEETING RECORD ==="
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
ORDER BY started_at DESC
LIMIT 5;
"

echo ""
echo "=== CHECKING SCHEDULER LOGS (LAST 50 LINES) ==="
docker-compose -f docker-compose.full.yml logs api | grep -i "scheduler\|schedule\|task.*12\|87603104813\|Error executing" | tail -50

echo ""
echo "=== CHECKING CONTAINERS ==="
docker ps | grep "87603104813" || echo "No running containers found"
docker ps -a | grep "87603104813" | head -5 || echo "No containers found (including stopped)"

echo ""
echo "=== CHECKING RECENT SCHEDULER EXECUTION ==="
docker-compose -f docker-compose.full.yml logs api | grep -i "Scheduler check\|Found.*due\|Executing scheduled task" | tail -20
