# 🚀 Quick Start - 50 Bots

## ✅ Smart Solution Ready!

Ab aap **loop/array-based approach** use kar sakte hain - no code repetition!

## 📋 Commands

### Method 1: Generate Compose File (Recommended)

```bash
# Step 1: Generate compose file for 50 bots
./generate-bots.sh 50

# Step 2: Run all 50 bots
docker compose -f compose-50-bots.yaml up -d

# Step 3: Check status
docker ps | grep zoom-bot | wc -l

# Step 4: Stop all bots
docker compose -f compose-50-bots.yaml down
```

### Method 2: Direct Run (Faster, No Compose File)

```bash
# Run 50 bots directly
./run-bots.sh 50

# Check status
docker ps | grep zoom-bot | wc -l

# Stop all bots
./stop-bots.sh 50
```

## 🎯 Key Features

✅ **Loop-Based** - No code repetition
✅ **Array of Names** - 50 unique names
✅ **Dynamic** - Easy to change number of bots
✅ **Optimized** - All optimizations included

## 📊 Bot Names

Each bot gets unique name:
- Bot-1-Alice
- Bot-2-Bob
- Bot-3-Charlie
- ...
- Bot-50-Xara

## ⚙️ Customize

### Different Number of Bots:
```bash
# 100 bots
./generate-bots.sh 100
docker compose -f compose-50-bots.yaml up -d
```

### Different Meeting URL:
```bash
# Custom URL
./generate-bots.sh 50 "your-meeting-url"
./run-bots.sh 50 "your-meeting-url"
```

## 🔍 Monitor

```bash
# Count running bots
docker ps | grep zoom-bot | wc -l

# Check resource usage
docker stats --no-stream | grep zoom-bot | head -10

# View logs
docker logs zoom-bot-1
```

## ✅ Summary

**Before**: 355 lines for 10 bots (repetitive)
**After**: Smart script - generates any number of bots!

**Command for 50 bots**:
```bash
./generate-bots.sh 50
docker compose -f compose-50-bots.yaml up -d
```

🎉 **Ab aap easily 50+ bots run kar sakte hain!**

