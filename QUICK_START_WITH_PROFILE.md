# 🚀 Quick Start: Bots with Profile Pictures

## 📋 Workflow Summary

**Har baar bots bhejne se pehle ZAK tokens generate karein!**

ZAK tokens expire hote hain (usually 2 hours), isliye har baar fresh tokens chahiye.

---

## ⚡ Quick Commands

### Step 1: Generate ZAK Tokens (Required)

```bash
./auto-setup-all-bots.sh \
  kOjrXedBRwGlbGiCyzQOyQ \
  9bk9CyXgSgqggGe5InpVMA \
  OiftYuJ6cM6QtDbex64P4T6MM5q1JEBS
```

**Yeh command:**
- ✅ Reads emails from `profile-pics/users.txt`
- ✅ Generates fresh ZAK tokens for all users
- ✅ Updates `compose-50-bots.yaml` automatically
- ✅ Saves tokens to `bot-zak-tokens.env`

### Step 2: Run Bots

```bash
docker compose -f compose-50-bots.yaml up --build
```

---

## 🔄 Complete Workflow

### First Time Setup (Ek baar)

1. **Create Zoom Users:**
   ```bash
   ./create-zoom-users.sh \
     kOjrXedBRwGlbGiCyzQOyQ \
     9bk9CyXgSgqggGe5InpVMA \
     OiftYuJ6cM6QtDbex64P4T6MM5q1JEBS
   ```

2. **Upload Profile Pictures:**
   ```bash
   ./update-profile-pictures.sh \
     kOjrXedBRwGlbGiCyzQOyQ \
     9bk9CyXgSgqggGe5InpVMA \
     OiftYuJ6cM6QtDbex64P4T6MM5q1JEBS
   ```

### Every Time You Run Bots (Har baar)

1. **Generate Fresh ZAK Tokens:**
   ```bash
   ./auto-setup-all-bots.sh \
     kOjrXedBRwGlbGiCyzQOyQ \
     9bk9CyXgSgqggGe5InpVMA \
     OiftYuJ6cM6QtDbex64P4T6MM5q1JEBS
   ```

2. **Run Bots:**
   ```bash
   docker compose -f compose-50-bots.yaml up --build
   ```

---

## 📝 File Structure

```
profile-pics/
├── users.txt          ← Bot emails (one per line)
├── bot1.jpg          ← Profile picture for first email
├── bot2.jpg          ← Profile picture for second email
└── ...

bot-zak-tokens.env    ← Auto-generated ZAK tokens
compose-50-bots.yaml   ← Auto-updated with ZAK tokens
```

---

## ⚠️ Important Notes

### ZAK Token Expiration

- **ZAK tokens expire in ~2 hours**
- **Har baar bots run karne se pehle fresh tokens generate karein**
- Old tokens se bots join nahi honge

### When to Regenerate Tokens

✅ **Regenerate if:**
- 2+ hours passed since last generation
- Bots fail to join with "Invalid token" error
- Starting new bot session

❌ **No need to regenerate if:**
- Tokens just generated (< 2 hours ago)
- Bots are already running successfully

---

## 🎯 One-Line Quick Start

```bash
# Generate tokens + Run bots (all in one)
./auto-setup-all-bots.sh ACCOUNT_ID CLIENT_ID CLIENT_SECRET && \
docker compose -f compose-50-bots.yaml up --build
```

---

## 🔧 Troubleshooting

### "Invalid token" Error

**Solution:** Regenerate ZAK tokens
```bash
./auto-setup-all-bots.sh ACCOUNT_ID CLIENT_ID CLIENT_SECRET
```

### "User does not exist" Error

**Solution:** Create users first
```bash
./create-zoom-users.sh ACCOUNT_ID CLIENT_ID CLIENT_SECRET
```

### Profile Picture Not Showing

**Solution:** Upload profile pictures
```bash
./update-profile-pictures.sh ACCOUNT_ID CLIENT_ID CLIENT_SECRET
```

---

## 📚 Related Scripts

- `auto-setup-all-bots.sh` - Complete setup (users + pics + tokens)
- `auto-setup-bots.sh` - Generate ZAK tokens only
- `update-profile-pictures.sh` - Update profile pictures
- `update-compose-with-zak.sh` - Update compose file with tokens

---

## 💡 Pro Tips

1. **Save API Credentials:**
   ```bash
   # Create .env file (don't commit!)
   echo "ACCOUNT_ID=kOjrXedBRwGlbGiCyzQOyQ" > .env
   echo "CLIENT_ID=9bk9CyXgSgqggGe5InpVMA" >> .env
   echo "CLIENT_SECRET=OiftYuJ6cM6QtDbex64P4T6MM5q1JEBS" >> .env
   ```

2. **Use Alias:**
   ```bash
   # Add to ~/.bashrc or ~/.zshrc
   alias setup-bots='./auto-setup-all-bots.sh kOjrXedBRwGlbGiCyzQOyQ 9bk9CyXgSgqggGe5InpVMA OiftYuJ6cM6QtDbex64P4T6MM5q1JEBS'
   
   # Then just run:
   setup-bots && docker compose -f compose-50-bots.yaml up --build
   ```

3. **Check Token Expiration:**
   ```bash
   # ZAK tokens are JWT - decode to see expiration
   # Or just regenerate if unsure!
   ```

---

## ✅ Summary

**Har baar bots bhejne se pehle:**
1. Run: `./auto-setup-all-bots.sh ACCOUNT_ID CLIENT_ID CLIENT_SECRET`
2. Run: `docker compose -f compose-50-bots.yaml up --build`

**That's it!** 🎉

