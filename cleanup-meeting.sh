#!/usr/bin/env bash
# Manual cleanup: remove containers and delete compose file(s) for a meeting
# Usage: ./cleanup-meeting.sh <meetingId> [requestId]
# Example: ./cleanup-meeting.sh 5067498331 1770049488306
# Example: ./cleanup-meeting.sh 5067498331   (cleans ALL compose files for this meeting)

MEETING_ID="${1:-}"
REQUEST_ID="${2:-}"
BOT_SERVER_URL="${BOT_SERVER_URL:-http://localhost:3001}"

if [ -z "$MEETING_ID" ]; then
  echo "Usage: $0 <meetingId> [requestId]"
  echo "  With requestId: cleanup specific compose file"
  echo "  Without: cleanup ALL compose files for this meeting"
  echo ""
  echo "Example: $0 5067498331 1770049488306"
  echo "Example: $0 5067498331"
  exit 1
fi

if [ -n "$REQUEST_ID" ]; then
  echo "Cleaning up meeting $MEETING_ID request $REQUEST_ID..."
  RESP=$(curl -s -X POST "${BOT_SERVER_URL}/api/bots/cleanup-compose" \
    -H "Content-Type: application/json" \
    -d "{\"meetingId\":\"$MEETING_ID\",\"requestId\":\"$REQUEST_ID\"}")
else
  echo "Cleaning up ALL compose files for meeting $MEETING_ID..."
  RESP=$(curl -s -X POST "${BOT_SERVER_URL}/api/bots/cleanup-by-meeting" \
    -H "Content-Type: application/json" \
    -d "{\"meetingId\":\"$MEETING_ID\"}")
fi

echo "$RESP"
if echo "$RESP" | grep -q '"success":true'; then
  echo "✅ Cleanup done"
else
  echo "❌ Cleanup failed. Is bot-server running at $BOT_SERVER_URL?"
fi
