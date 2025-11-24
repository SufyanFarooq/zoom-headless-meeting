# Zoom Bot Dashboard API

Node.js API server for managing Zoom bots via dashboard.

## Architecture

- **Dashboard API Server**: Node.js/Express (port 3000)
- **Bot Server API**: Node.js/Express (port 3001) - runs on each bot server
- **Database**: PostgreSQL
- **Scheduling**: Background worker polls database every 30 seconds

## Setup

### 1. Install Dependencies

```bash
npm install
```

### 2. Setup PostgreSQL Database

```bash
# Create database
createdb zoom_bots

# Run schema
psql zoom_bots < database/schema.sql
```

### 3. Configure Environment

```bash
cp .env.example .env
# Edit .env with your database and Zoom API credentials
```

### 4. Start Services

**Dashboard API Server:**
```bash
npm start
# or for development:
npm run dev
```

**Bot Server API** (on each bot server):
```bash
npm run start:bot-server
# or for development:
npm run dev:bot-server
```

## API Endpoints

### Meetings

- `POST /api/meetings` - Create meeting
- `GET /api/meetings` - Get all meetings
- `GET /api/meetings/:id` - Get meeting by ID
- `DELETE /api/meetings/:id` - Stop meeting

### Schedules

- `POST /api/schedules` - Create scheduled task
- `GET /api/schedules` - Get all scheduled tasks
- `DELETE /api/schedules/:id` - Cancel scheduled task

### Usage

- `GET /api/usage` - Get usage statistics (0/2000)

## Features

- ✅ Members count validation (divisible by 10, not zero, max 100)
- ✅ Usage limit tracking (2000 total, 100+ not allowed)
- ✅ Name type selection (Indian/International)
- ✅ Meeting type mapping (Normal/Webinar/Profile Pic)
- ✅ Scheduled meetings (IST timezone)
- ✅ Multi-server support (scalable)
- ✅ Background scheduler (30s polling)

## Scheduler

The scheduler automatically:
- Polls database every 30 seconds
- Finds due scheduled tasks
- Executes them immediately
- Creates meetings and bots
- Updates usage tracking

No cron jobs needed - everything runs in the same Node.js process.

