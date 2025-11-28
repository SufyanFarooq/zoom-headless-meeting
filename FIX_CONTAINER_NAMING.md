# Fix Container Naming - Multiple Meetings Support

## Problem
Har meeting ke liye containers ko unique names chahiye. Currently, har meeting me containers `zoom-bot-1` to `zoom-bot-N` se start hote hain, jo conflict create karta hai.

**Example:**
- Meeting 1: `zoom-bot-1` to `zoom-bot-100` (running)
- Meeting 2: `zoom-bot-1` to `zoom-bot-20` (conflict!)

## Solution: Meeting-Based Container Names

Containers ko meeting ID ya unique prefix ke saath name karein:

**Format:** `zoom-bot-{meetingId}-{botNumber}`

**Example:**
- Meeting 1 (5067498331): `zoom-bot-5067498331-1` to `zoom-bot-5067498331-100`
- Meeting 2 (8421085087): `zoom-bot-8421085087-1` to `zoom-bot-8421085087-20`

## Implementation

### Option 1: Meeting ID Based (Recommended)

**Modify `bot-server/api.js`:**

```javascript
// Line 202-204: Change container naming
// OLD:
for (let i = 1; i <= totalBots; i++) {
  containerIds.push(`zoom-bot-${i}`);
}

// NEW:
const meetingPrefix = `zoom-bot-${meetingId}`;
for (let i = 1; i <= totalBots; i++) {
  containerIds.push(`${meetingPrefix}-${i}`);
}
```

**Modify `generate-flexible-bots.sh`:**

```bash
# Add meeting ID parameter
MEETING_ID="${1:-}"
BOT_NUMBER="${2:-1}"

# Use meeting ID in container name
container_name: zoom-bot-${MEETING_ID}-${BOT_NUMBER}
```

### Option 2: Timestamp Based

**Use timestamp to make names unique:**

```javascript
const timestamp = Date.now();
const meetingPrefix = `zoom-bot-${timestamp}`;
for (let i = 1; i <= totalBots; i++) {
  containerIds.push(`${meetingPrefix}-${i}`);
}
```

## Current Behavior

**Issue:** 
- Har meeting me containers `zoom-bot-1` se start hote hain
- Agar pehli meeting me `zoom-bot-1` to `zoom-bot-100` running hain
- Dusri meeting me bhi `zoom-bot-1` to `zoom-bot-20` create karna hai
- Docker container names unique hone chahiye, isliye conflict hota hai

**Solution:**
- Meeting ID ya unique prefix use karein
- Har meeting ke containers unique names se identify ho jayenge

## Quick Fix (Temporary)

**Agar immediate fix chahiye:**

1. Pehli meeting stop karein
2. Dusri meeting start karein
3. Phir pehli meeting start karein

**Ya:**

1. Server 1 par Docker image build karein (immediate fix)
2. Container naming fix karein (long-term fix)

## Summary

**Problem:** Container names conflict ho rahe hain multiple meetings me  
**Solution:** Meeting ID ya unique prefix use karein  
**Format:** `zoom-bot-{meetingId}-{botNumber}`  
**Status:** Needs code changes

