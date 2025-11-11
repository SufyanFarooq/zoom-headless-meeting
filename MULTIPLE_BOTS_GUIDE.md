# 🤖 Multiple Bots Guide - 10 Bots Simultaneously

Yeh guide aapko batayega ke kaise 10 bots ko simultaneously ek meeting mein join karwaya jaye different names ke saath.

## 📋 Prerequisites

1. ✅ Docker aur Docker Compose installed
2. ✅ Zoom SDK library already setup
3. ✅ Config file with credentials ready

## 🚀 Method 1: Docker Compose (Recommended)

### Step 1: Run All 10 Bots

```bash
docker compose -f compose-multiple-bots.yaml up
```

Yeh command 10 bots ko simultaneously start karega:
- Bot-1-Alice
- Bot-2-Bob
- Bot-3-Charlie
- Bot-4-Diana
- Bot-5-Eve
- Bot-6-Frank
- Bot-7-Grace
- Bot-8-Henry
- Bot-9-Iris
- Bot-10-Jack

### Step 2: Check Status

```bash
# All containers check karein
docker ps | grep zoom-bot

# Specific bot ka log dekhne ke liye
docker logs zoom-bot-1
docker logs zoom-bot-2
# ... etc
```

### Step 3: Stop All Bots

```bash
docker compose -f compose-multiple-bots.yaml down
```

## 🎯 Method 2: Individual Docker Commands

Agar aap manually control karna chahte hain:

```bash
# Bot 1 start karein
docker run -d --name zoom-bot-1 \
  -v $(pwd):/tmp/meeting-sdk-linux-sample \
  meetingsdk-headless-linux-sample-zoomsdk \
  /bin/bash -c "cd /tmp/meeting-sdk-linux-sample && ./build/zoomsdk --client-id 'vdPX1q2bSQKip0X17LqXAw' --client-secret 'Te1YdXaBL6IScwdBVlNF0kay75KDMkyz' --join-url 'https://us05web.zoom.us/j/5067498331?pwd=4aJ3z9zb8f0ZaKiouEYdWNFhBh1V6d.1&omn=86931044022' --display-name 'Bot-1-Alice' RawAudio --file bot-1-audio.pcm --dir out/bot-1"

# Bot 2 start karein
docker run -d --name zoom-bot-2 \
  -v $(pwd):/tmp/meeting-sdk-linux-sample \
  meetingsdk-headless-linux-sample-zoomsdk \
  /bin/bash -c "cd /tmp/meeting-sdk-linux-sample && ./build/zoomsdk --client-id 'vdPX1q2bSQKip0X17LqXAw' --client-secret 'Te1YdXaBL6IScwdBVlNF0kay75KDMkyz' --join-url 'https://us05web.zoom.us/j/5067498331?pwd=4aJ3z9zb8f0ZaKiouEYdWNFhBh1V6d.1&omn=86931044022' --display-name 'Bot-2-Bob' RawAudio --file bot-2-audio.pcm --dir out/bot-2"

# ... continue for all 10 bots
```

## 📁 Output Files

Har bot ka output separate folder mein save hoga:

```
out/
├── bot-1/
│   ├── bot-1-audio.pcm
│   └── bot-1-video.mp4
├── bot-2/
│   ├── bot-2-audio.pcm
│   └── bot-2-video.mp4
├── bot-3/
│   └── ...
└── ...
```

## ⚙️ Configuration

### Bot Names Change Karne Ke Liye

`compose-multiple-bots.yaml` file mein jao aur `DISPLAY_NAME` aur `--display-name` values change karein:

```yaml
environment:
  - DISPLAY_NAME=Your-Bot-Name
```

### Meeting URL Change Karne Ke Liye

`compose-multiple-bots.yaml` file mein `JOIN_URL` update karein:

```yaml
environment:
  - JOIN_URL=your-meeting-url-here
```

## 🔍 Monitoring

### All Bots Status Check

```bash
docker ps --filter "name=zoom-bot" --format "table {{.Names}}\t{{.Status}}\t{{.CreatedAt}}"
```

### Specific Bot Logs

```bash
docker logs -f zoom-bot-1
```

### All Bots Logs

```bash
docker logs -f $(docker ps -q --filter "name=zoom-bot")
```

## ⚠️ Important Notes

1. **Resource Usage**: 10 bots simultaneously run karne se system resources zyada use honge
2. **Network**: Har bot ko proper network access chahiye
3. **Zoom Limits**: Zoom meeting mein participant limit check karein
4. **Port Conflicts**: Har bot ko different port chahiye (agar needed)

## 🛠️ Troubleshooting

### Bot Start Nahi Ho Raha

```bash
# Check logs
docker logs zoom-bot-1

# Check if container running
docker ps -a | grep zoom-bot
```

### Bot Meeting Join Nahi Kar Raha

- Credentials check karein
- Meeting URL verify karein
- Meeting password correct hai ya nahi

### Multiple Bots Conflict

- Har bot ko separate output directory use karna chahiye
- PulseAudio setup har container mein separate hoga

## 📊 Quick Commands Reference

```bash
# Start all bots
docker compose -f compose-multiple-bots.yaml up -d

# Stop all bots
docker compose -f compose-multiple-bots.yaml down

# View all bot logs
docker compose -f compose-multiple-bots.yaml logs -f

# Restart specific bot
docker restart zoom-bot-1

# Remove all stopped bots
docker container prune -f
```

## ✅ Success Checklist

- [ ] All 10 bots started successfully
- [ ] Each bot has different display name
- [ ] All bots joined the meeting
- [ ] Output files being created in separate folders
- [ ] No conflicts between bots

---

**Status**: ✅ Ready to run 10 bots simultaneously!

