# 🚀 Run 50 Bots - Quick Guide

## ✅ Step 1: File Generated Successfully!

`compose-50-bots.yaml` file generate ho gaya hai with 50 bots!

## 🚀 Step 2: Run All 50 Bots

```bash
docker compose -f compose-50-bots.yaml up -d
```

Yeh command:
- All 50 bots ko simultaneously start karega
- Background mein run hoga (-d flag)
- Har bot ko different name milega (Bot-1-Alice, Bot-2-Bob, etc.)

## 📊 Step 3: Check Status

```bash
# Count running bots
docker ps | grep zoom-bot | wc -l

# View all bots
docker ps | grep zoom-bot

# Check resource usage
docker stats --no-stream | grep zoom-bot | head -10
```

## 🔍 Step 4: Monitor Logs

```bash
# View specific bot log
docker logs zoom-bot-1
docker logs zoom-bot-25
docker logs zoom-bot-50

# View all logs
docker compose -f compose-50-bots.yaml logs -f
```

## 🛑 Step 5: Stop All Bots

```bash
# Stop all 50 bots
docker compose -f compose-50-bots.yaml down

# Or use script
./stop-bots.sh 50
```

## 📈 Expected Results

- **50 bots** will join the meeting
- Each with **unique name** (Bot-1-Alice to Bot-50-Xara)
- **CPU usage**: ~350-400% (3.5-4 cores)
- **Memory usage**: ~4.5 GB
- **Status**: ✅ Within limits

## ⚠️ Important Notes

1. **First run**: Build time lagega (10-15 minutes)
2. **Resource usage**: 50 bots = ~4 cores CPU, ~4.5 GB memory
3. **Network**: Ensure stable internet connection
4. **Zoom limits**: Check meeting participant limits

## 🎯 Quick Commands

```bash
# Run 50 bots
docker compose -f compose-50-bots.yaml up -d

# Check status
docker ps | grep zoom-bot | wc -l

# View logs
docker logs zoom-bot-1

# Stop all
docker compose -f compose-50-bots.yaml down
```

---

**Ready to run!** 🚀

