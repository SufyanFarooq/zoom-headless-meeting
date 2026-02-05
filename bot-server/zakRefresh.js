/**
 * ZAK Token Pre-Generate Job
 * Uses cron to refresh ZAK and save to file.
 * Meeting creation uses this file instead of generating at submit time (faster).
 *
 * Requires ONE of:
 * A) User OAuth: ZOOM_REFRESH_TOKEN + ZOOM_CLIENT_ID + ZOOM_CLIENT_SECRET (recommended for ZAK)
 * B) Server-to-Server: ZOOM_ACCOUNT_ID + ZOOM_CLIENT_ID + ZOOM_CLIENT_SECRET + ZOOM_BOT_EMAIL
 *
 * Note: Server-to-Server OAuth may return error 2300 for ZAK - use User OAuth for Profile Pic.
 */

const axios = require('axios');
const cron = require('node-cron');
const fs = require('fs');
const path = require('path');

const ZAK_FILE = process.env.ZAK_TOKEN_FILE || 'zak-token.env';
const MAX_AGE_MINUTES = 90; // Refresh if older (ZAK lasts 2h)

async function getAccessTokenFromRefresh() {
  const ZOOM_REFRESH_TOKEN = process.env.ZOOM_REFRESH_TOKEN;
  const clientId = process.env.ZOOM_OAUTH_CLIENT_ID || process.env.ZOOM_CLIENT_ID;
  const clientSecret = process.env.ZOOM_OAUTH_CLIENT_SECRET || process.env.ZOOM_CLIENT_SECRET;
  if (!ZOOM_REFRESH_TOKEN || !clientId || !clientSecret) return null;

  const resp = await axios.post(
    'https://zoom.us/oauth/token',
    new URLSearchParams({
      grant_type: 'refresh_token',
      refresh_token: ZOOM_REFRESH_TOKEN,
    }),
    {
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        Authorization: 'Basic ' + Buffer.from(`${clientId}:${clientSecret}`).toString('base64'),
      },
      timeout: 30000,
    }
  );
  return resp.data?.access_token || null;
}

async function getAccessTokenS2S() {
  const { ZOOM_ACCOUNT_ID, ZOOM_CLIENT_ID, ZOOM_CLIENT_SECRET } = process.env;
  if (!ZOOM_ACCOUNT_ID || !ZOOM_CLIENT_ID || !ZOOM_CLIENT_SECRET) return null;

  const resp = await axios.post(
    'https://zoom.us/oauth/token',
    new URLSearchParams({
      grant_type: 'account_credentials',
      account_id: ZOOM_ACCOUNT_ID,
    }),
    {
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        Authorization: 'Basic ' + Buffer.from(`${ZOOM_CLIENT_ID}:${ZOOM_CLIENT_SECRET}`).toString('base64'),
      },
      timeout: 30000,
    }
  );
  return resp.data?.access_token || null;
}

const API_TIMEOUT = 30000;

async function getZakToken(accessToken, userId = 'me') {
  const url = userId === 'me'
    ? 'https://api.zoom.us/v2/users/me/token?type=zak'
    : `https://api.zoom.us/v2/users/${userId}/token?type=zak`;
  const resp = await axios.get(url, {
    headers: { Authorization: `Bearer ${accessToken}` },
    timeout: API_TIMEOUT,
  });
  return resp.data?.token || null;
}

async function getUserIdFromEmail(accessToken, email) {
  const resp = await axios.get(`https://api.zoom.us/v2/users/${encodeURIComponent(email)}`, {
    headers: { Authorization: `Bearer ${accessToken}` },
    timeout: API_TIMEOUT,
  });
  return resp.data?.id || null;
}

async function getZakForEmail(accessToken, email) {
  try {
    const userId = await getUserIdFromEmail(accessToken, email);
    if (!userId) return null;
    const zak = await getZakToken(accessToken, userId);
    return zak || null;
  } catch (e) {
    if (e.response?.data?.code === 2300) throw e;
    return null;
  }
}

function readUsersFile(projectDir) {
  const usersPath = path.join(projectDir, 'profile-pics', 'users.txt');
  if (!fs.existsSync(usersPath)) return [];
  const raw = fs.readFileSync(usersPath, 'utf8');
  return raw
    .split('\n')
    .map(line => line.trim())
    .filter(line => line && !line.startsWith('#') && line.includes('@'));
}

