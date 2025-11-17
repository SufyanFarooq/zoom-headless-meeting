# 🔑 ZAK Token Setup Guide

## Overview

ZAK (Zoom Access Key) tokens allow bots to join meetings with profile pictures from their Zoom accounts.

---

## 📋 Prerequisites

1. **Zoom Account with API Access** (ONE for all bots)
   - Go to https://marketplace.zoom.us/develop/create
   - Create a Server-to-Server OAuth app
   - Note down: `Account ID`, `Client ID`, `Client Secret`
   - ⚠️ **IMPORTANT:** These are the SAME for all bots (one API app manages all)

2. **Zoom User Accounts for Bots** (ONE per bot)
   - ✅ **YES, you need separate Zoom user accounts for each bot**
   - Each bot needs its own email/user account in Zoom
   - You can create them via Zoom web portal OR via API (see below)
   - Note down email addresses: `bot1@example.com`, `bot2@example.com`, etc.

3. **Profile Pictures**
   - Prepare JPG/PNG images (400x400px recommended, max 2MB)
   - Name them: `bot1.jpg`, `bot2.jpg`, etc.

---

## 🚀 Quick Setup (Automated)

### Step 1: Prepare Files

Create a `profile-pics/` directory:
```bash
mkdir profile-pics
```

Add profile pictures:
```bash
profile-pics/
  ├── bot1.jpg
  ├── bot2.jpg
  ├── bot3.jpg
  └── users.txt
```

Create `profile-pics/users.txt`:
```
bot1@example.com
bot2@example.com
bot3@example.com
```

### Step 2: Run Setup Script

```bash
./setup-bot-profiles.sh \
  YOUR_ACCOUNT_ID \
  YOUR_CLIENT_ID \
  YOUR_CLIENT_SECRET \
  ./profile-pics
```

This will:
- ✅ Upload profile pictures to Zoom accounts
- ✅ Generate ZAK tokens for each account
- ✅ Save tokens to `bot-zak-tokens.env`

---

## 🔧 Manual Setup

### Step 1: Get Access Token

```bash
./get-access-token.sh \
  YOUR_ACCOUNT_ID \
  YOUR_CLIENT_ID \
  YOUR_CLIENT_SECRET
```

Copy the access token.

### Step 2: Upload Profile Pictures

For each bot:
```bash
./upload-profile-picture.sh \
  bot1@example.com \
  profile-pics/bot1.jpg \
  YOUR_ACCESS_TOKEN
```

### Step 3: Get ZAK Tokens

For each bot:
```bash
./get-zak-token.sh \
  bot1@example.com \
  YOUR_ACCESS_TOKEN
```

Copy each ZAK token.

---

## 📝 Using ZAK Tokens in Compose

### Option 1: Environment Variables

1. Create `bot-zak-tokens.env`:
```bash
BOT1_ZAK_TOKEN=eyJ0eXAiOiJKV1QiLCJhbGc...
BOT2_ZAK_TOKEN=eyJ0eXAiOiJKV1QiLCJhbGc...
BOT3_ZAK_TOKEN=eyJ0eXAiOiJKV1QiLCJhbGc...
```

2. Update `compose-50-bots.yaml`:
```yaml
services:
  bot-1:
    env_file:
      - bot-zak-tokens.env
    command:
      - "--zak"
      - "${BOT1_ZAK_TOKEN}"
      - "--display-name"
      - "Bot-1-Alice"
```

### Option 2: Direct in Compose

```yaml
services:
  bot-1:
    command:
      - "--zak"
      - "eyJ0eXAiOiJKV1QiLCJhbGc..."  # ZAK token here
      - "--display-name"
      - "Bot-1-Alice"
```

---

## ⚠️ Important Notes

1. **Token Expiration**
   - ZAK tokens expire in 2 hours
   - Regenerate tokens before they expire
   - Use `setup-bot-profiles.sh` to regenerate all tokens

2. **Security**
   - Never commit ZAK tokens to git
   - Add `bot-zak-tokens.env` to `.gitignore`
   - Store tokens securely

3. **Profile Pictures**
   - Must be uploaded to Zoom accounts first
   - Profile pictures appear automatically when using ZAK token
   - No need to specify `--profile-picture` option (it's for future use)

---

## 🔄 Regenerating Tokens

When tokens expire, regenerate them:

```bash
# Quick regenerate (if you have access token)
./get-zak-token.sh bot1@example.com YOUR_ACCESS_TOKEN

# Or regenerate all
./setup-bot-profiles.sh ACCOUNT_ID CLIENT_ID CLIENT_SECRET ./profile-pics
```

---

## 📚 API References

- [Zoom API - Get ZAK Token](https://developers.zoom.us/docs/api/rest/reference/zoom-api/methods/#operation/userToken)
- [Zoom API - Upload Profile Picture](https://developers.zoom.us/docs/api/rest/reference/zoom-api/methods/#operation/userPicture)
- [Zoom API - Server-to-Server OAuth](https://developers.zoom.us/docs/api/rest/using-zoom-apis/#server-to-server-oauth)

---

## 🐛 Troubleshooting

### "Could not find user"
- Check email address is correct
- Ensure user account exists in your Zoom account

### "Could not get ZAK token"
- Check access token is valid (not expired)
- Ensure user has proper permissions

### "Image file too large"
- Resize image to max 2MB
- Use: `convert image.jpg -resize 400x400 -quality 85 bot1.jpg`

### Profile picture not showing
- Wait a few minutes after upload
- Ensure using ZAK token (not just meeting password)
- Check profile picture is set in Zoom web portal

