# 🧪 Local Bot Testing Guide

## Quick Start

### 1. Normal Member Bots (No ZAK tokens - Fast)
```bash
./test-local-bot.sh <MEETING_ID> <PASSWORD> [BOT_COUNT]
```

**Example:**
```bash
./test-local-bot.sh 87603104813 511651 5
```
This creates 5 audio bots that join as guests (no profile pictures).

---

### 2. Profile Pic Member Bots (With ZAK tokens - Slower)
```bash
./test-local-bot-profile-pic.sh <MEETING_ID> <PASSWORD> [BOT_COUNT]
```

**Example:**
```bash
./test-local-bot-profile-pic.sh 87603104813 511651 5
```
This creates 5 audio bots with ZAK tokens (join with profile pictures).

**Note:** ZAK token generation takes 30-60 seconds for multiple bots.

---

## 📋 Prerequisites

1. **Docker Desktop** must be running
2. **Bot Server** must be running (check: `curl http://localhost:3001/health`)
3. **Real Zoom Meeting** must be created and active
4. **Linux video bots (v4l2loopback)** need virtual camera devices if you want camera icons in desktop/mobile clients

---

## 🎥 Virtual Camera (v4l2loopback) for Video Bots

If you want video bots to use virtual cameras (and show camera icons in desktop/mobile clients), create v4l2 devices on the Linux host.

### 1) Install v4l2loopback
```bash
sudo apt install v4l2loopback-dkms
```

### 2) Create multiple virtual cameras with labels
```bash
sudo modprobe v4l2loopback devices=3 video_nr=2,3,4 card_label="BotCam1,BotCam2,BotCam3" exclusive_caps=1
```

### 3) Feed a video stream into a device (example)
```bash
ffmpeg -stream_loop -1 -re -i videos/video-1.mp4 -f v4l2 /dev/video2
```

### 4) Run bots with v4l2 cameras
The generated compose file uses:
- `VIDEO_DEVICE_BASE` (default 2)
- `CAMERA_LABEL_PREFIX` (default BotCam)
- `CAMERA_MODE` (default v4l2)

So video bot #1 expects `/dev/video2` labeled `BotCam1`, bot #2 uses `/dev/video3` labeled `BotCam2`, etc.

---

## 🔍 Monitoring Bots

### View Container Status
```bash
docker ps | grep zoom-bot
```

### View Build Logs
```bash
docker logs <CONTAINER_NAME>
```

### View Bot Application Logs (After Build Completes)
```bash
docker exec <CONTAINER_NAME> tail -f /tmp/meeting-sdk-linux-sample/out/error.log
```

### View All Bot Logs
```bash
# Replace MEETING_ID and REQUEST_ID with your values
docker logs zoom-bot-<MEETING_ID>-<REQUEST_ID>-1
docker logs zoom-bot-<MEETING_ID>-<REQUEST_ID>-2
# ... etc
```

---

## 🛑 Stopping Bots

### Stop All Bots for a Meeting
```bash
docker stop $(docker ps -q --filter "name=zoom-bot-<MEETING_ID>-<REQUEST_ID>")
```

### Stop All Bot Containers
```bash
docker stop $(docker ps -q --filter "name=zoom-bot-")
```

### Remove All Stopped Bot Containers
```bash
docker rm $(docker ps -aq --filter "name=zoom-bot-")
```

---

## 📊 Expected Behavior

### First Time Build
- **Build Time:** 5-15 minutes (compiling dependencies)
- **Logs:** Show CMake, vcpkg, and compilation progress
- **Status:** Container stays running during build

### Subsequent Builds (Cached)
- **Build Time:** 10-30 seconds (using cache)
- **Logs:** Minimal output, quick startup

### After Build Completes
- **Bot Logs:** Available in `/tmp/meeting-sdk-linux-sample/out/error.log`
- **Zoom SDK:** Initializes and attempts to join meeting
- **Success:** Bots appear in Zoom meeting participant list

---

## 🐛 Troubleshooting

### Bot Server Not Responding
```bash
# Check if bot-server is running
docker ps | grep bot-server

# Restart bot-server
docker-compose -f docker-compose.full.yml restart bot-server
```

### Build Taking Too Long
- First build always takes 5-15 minutes
- Subsequent builds use cache (10-30 seconds)
- Check build progress: `docker logs <CONTAINER_NAME>`

### Bots Not Joining Meeting
1. Verify meeting ID and password are correct
2. Ensure meeting is active (not ended)
3. Check bot logs: `docker exec <CONTAINER> tail /tmp/meeting-sdk-linux-sample/out/error.log`
4. Look for error codes:
   - `MeetingFailCode 63` = Invalid meeting ID/password
   - `MeetingFailCode 0` = Success (should join)

### No Logs Appearing
- Build logs: `docker logs <CONTAINER_NAME>`
- Application logs: `docker exec <CONTAINER> cat /tmp/meeting-sdk-linux-sample/out/error.log`
- Logs are redirected to file, not stdout

---

## ✅ Success Indicators

1. **Container Running:** `docker ps` shows container status "Up"
2. **Build Complete:** Logs show "Build successful - executable found"
3. **SDK Initialized:** Logs show "✅ authorize" and "✅ join a meeting"
4. **Meeting Joined:** Logs show "⏳ connecting to the meeting" without errors
5. **Bots Visible:** Check Zoom meeting participant list

---

## 📝 Example Test Session

```bash
# 1. Create a Zoom meeting and note the ID and password
#    Example: Meeting ID: 87603104813, Password: 511651

# 2. Test with 2 normal bots (fast)
./test-local-bot.sh 87603104813 511651 2

# 3. Wait for build (first time: 5-15 min, cached: 10-30 sec)

# 4. Check logs
docker logs zoom-bot-87603104813-local-test-<TIMESTAMP>-1

# 5. Check application logs
docker exec zoom-bot-87603104813-local-test-<TIMESTAMP>-1 tail /tmp/meeting-sdk-linux-sample/out/error.log

# 6. Verify bots joined in Zoom meeting

# 7. Stop bots when done
docker stop $(docker ps -q --filter "name=zoom-bot-87603104813-local-test")
```

---

## 🎯 Tips

- **Start Small:** Test with 1-2 bots first
- **Use Cached Builds:** After first build, subsequent bots start much faster
- **Check Meeting Settings:** Ensure meeting allows participants to join
- **Monitor Resources:** Multiple bots consume CPU/memory during build
- **Clean Up:** Remove old containers regularly to save disk space
