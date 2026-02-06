-- PostgreSQL Schema for Zoom Bot Dashboard
-- Run this to create the database tables

-- Meetings table - stores active and completed meetings
CREATE TABLE IF NOT EXISTS meetings (
  id SERIAL PRIMARY KEY,
  meeting_id VARCHAR(50) NOT NULL,
  password VARCHAR(100) NOT NULL,
  members_count INTEGER NOT NULL,
  name_type VARCHAR(20) NOT NULL CHECK (name_type IN ('Indian', 'International')),
  meeting_type VARCHAR(30) NOT NULL CHECK (meeting_type IN ('Normal Member', 'Profile Pic Member')),
  status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'stopped', 'completed')),
  timeout_seconds INTEGER DEFAULT 7200,
  bot_server_id INTEGER,
  container_ids TEXT[], -- Array of Docker container IDs
  video_count INTEGER DEFAULT 0,
  audio_count INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW(),
  started_at TIMESTAMP,
  stopped_at TIMESTAMP
);

-- Scheduled tasks - meetings scheduled for future
CREATE TABLE IF NOT EXISTS scheduled_tasks (
  id SERIAL PRIMARY KEY,
  meeting_id VARCHAR(50) NOT NULL,
  password VARCHAR(100) NOT NULL,
  members_count INTEGER NOT NULL,
  video_count INTEGER NOT NULL DEFAULT 0,
  audio_count INTEGER NOT NULL DEFAULT 0,
  name_type VARCHAR(20) NOT NULL CHECK (name_type IN ('Indian', 'International')),
  meeting_type VARCHAR(30) NOT NULL CHECK (meeting_type IN ('Normal Member', 'Profile Pic Member')),
  scheduled_time_ist TIMESTAMP NOT NULL, -- Stored as UTC, displayed as IST
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'executed', 'cancelled', 'failed')),
  timeout_seconds INTEGER DEFAULT 7200,
  created_at TIMESTAMP DEFAULT NOW(),
  executed_at TIMESTAMP
);

-- Usage tracking - tracks total submissions
CREATE TABLE IF NOT EXISTS usage_tracking (
  id SERIAL PRIMARY KEY,
  total_submitted INTEGER DEFAULT 0,
  remaining INTEGER DEFAULT 2000,
  limit_value INTEGER DEFAULT 2000,
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Bot servers registry - multiple servers for scaling
CREATE TABLE IF NOT EXISTS bot_servers (
  id SERIAL PRIMARY KEY,
  server_name VARCHAR(100) NOT NULL UNIQUE,
  server_url VARCHAR(255) NOT NULL, -- http://server-ip:port
  status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'maintenance')),
  capacity INTEGER DEFAULT 100, -- Max bots this server can handle
  current_load INTEGER DEFAULT 0, -- Current number of bots running
  priority INTEGER DEFAULT 100, -- Lower number = higher priority (Server 1 = 1, Server 2 = 2)
  created_at TIMESTAMP DEFAULT NOW(),
  last_heartbeat TIMESTAMP DEFAULT NOW()
);

-- Users table - for authentication
CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  username VARCHAR(50) NOT NULL UNIQUE,
  email VARCHAR(100) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  is_admin BOOLEAN DEFAULT FALSE,
  reset_token VARCHAR(255),
  reset_token_expiry TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Initialize usage tracking
INSERT INTO usage_tracking (total_submitted, remaining, limit_value) 
VALUES (0, 2000, 2000)
ON CONFLICT DO NOTHING;

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_meetings_status ON meetings(status);
CREATE INDEX IF NOT EXISTS idx_meetings_created_at ON meetings(created_at);
CREATE INDEX IF NOT EXISTS idx_scheduled_tasks_status ON scheduled_tasks(status);
CREATE INDEX IF NOT EXISTS idx_scheduled_tasks_time ON scheduled_tasks(scheduled_time_ist);
CREATE INDEX IF NOT EXISTS idx_bot_servers_status ON bot_servers(status);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
