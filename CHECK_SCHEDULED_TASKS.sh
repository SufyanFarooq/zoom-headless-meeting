#!/bin/bash
echo "=== CHECKING SCHEDULED TASKS ==="
docker-compose -f docker-compose.full.yml exec postgres psql -U postgres -d zoom_bots -c "
SELECT 
  id,
  meeting_id,
  members_count,
  video_count,
  audio_count,
  name_type,
  meeting_type,
  scheduled_time_ist,
  status,
  executed_at,
  created_at
FROM scheduled_tasks 
WHERE meeting_id = '87603104813'
ORDER BY id DESC
LIMIT 10;
"

echo ""
echo "=== CHECKING MEETINGS CREATED BY SCHEDULER ==="
docker-compose -f docker-compose.full.yml exec postgres psql -U postgres -d zoom_bots -c "
SELECT 
  id,
  meeting_id,
  members_count,
  video_count,
  audio_count,
  name_type,
  meeting_type,
  status,
  started_at
FROM meetings 
WHERE meeting_id = '87603104813'
ORDER BY started_at DESC
LIMIT 5;
"

echo ""
echo "=== CHECKING SCHEDULER LOGS ==="
docker-compose -f docker-compose.full.yml logs api | grep -i "Scheduler calling createBots\|videoCount\|audioCount" | tail -10
