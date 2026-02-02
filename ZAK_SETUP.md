# ZAK Token Setup (Profile Pic Members)

## Different Profile Pic Per Bot

For **different profile pics per bot**, you need **1 ZAK per bot** (each from a different Zoom user):

- **Option A – Server-to-Server (S2S):** Uses `profile-pics/users.txt` and generates ZAK per email. Works only if your Zoom app supports S2S for ZAK (no error 2300).
- **Option B – Multiple User OAuth tokens:** Set `ZOOM_REFRESH_TOKENS` (comma-separated) or `ZOOM_REFRESH_TOKENS_FILE` (one refresh token per line). Do OAuth once per bot account.

With only 1 ZAK token, all bots share the same profile pic.

---

## Error 2300: "This API endpoint is not recognized"

This occurs when using **Server-to-Server OAuth** to generate ZAK tokens. Zoom's ZAK endpoint requires **User OAuth** (OAuth 2.0 with user consent).

## Solution: Use User OAuth

### 1. Create OAuth 2.0 App (if not already)

1. Go to [Zoom Marketplace](https://marketplace.zoom.us/) → Your Apps → Create → **OAuth** (not Server-to-Server)
2. Add scopes: `user:read:zak`, `user:read`
3. Add redirect URL (e.g. `http://localhost:3000/callback`)
4. Note **Client ID** and **Client Secret**

### 2. Get Refresh Token

Run OAuth flow once for your bot user (e.g. first email in `profile-pics/users.txt`):

```bash
# Get authorization URL (replace CLIENT_ID and REDIRECT_URI)
echo "Visit: https://zoom.us/oauth/authorize?response_type=code&client_id=YOUR_CLIENT_ID&redirect_uri=YOUR_REDIRECT_URI&scope=user:read:zak%20user:read"
```

After user authorizes, exchange the `code` for refresh_token:

```bash
curl -X POST "https://zoom.us/oauth/token" \
  -H "Authorization: Basic $(echo -n 'CLIENT_ID:CLIENT_SECRET' | base64)" \
  -d "grant_type=authorization_code&code=CODE_FROM_REDIRECT&redirect_uri=YOUR_REDIRECT_URI"
```

Save the `refresh_token` from the response.

### 3. Add to .env

**Single profile pic for all bots:**
```env
ZOOM_REFRESH_TOKEN=your_refresh_token_here
```

**Different profile pic per bot (multiple refresh tokens):**
```env
ZOOM_REFRESH_TOKEN=first_token
ZOOM_REFRESH_TOKENS=token1,token2,token3,...
# Or use a file (one token per line):
ZOOM_REFRESH_TOKENS_FILE=profile-pics/refresh-tokens.txt
```

### 4. Pre-Generate Job

The bot-server runs a job every 2 hours to refresh ZAK and save to `zak-token.env`. Meeting creation uses this file (no API call at submit time = faster).

- First run: 30 seconds after bot-server start
- Then: every 2 hours
- File: `zak-token.env` in project root
- With **S2S**: generates ZAK per user from `profile-pics/users.txt` (up to 50)
