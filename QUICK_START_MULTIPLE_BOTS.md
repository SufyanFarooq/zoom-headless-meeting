# 🚀 Quick Start - 10 Bots Simultaneously

## ✅ Simple Commands

### 1. Start All 10 Bots

```bash
docker compose -f compose-multiple-bots.yaml up -d
```

Yeh command 10 bots ko simultaneously start karega with different names:
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

### 2. Check Status

```bash
# All bots ka status
docker ps | grep zoom-bot

# Specific bot ka log
docker logs -f zoom-bot-1
```

### 3. Stop All Bots

```bash
docker compose -f compose-multiple-bots.yaml down
```

## 📁 Output Files Location

Har bot ka output separate folder mein:
- `out/bot-1/` - Bot-1-Alice files
- `out/bot-2/` - Bot-2-Bob files
- `out/bot-3/` - Bot-3-Charlie files
- ... etc

## ⚙️ Customize Karne Ke Liye

### Bot Names Change Karne Ke Liye

`compose-multiple-bots.yaml` file open karein aur `--display-name` values change karein.

### Meeting URL Change Karne Ke Liye

`compose-multiple-bots.yaml` file mein `--join-url` update karein.

## 🔍 Useful Commands

```bash
# All bots logs dekhne ke liye
docker compose -f compose-multiple-bots.yaml logs -f

# Specific bot restart
docker restart zoom-bot-1

# All bots stop
docker compose -f compose-multiple-bots.yaml stop

# All bots remove
docker compose -f compose-multiple-bots.yaml down
```

---

**That's it! Ab aap 10 bots simultaneously run kar sakte hain! 🎉**

