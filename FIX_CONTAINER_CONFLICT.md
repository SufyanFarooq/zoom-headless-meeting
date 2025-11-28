# Fix Container Conflict - Multiple Meetings Support

## Problem Fixed ✅

**Before:**
- Har meeting ke liye `compose-50-bots.yaml` overwrite hoti thi
- Containers `zoom-bot-1` to `zoom-bot-N` se start hote the
- Multiple meetings me same container names conflict create karte the
- Existing containers disturb ho rahe the

**After:**
- Har meeting ke liye unique compose file: `compose-{meetingId}-bots.yaml`
- Containers unique names: `zoom-bot-{meetingId}-{botNumber}`
- Existing containers disturb nahi hote
- Stop ke time sirf specific meeting ke containers stop hote hain

## Changes Made

### 1. `generate-flexible-bots.sh`
- Meeting ID parameter add kiya
- Compose file name: `compose-{meetingId}-bots.yaml`
- Container names: `zoom-bot-{meetingId}-{botNumber}`

### 2. `setup-flexible-bots.sh`
- Meeting ID extract kiya JOIN_URL se
- Meeting ID pass kiya `generate-flexible-bots.sh` ko
- `update-compose-zak.py` ko compose file name pass kiya

### 3. `bot-server/api.js`
- Meeting ID pass kiya scripts ko
- Compose file name meeting ID based
- Container names meeting ID based
- Container IDs meeting ID based

### 4. `update-compose-zak.py`
- Compose file name command line argument se accept karta hai
- Both formats support: `bot-{meetingId}-{number}` aur `bot-{number}`

## Example

**Meeting 1 (5067498331):**
- Compose file: `compose-5067498331-bots.yaml`
- Containers: `zoom-bot-5067498331-1` to `zoom-bot-5067498331-100`

**Meeting 2 (8421085087):**
- Compose file: `compose-8421085087-bots.yaml`
- Containers: `zoom-bot-8421085087-1` to `zoom-bot-8421085087-20`

**Result:**
- ✅ No conflict
- ✅ Existing containers safe
- ✅ Multiple meetings simultaneously

## Testing

**Create Meeting 1:**
```bash
curl -X POST http://SERVER1_IP:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer TOKEN" \
  -d '{
    "meetingId": "5067498331",
    "password": "123456",
    "membersCount": 100,
    "videoCount": 0,
    "audioCount": 100,
    "nameType": "Indian",
    "meetingType": "Normal Member"
  }'
```

**Create Meeting 2 (while Meeting 1 running):**
```bash
curl -X POST http://SERVER1_IP:3000/api/meetings \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer TOKEN" \
  -d '{
    "meetingId": "8421085087",
    "password": "123456",
    "membersCount": 20,
    "videoCount": 0,
    "audioCount": 20,
    "nameType": "Indian",
    "meetingType": "Normal Member"
  }'
```

**Verify:**
```bash
# Check containers
docker ps | grep zoom-bot

# Should see:
# zoom-bot-5067498331-1 to zoom-bot-5067498331-100
# zoom-bot-8421085087-1 to zoom-bot-8421085087-20
```

**Stop Meeting 1 (only):**
```bash
# Stop via API - only Meeting 1 containers will stop
# Meeting 2 containers remain running
```

## Summary

**Problem:** Container conflict multiple meetings me  
**Solution:** Meeting ID based naming  
**Result:** ✅ Multiple meetings simultaneously, no conflicts

