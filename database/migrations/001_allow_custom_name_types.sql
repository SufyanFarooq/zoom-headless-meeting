-- Allow custom name types (Nepal, Pak, etc.) in addition to Indian, International
-- Run: psql -U postgres -d zoom_bots -f database/migrations/001_allow_custom_name_types.sql

ALTER TABLE meetings DROP CONSTRAINT IF EXISTS meetings_name_type_check;
ALTER TABLE meetings ADD CONSTRAINT meetings_name_type_check CHECK (char_length(name_type) <= 50 AND name_type ~ '^[a-zA-Z0-9_-]+$');

ALTER TABLE scheduled_tasks DROP CONSTRAINT IF EXISTS scheduled_tasks_name_type_check;
ALTER TABLE scheduled_tasks ADD CONSTRAINT scheduled_tasks_name_type_check CHECK (char_length(name_type) <= 50 AND name_type ~ '^[a-zA-Z0-9_-]+$');
