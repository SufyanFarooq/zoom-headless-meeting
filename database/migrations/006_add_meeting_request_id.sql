-- Scope meeting cleanup to a single bot batch/refill request.
-- This prevents cleanup of one refill row from stopping all batches
-- for the same Zoom meeting ID.

ALTER TABLE meetings
ADD COLUMN IF NOT EXISTS request_id VARCHAR(50);

-- Backfill request_id from the first stored container name when possible.
UPDATE meetings
SET request_id = substring(container_ids[1] from '^zoom-bot-[0-9]+-([0-9]+)-[0-9]+$')
WHERE request_id IS NULL
  AND container_ids IS NOT NULL
  AND array_length(container_ids, 1) > 0
  AND container_ids[1] ~ '^zoom-bot-[0-9]+-[0-9]+-[0-9]+$';

CREATE INDEX IF NOT EXISTS idx_meetings_request_id ON meetings(request_id);
