-- Add user_id to meetings and scheduled_tasks
ALTER TABLE meetings ADD COLUMN IF NOT EXISTS user_id INTEGER REFERENCES users(id);
ALTER TABLE scheduled_tasks ADD COLUMN IF NOT EXISTS user_id INTEGER REFERENCES users(id);
CREATE INDEX IF NOT EXISTS idx_meetings_user_id ON meetings(user_id);
CREATE INDEX IF NOT EXISTS idx_scheduled_tasks_user_id ON scheduled_tasks(user_id);
