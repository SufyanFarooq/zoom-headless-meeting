#!/usr/bin/env bash
# View API and bot-server logs to debug cleanup/stop flow
# Run: ./check-cleanup-logs.sh

echo "=== API logs (last 50 lines, filter STOP/CLEANUP) ==="
docker compose -f docker-compose.full.yml logs api --tail 100 2>&1 | grep -E '\[STOP\]|\[CLEANUP\]|\[stopBots\]|\[checkContainersStatus\]' || echo "(no matches)"

echo ""
echo "=== Bot-server logs (last 50 lines, filter STOP/STATUS/CLEANUP) ==="
docker compose -f docker-compose.full.yml logs bot-server --tail 100 2>&1 | grep -E '\[STOP\]|\[STATUS\]|\[CLEANUP' || echo "(no matches)"
