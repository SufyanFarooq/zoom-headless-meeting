-- Migration: Add priority column to bot_servers table
-- Run this if the priority column doesn't exist yet

-- Add priority column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'bot_servers' 
        AND column_name = 'priority'
    ) THEN
        ALTER TABLE bot_servers ADD COLUMN priority INTEGER DEFAULT 100;
        RAISE NOTICE 'Added priority column to bot_servers table';
    ELSE
        RAISE NOTICE 'Priority column already exists';
    END IF;
END $$;

-- Set default priorities for existing servers
-- If server_name contains '1' or 'server-1', set priority to 1
-- If server_name contains '2' or 'server-2', set priority to 2
UPDATE bot_servers 
SET priority = 1 
WHERE (server_name ILIKE '%server-1%' OR server_name ILIKE '%1%') 
AND priority = 100;

UPDATE bot_servers 
SET priority = 2 
WHERE (server_name ILIKE '%server-2%' OR server_name ILIKE '%2%') 
AND priority = 100 
AND NOT (server_name ILIKE '%server-1%' OR server_name ILIKE '%1%');

-- Display current server configuration
SELECT 
    id,
    server_name,
    server_url,
    capacity,
    current_load,
    priority,
    status,
    (capacity - current_load) as available_capacity
FROM bot_servers
ORDER BY priority ASC, current_load ASC;

