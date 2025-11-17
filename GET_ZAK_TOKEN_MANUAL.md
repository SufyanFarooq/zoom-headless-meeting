# 🔑 How to Get ZAK Token Manually

## ⚠️ API Issue

ZAK token generation via API might not work for all account types. Here's how to get it manually:

---

## 📋 Method 1: Via Zoom Web Portal (Recommended)

### Step 1: Login to Zoom

1. Go to: **https://zoom.us/signin**
2. Login with: **sufyanfarooqvirtualtech@gmail.com**

### Step 2: Generate ZAK Token

1. Go to: **https://zoom.us/profile**
2. Scroll down to **"Advanced"** section
3. Look for **"Generate ZAK Token"** or **"Meeting SDK Token"**
4. Click **"Generate"**
5. Copy the token

---

## 📋 Method 2: Via Zoom API (Alternative)

If API works, use:

```bash
./get-zak-token.sh \
  sufyanfarooqvirtualtech@gmail.com \
  YOUR_ACCESS_TOKEN
```

---

## 📋 Method 3: Via Meeting Join URL

1. Create a test meeting
2. Generate join URL with ZAK token
3. Extract token from URL

---

## 💡 Quick Test

To test if ZAK token works:

```bash
# In compose file, add:
- "--zak"
- "YOUR_ZAK_TOKEN_HERE"
```

Then run bot and check if profile picture appears!

---

## 🔄 If ZAK Token Expires

ZAK tokens expire in 2 hours. Regenerate:
- Via web portal (Method 1)
- Or run script again

---

## 📝 Save Token

Once you have ZAK token, save it:

```bash
echo "BOT1_ZAK_TOKEN=YOUR_TOKEN_HERE" >> bot-zak-tokens.env
```

Then use in compose file!

