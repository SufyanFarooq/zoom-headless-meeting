-- Add priority column to bot_servers if it doesn't exist
-- Run: cat database/migrations/002_add_priority_to_bot_servers.sql | docker compose -f docker-compose.full.yml exec -T postgres psql -U postgres -d zoom_bots

ALTER TABLE bot_servers ADD COLUMN IF NOT EXISTS priority INTEGER DEFAULT 100;
