-- Add is_admin to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT false;
-- To make a user admin, run: UPDATE users SET is_admin = true WHERE username = 'your_admin_username';
-- Or first user: UPDATE users SET is_admin = true WHERE id = 1;
CREATE INDEX IF NOT EXISTS idx_users_is_admin ON users(is_admin);
