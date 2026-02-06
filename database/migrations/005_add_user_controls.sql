-- Add blocking + per-user max member limit + creator tracking
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_blocked BOOLEAN DEFAULT false;
ALTER TABLE users ADD COLUMN IF NOT EXISTS max_members_limit INTEGER;
ALTER TABLE users ADD COLUMN IF NOT EXISTS created_by_admin_id INTEGER REFERENCES users(id);

CREATE INDEX IF NOT EXISTS idx_users_is_blocked ON users(is_blocked);
CREATE INDEX IF NOT EXISTS idx_users_created_by_admin_id ON users(created_by_admin_id);
