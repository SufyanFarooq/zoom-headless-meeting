-- Check scheduled tasks with video/audio counts
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

-- Check recent meetings created by scheduler
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

