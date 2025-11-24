#!/bin/bash

# Script to register bot server in database
# Usage: ./scripts/register-bot-server.sh <server_name> <server_url> <capacity>

set -e

SERVER_NAME=${1:-"server-1"}
SERVER_URL=${2:-"http://localhost:3001"}
CAPACITY=${3:-100}

# Get database connection from environment or use defaults
DB_HOST=${DB_HOST:-localhost}
DB_PORT=${DB_PORT:-5432}
DB_NAME=${DB_NAME:-zoom_bots}
DB_USER=${DB_USER:-postgres}
DB_PASSWORD=${DB_PASSWORD:-postgres}

echo "🔧 Registering bot server..."
echo "   Name: $SERVER_NAME"
echo "   URL: $SERVER_URL"
echo "   Capacity: $CAPACITY"
echo ""

# Check if running in Docker
if [ -f /.dockerenv ] || [ -n "$DOCKER_CONTAINER" ]; then
    # Running in Docker - use docker exec
    DOCKER_DB_CONTAINER=${DOCKER_DB_CONTAINER:-zoom-dashboard-db}
    
    echo "Using Docker container: $DOCKER_DB_CONTAINER"
    
    docker exec -i "$DOCKER_DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" << EOF
INSERT INTO bot_servers (server_name, server_url, capacity, status)
VALUES ('$SERVER_NAME', '$SERVER_URL', $CAPACITY, 'active')
ON CONFLICT (server_name) 
DO UPDATE SET 
    server_url = EXCLUDED.server_url,
    capacity = EXCLUDED.capacity,
    status = 'active',
    last_heartbeat = NOW();
EOF

else
    # Running locally - use psql directly
    echo "Using local PostgreSQL connection"
    
    export PGPASSWORD="$DB_PASSWORD"
    
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" << EOF
INSERT INTO bot_servers (server_name, server_url, capacity, status)
VALUES ('$SERVER_NAME', '$SERVER_URL', $CAPACITY, 'active')
ON CONFLICT (server_name) 
DO UPDATE SET 
    server_url = EXCLUDED.server_url,
    capacity = EXCLUDED.capacity,
    status = 'active',
    last_heartbeat = NOW();
EOF

fi

echo ""
echo "✅ Bot server registered successfully!"
echo ""
echo "Verify:"
echo "   docker exec -it zoom-dashboard-db psql -U postgres -d zoom_bots -c 'SELECT * FROM bot_servers;'"