async function refreshZak() {
  const projectDir = process.env.BOT_PROJECT_DIR || path.join(__dirname, '..');
  const zakPath = path.join(projectDir, ZAK_FILE);
  const maxBots = parseInt(process.env.ZAK_MAX_BOTS || '0', 10) || 0; // 0 = no limit, process all emails

  const hasRefresh = !!process.env.ZOOM_REFRESH_TOKEN;
  const hasS2S = !!(process.env.ZOOM_ACCOUNT_ID && process.env.ZOOM_CLIENT_ID && process.env.ZOOM_CLIENT_SECRET);
  const forceRefresh = process.env.ZAK_USE_REFRESH_ONLY === '1' || process.env.ZAK_USE_REFRESH_ONLY === 'true';
  // When users.txt has emails: use S2S to generate 1 ZAK per email (different profile pic each). Extra bots join as guests.
  const emails = readUsersFile(projectDir);
  const wantMulti = emails.length > 1;
  const tryS2SFirst = hasS2S && wantMulti && !forceRefresh;

  if (!hasRefresh && !hasS2S) {
    console.log('[ZAK-REFRESH] Skipped: set ZOOM_REFRESH_TOKEN or ZOOM_ACCOUNT_ID+CLIENT_ID+CLIENT_SECRET');
    return false;
  }
  if (wantMulti && !hasS2S) {
    console.log(`[ZAK-REFRESH] ${emails.length} emails in users.txt - for different profile per bot, add ZOOM_ACCOUNT_ID, ZOOM_CLIENT_ID, ZOOM_CLIENT_SECRET (S2S)`);
  }

  try {
    let accessToken;
    let zakList = [];

    if (tryS2SFirst) {
      accessToken = await getAccessTokenS2S();
      if (!accessToken) {
        console.error('[ZAK-REFRESH] S2S access token failed, falling back to User OAuth...');
      } else {
      const emails = readUsersFile(projectDir);
      const toProcess = maxBots > 0 ? emails.slice(0, maxBots) : emails;
      if (toProcess.length === 0) {
        console.error('[ZAK-REFRESH] No emails in profile-pics/users.txt');
        return false;
      }
      const PARALLEL = parseInt(process.env.ZAK_PARALLEL || '10', 10) || 10;
      const batches = [];
      for (let i = 0; i < toProcess.length; i += PARALLEL) {
        batches.push(toProcess.slice(i, i + PARALLEL));
      }
      for (let b = 0; b < batches.length; b++) {
        const batch = batches[b];
        try {
          const results = await Promise.all(
            batch.map((email) => getZakForEmail(accessToken, email))
          );
          for (const zak of results) {
            if (zak) zakList.push(zak);
          }
        } catch (e) {
          if (e.response?.data?.code === 2300) {
            console.error('[ZAK-REFRESH] S2S ZAK not supported (2300). Falling back to User OAuth...');
            zakList.length = 0;
          }
          break;
        }
        const done = Math.min((b + 1) * PARALLEL, toProcess.length);
        if (done % 20 === 0 || done === toProcess.length) {
          console.log(`[ZAK-REFRESH] S2S: ${done}/${toProcess.length} done (parallel ${PARALLEL})`);
        }
      }
      if (zakList.length > 0) {
        console.log(`[ZAK-REFRESH] S2S: generated ${zakList.length} ZAK tokens for ${toProcess.length} users`);
      }
      }
    }

    if (zakList.length === 0 && hasRefresh) {
      console.log('[ZAK-REFRESH] Using User OAuth (1 ZAK)...');
      accessToken = await getAccessTokenFromRefresh();
      if (!accessToken) {
        console.error('[ZAK-REFRESH] Failed to get access token from refresh_token');
        return false;
      }
      const zak = await getZakToken(accessToken, 'me');
      if (zak) zakList.push(zak);
      console.log(`[ZAK-REFRESH] User OAuth: ${zakList.length} ZAK (same profile pic for all)`);
    }

    if (zakList.length === 0) {
      console.error('[ZAK-REFRESH] No ZAK tokens generated');
      return false;
    }

    // Only BOT1_ZAK_TOKEN ... BOTn_ZAK_TOKEN (no redundant ZAK_TOKEN - setup uses BOT1 for single-ZAK)
    const lines = [`# ZAK tokens (pre-generated, valid ~2h)`, `# Generated: ${new Date().toISOString()}`, `# Count: ${zakList.length}`];
    zakList.forEach((zak, i) => { lines.push(`BOT${i + 1}_ZAK_TOKEN=${zak}`); });
    const content = lines.join('\n') + '\n';
    fs.writeFileSync(zakPath, content, 'utf8');
    console.log(`[ZAK-REFRESH] Saved ${zakList.length} ZAK to`, zakPath);
    return true;
  } catch (err) {
    const msg = err.response?.data?.message || err.message;
    const code = err.response?.data?.code;
    console.error('[ZAK-REFRESH] Error:', code ? `(${code})` : '', msg);
    if (code === 2300) {
      console.error('[ZAK-REFRESH] S2S ZAK not supported. Use ZOOM_REFRESH_TOKEN (User OAuth).');
    }
    return false;
  }
}


//  * Convert interval minutes to cron expression.
//  * Examples: 5 -> "*/5 * * * *", 120 -> "0 */2 * * *"

function minutesToCron(minutes) {
  const m = Math.max(1, Math.floor(minutes));
  if (m < 60) return `*/${m} * * * *`;
  const hours = Math.floor(m / 60);
  return `0 */${hours} * * *`;
}

function startZakRefreshJob() {
  const intervalMin = parseInt(process.env.ZAK_REFRESH_INTERVAL_MINUTES || '120', 10) || 120;
  const cronExpr = minutesToCron(intervalMin);

  const run = () => {
    refreshZak().catch((err) => {
      console.error('[ZAK-REFRESH] Job error:', err.message);
    });
  };

  if (!cron.validate(cronExpr)) {
    console.error('[ZAK-REFRESH] Invalid cron expression, using */5 * * * * (every 5 min)');
    cron.schedule('*/5 * * * *', run);
  } else {
    cron.schedule(cronExpr, run);
  }

  const label = intervalMin < 60 ? `every ${intervalMin}m` : `every ${Math.floor(intervalMin / 60)}h`;
  console.log(`[ZAK-REFRESH] Cron job: ${label} (${cronExpr})`);

  setTimeout(run, 10000);
}

module.exports = { refreshZak, startZakRefreshJob };
