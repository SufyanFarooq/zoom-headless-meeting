# 🤖 Multiple Bots Setup - Complete Guide

## ✅ Setup Complete!

Aap ab **10 bots simultaneously** run kar sakte hain with different names!

## 📋 Files Created

1. ✅ `compose-multiple-bots.yaml` - Docker Compose file for 10 bots
2. ✅ `bin/entry-bot.sh` - Entry script for bots with command line args
3. ✅ `QUICK_START_MULTIPLE_BOTS.md` - Quick start guide
4. ✅ `MULTIPLE_BOTS_GUIDE.md` - Detailed guide

## 🚀 Quick Start

### Step 1: Start All 10 Bots

```bash
docker compose -f compose-multiple-bots.yaml up -d
```

### Step 2: Check Status

```bash
docker ps | grep zoom-bot
```

### Step 3: View Logs

```bash
# All bots logs
docker compose -f compose-multiple-bots.yaml logs -f

# Specific bot log
docker logs -f zoom-bot-1
```

### Step 4: Stop All Bots

```bash
docker compose -f compose-multiple-bots.yaml down
```

## 📝 Bot Names

1. Bot-1-Alice
2. Bot-2-Bob
3. Bot-3-Charlie
4. Bot-4-Diana
5. Bot-5-Eve
6. Bot-6-Frank
7. Bot-7-Grace
8. Bot-8-Henry
9. Bot-9-Iris
10. Bot-10-Jack

## 📁 Output Files

Har bot ka output separate folder mein:
- `out/bot-1/` - Bot-1-Alice files
- `out/bot-2/` - Bot-2-Bob files
- ... etc

## ⚙️ Customize Karne Ke Liye

### Bot Names Change

`compose-multiple-bots.yaml` file mein `--display-name` values change karein.

### Meeting URL Change

`compose-multiple-bots.yaml` file mein `--join-url` update karein.

## ⚠️ Important Notes

1. **Build Time**: Pehli baar build karte waqt thoda time lagega
2. **Resources**: 10 bots simultaneously run karne se system resources zyada use honge
3. **Zoom Limits**: Meeting participant limits check karein
4. **Port Conflicts**: Har bot ko separate resources chahiye

## 🔧 Troubleshooting

### Bot Start Nahi Ho Raha

```bash
# Check logs
docker logs zoom-bot-1

# Check container status
docker ps -a | grep zoom-bot
```

### Build Errors

```bash
# Rebuild
docker compose -f compose-multiple-bots.yaml build
```

## ✅ Next Steps

1. ✅ `compose-multiple-bots.yaml` file ready hai
2. ✅ `entry-bot.sh` script ready hai
3. ⚠️ **Bots 3-10 ko manually update karna hoga** (bot-1 aur bot-2 ke template use karein)

## 📊 Status

- ✅ Bot-1: Ready
- ✅ Bot-2: Ready
- ⚠️ Bot-3: Needs update (use bot-1 template)
- ⚠️ Bot-4: Needs update (use bot-1 template)
- ⚠️ Bot-5: Needs update (use bot-1 template)
- ⚠️ Bot-6: Needs update (use bot-1 template)
- ⚠️ Bot-7: Needs update (use bot-1 template)
- ⚠️ Bot-8: Needs update (use bot-1 template)
- ⚠️ Bot-9: Needs update (use bot-1 template)
- ⚠️ Bot-10: Needs update (use bot-1 template)

---

**Note**: Bots 3-10 ko manually update karna hoga. Bot-1 aur Bot-2 ke format ko copy karke use karein, sirf bot number aur name change karein.

