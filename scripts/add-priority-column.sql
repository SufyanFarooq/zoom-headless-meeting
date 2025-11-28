-- Add priority column to bot_servers table
-- Run this if priority column doesn't exist

-- Add priority column if it doesn't exist
ALTER TABLE bot_servers ADD COLUMN IF NOT EXISTS priority INTEGER DEFAULT 100;

-- Update existing servers with default priorities
-- Server 1 gets priority 1 (primary)
UPDATE bot_servers 
SET priority = 1 
WHERE server_name = 'server-1' OR server_name ILIKE '%server-1%' OR server_name ILIKE '%1%';

-- Any other servers get priority 2 (secondary)
UPDATE bot_servers 
SET priority = 2 
WHERE priority = 100 AND (server_name != 'server-1' AND server_name NOT ILIKE '%server-1%');

-- Display updated table
SELECT id, server_name, server_url, capacity, current_load, priority, status 
FROM bot_servers 
ORDER BY priority ASC;

