# Fast Join Optimization Guide

## Applied Optimizations

### 1. **Audio-Only: No Black Frames** ✅
- **Before:** 150 black frames + 18s mute delay = ~25s extra per bot
- **After:** Join with video OFF directly - **instant**
- **Result:** Audio-only bots join ~25 seconds faster

### 2. **ZAK Token Cache** ✅
- **Reuse:** If `bot-zak-tokens.env` exists and is < 60 min old, skip generation
- **Result:** 2nd request within 60 min = **0s** ZAK time (uses cache)
- **Env:** `ZAK_CACHE_MINUTES=60` (default)

### 3. **Single ZAK for All Bots** ✅ (Profile Pic default)
- **Before:** 1 ZAK per bot = N API calls
- **After:** 1 ZAK for all bots = **1 API call** (~2s total)
- **Trade-off:** All bots show same profile pic (first user in users.txt)
- **Default:** Auto-enabled for Profile Pic Member

### 5. **ZAK Token Parallel Generation** ✅ (when not using single ZAK)
- **Before:** Sequential ~2s per bot (150 bots = ~5 min)
- **After:** Parallel 20-50 jobs based on bot count
  - 20 bots: 10 parallel
  - 50 bots: 30 parallel  
  - 100+ bots: 50 parallel
- **Result:** 150 bots ≈ 15-20 seconds (vs 5 min)
- **Files:** `setup-flexible-bots.sh`, `generate-zak-tokens-parallel.sh`

### 2. **Normal Member (No ZAK)** ✅
- **Profile Pic Member:** Requires ZAK tokens (one per user)
- **Normal Member:** No ZAK needed = **instant** (skip token generation)
- **Use when:** Profile pic not required – saves 15-60 seconds

### 3. **Shared Build Cache** ✅
- All containers mount `/tmp/build-cache` – first container builds, rest reuse
- 150 containers: only 1st does full build (~2 min), 149 skip
- **Tip:** Pre-warm by running 1 bot first; then 150-request uses cached build

## Further Speed Tips

### Pre-generate ZAK (Manual)
Before a big run, pre-generate tokens:
```bash
# Generate tokens for first 150 users, save to bot-zak-tokens.env
./generate-zak-tokens-parallel.sh ACCOUNT_ID CLIENT_ID CLIENT_SECRET profile-pics/users.txt 50
# Tokens cached in bot-zak-tokens.env (~2hr validity)
# Next create request uses these if same meeting/session
```

### users.txt Size
- Profile Pic: Each bot needs unique user email
- 150 bots = 150 emails in `profile-pics/users.txt`
- Current: 82 emails → max 82 Profile Pic bots per meeting
- Add more emails for 150+ Profile Pic bots

### Container Startup
- **First ever run:** Build ~2 min (one-time)
- **Subsequent:** ~5-15s per batch (containers start, skip build)
- **150 containers:** Docker creates 150 – orchestration ~10-30s

## Multi-Bot Per Container (Experimental)
`bin/entry-multi-bot.sh` – run 5-10 bots in 1 container:
- Fewer containers = faster orchestration
- Requires: BOT_CONFIG_FILE, BOT_COUNT, JOIN_URL
- Not yet integrated into setup-flexible-bots.sh
- Memory: ~300MB per bot (10 bots = ~3GB per container)

## Summary: 150 Bots Quick Join

| Step | Time (Optimized) |
|------|------------------|
| ZAK (Profile Pic, 50 parallel) | ~15-20s |
| Compose + update | ~2-3s |
| Container startup (150 containers) | ~20-40s |
| **Total** | **~40-65s** |

For **Normal Member** (no ZAK): ~25-45s total.
