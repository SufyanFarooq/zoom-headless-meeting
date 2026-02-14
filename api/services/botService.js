const axios = require('axios');
const { query } = require('../db');
const { getNamesForBots } = require('./nameService');

let zoomAccessToken = null;
let zoomAccessTokenExpiry = 0;

/**
 * Calculate bot distribution based on meeting type
 * Note: Now videoCount and audioCount are passed directly from frontend
 * This function is kept for backward compatibility but may not be used
 */
function calculateBotDistribution(membersCount, meetingType) {
  let videoCount = 0;
  let audioCount = 0;
  
  switch (meetingType) {
    case 'Normal Member':
      // 50% video, 50% audio
      videoCount = Math.floor(membersCount / 2);
      audioCount = membersCount - videoCount;
      break;
      
    case 'Profile Pic Member':
      // All video (with ZAK tokens)
      videoCount = membersCount;
      audioCount = 0;
      break;
      
    default:
      // Default: 50/50 split
      videoCount = Math.floor(membersCount / 2);
      audioCount = membersCount - videoCount;
  }
  
  return { videoCount, audioCount };
}

async function getZoomAccessToken() {
  if (zoomAccessToken && Date.now() < zoomAccessTokenExpiry) return zoomAccessToken;

  const accountId = process.env.ZOOM_ACCOUNT_ID;
  const clientId = process.env.ZOOM_CLIENT_ID;
  const clientSecret = process.env.ZOOM_CLIENT_SECRET;

  if (!accountId || !clientId || !clientSecret) {
    throw new Error('Zoom API credentials not configured');
  }

  const resp = await axios.post(
    'https://zoom.us/oauth/token',
    new URLSearchParams({
      grant_type: 'account_credentials',
      account_id: accountId
    }),
    {
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        Authorization: 'Basic ' + Buffer.from(`${clientId}:${clientSecret}`).toString('base64')
      },
      timeout: 15000
    }
  );

  const token = resp.data?.access_token;
  const expiresIn = Number.parseInt(resp.data?.expires_in, 10) || 0;
  if (!token) throw new Error('Failed to get Zoom access token');

  // Refresh 60s before expiry
  zoomAccessToken = token;
  zoomAccessTokenExpiry = Date.now() + Math.max(expiresIn - 60, 60) * 1000;
  return zoomAccessToken;
}

async function fetchMeetingStatus(meetingId, token) {
  const { data } = await axios.get(`https://api.zoom.us/v2/meetings/${meetingId}`, {
    headers: { Authorization: `Bearer ${token}` },
    timeout: 15000
  });
  return String(data?.status || '').toLowerCase();
}

async function ensureMeetingStarted(meetingId) {
  try {
    const token = await getZoomAccessToken();
    const status = await fetchMeetingStatus(meetingId, token);
    if (status !== 'started') {
      const msg = status ? `Meeting hasn’t started yet (status: ${status}). Please start the meeting and try again.` : 'Meeting hasn’t started yet. Please start the meeting and try again.';
      const err = new Error(msg);
      err.code = 'MEETING_NOT_STARTED';
      throw err;
    }
    return true;
  } catch (error) {
    if (error?.code === 'MEETING_NOT_STARTED') throw error;
    if (error.response?.status === 404) {
      const err = new Error('Meeting hasn’t started yet or could not be found. Please verify the meeting ID and try again.');
      err.code = 'MEETING_NOT_STARTED';
      throw err;
    }
    if (error.response?.status === 401 || error.response?.status === 403) {
      zoomAccessToken = null;
      zoomAccessTokenExpiry = 0;
      const token = await getZoomAccessToken();
      const status = await fetchMeetingStatus(meetingId, token);
      if (status !== 'started') {
        const msg = status ? `Meeting hasn’t started yet (status: ${status}). Please start the meeting and try again.` : 'Meeting hasn’t started yet. Please start the meeting and try again.';
        const err = new Error(msg);
        err.code = 'MEETING_NOT_STARTED';
        throw err;
      }
      return true;
    }
    const msg = error.response?.data?.message || error.message || 'Failed to verify meeting status';
    throw new Error(`Failed to verify meeting status: ${msg}`);
  }
}

async function selectBestServerFromDb(membersCount) {
  // Try query with priority first (Server 1 = 1, Server 2 = 2)
  try {
    const withPriority = await query(
      `SELECT id, server_name, server_url, capacity, current_load, priority
       FROM bot_servers 
       WHERE status = 'active' 
       AND (capacity - current_load) >= $1
       ORDER BY COALESCE(priority, 100) ASC, current_load ASC
       LIMIT 1`,
      [membersCount]
    );
    if (withPriority.rows.length > 0) {
      console.log(`✅ Selected server (${withPriority.rows[0].server_name}) - Load: ${withPriority.rows[0].current_load}/${withPriority.rows[0].capacity}`);
      return withPriority.rows[0];
    }
  } catch (priorityErr) {
    if (!priorityErr.message?.includes('priority')) throw priorityErr;
    // Fallback: priority column doesn't exist
  }

  // Fallback: select without priority column
  const result = await query(
    `SELECT id, server_name, server_url, capacity, current_load
     FROM bot_servers 
     WHERE status = 'active' 
     AND (capacity - current_load) >= $1
     ORDER BY current_load ASC
     LIMIT 1`,
    [membersCount]
  );

  if (result.rows.length > 0) {
    console.log(`✅ Selected server (${result.rows[0].server_name}) - Load: ${result.rows[0].current_load}/${result.rows[0].capacity}`);
    return result.rows[0];
  }

  return null;
}

async function refreshServerLoad(serverId) {
  try {
    const serverUrl = await getBotServerUrl(serverId);
    const { data } = await axios.get(`${serverUrl}/api/bots/capacity`, { timeout: 5000 });
    const currentLoad = Number.parseInt(data?.currentLoad, 10);
    const schedulerLoad = Number.parseInt(data?.schedulerLoad, 10);
    const effectiveLoad = Number.isFinite(schedulerLoad) ? schedulerLoad : currentLoad;
    if (!Number.isFinite(effectiveLoad)) {
      console.warn(`[refreshServerLoad] Invalid load from ${serverUrl}:`, {
        currentLoad: data?.currentLoad,
        schedulerLoad: data?.schedulerLoad
      });
      return null;
    }
    await query(
      `UPDATE bot_servers 
       SET current_load = $1, last_heartbeat = NOW()
       WHERE id = $2`,
      [effectiveLoad, serverId]
    );
    return effectiveLoad;
  } catch (error) {
    console.error(`[refreshServerLoad] Failed for server ${serverId}:`, error.message);
    return null;
  }
}

async function refreshAllServerLoads() {
  try {
    const result = await query(
      `SELECT id FROM bot_servers WHERE status = 'active'`
    );
    if (result.rows.length === 0) return 0;

    const updates = await Promise.allSettled(
      result.rows.map((row) => refreshServerLoad(row.id))
    );
    return updates.filter((u) => u.status === 'fulfilled' && Number.isFinite(u.value)).length;
  } catch (error) {
    console.error('[refreshAllServerLoads] Failed:', error.message);
    return 0;
  }
}

/**
 * Select best bot server based on priority and capacity
 * Uses priority if column exists; otherwise selects by current_load
 * If none found, refreshes server loads from bot-server and retries once.
 */
async function selectBestServer(membersCount) {
  try {
    let server = await selectBestServerFromDb(membersCount);
    if (server) return server;

    console.warn('⚠️ No server capacity from DB. Refreshing server loads...');
    await refreshAllServerLoads();

    server = await selectBestServerFromDb(membersCount);
    if (server) return server;

    throw new Error('No available bot server with sufficient capacity.');
  } catch (error) {
    console.error('Error selecting bot server:', error);
    throw error;
  }
}

/**
 * Update server load after bot creation
 */
async function updateServerLoad(serverId, loadChange) {
  try {
    await query(
      `UPDATE bot_servers 
       SET current_load = GREATEST(0, current_load + $1),
           last_heartbeat = NOW()
       WHERE id = $2`,
      [loadChange, serverId]
    );
  } catch (error) {
    console.error('Error updating server load:', error);
    throw error;
  }
}

/**
 * Create bots on bot server
 * @param {number} [preferredServerId] - If provided, use this server (e.g. for refill to same server)
 */
async function createBots(meetingId, password, membersCount, videoCount, audioCount, nameType, meetingType, timeoutSeconds, preferredServerId) {
  try {
    // Validate parameters - catch mis-assigned values early
    console.log('🔍 createBots called with:', {
      meetingId,
      password: '***',
      membersCount,
      videoCount,
      audioCount,
      nameType,
      meetingType,
      timeoutSeconds,
      videoCountType: typeof videoCount,
      audioCountType: typeof audioCount,
      nameTypeType: typeof nameType,
      meetingTypeType: typeof meetingType
    });
    
    // Check if videoCount/audioCount are mis-assigned (strings that look like nameType/meetingType)
    // This MUST be checked BEFORE any other operations
    if (typeof videoCount === 'string' && (videoCount === 'Indian' || videoCount === 'International' || videoCount === 'Normal Member' || videoCount === 'Profile Pic Member')) {
      console.error('❌ CRITICAL: videoCount appears to be mis-assigned!', {
        videoCount,
        audioCount,
        nameType,
        meetingType,
        allParams: { meetingId, password, membersCount, videoCount, audioCount, nameType, meetingType, timeoutSeconds }
      });
      throw new Error(`Invalid videoCount: received "${videoCount}" but expected a number. Parameters may be in wrong order. Received: videoCount="${videoCount}", audioCount="${audioCount}", nameType="${nameType}", meetingType="${meetingType}"`);
    }
    
    if (typeof audioCount === 'string' && (audioCount === 'Indian' || audioCount === 'International' || audioCount === 'Normal Member' || audioCount === 'Profile Pic Member')) {
      console.error('❌ CRITICAL: audioCount appears to be mis-assigned!', {
        videoCount,
        audioCount,
        nameType,
        meetingType,
        allParams: { meetingId, password, membersCount, videoCount, audioCount, nameType, meetingType, timeoutSeconds }
      });
      throw new Error(`Invalid audioCount: received "${audioCount}" but expected a number. Parameters may be in wrong order. Received: videoCount="${videoCount}", audioCount="${audioCount}", nameType="${nameType}", meetingType="${meetingType}"`);
    }
    
    // Select server: use preferredServerId for refill, otherwise select best
    let server;
    if (preferredServerId) {
      const serverResult = await query('SELECT id, server_name, server_url FROM bot_servers WHERE id = $1 AND status = $2', [preferredServerId, 'active']);
      if (serverResult.rows.length === 0) throw new Error('Preferred bot server not found');
      server = serverResult.rows[0];
    } else {
      server = await selectBestServer(membersCount);
    }
    
    // Build join URL
    const joinUrl = `https://zoom.us/j/${meetingId}?pwd=${password}`;
    
    // Get Zoom API credentials from environment
    const accountId = process.env.ZOOM_ACCOUNT_ID;
    const clientId = process.env.ZOOM_CLIENT_ID;
    const clientSecret = process.env.ZOOM_CLIENT_SECRET;
    
    if (!accountId || !clientId || !clientSecret) {
      throw new Error('Zoom API credentials not configured');
    }

    // NOTE: Meeting-start check temporarily disabled (user request)
    // await ensureMeetingStarted(meetingId);
    
    // Call bot server API to create bots
    let botServerUrl = process.env.BOT_SERVER_URL || server.server_url;
    
    if (!process.env.BOT_SERVER_URL) {
    const isDocker = process.env.DB_HOST && process.env.DB_HOST !== 'localhost';
    
    if (isDocker && botServerUrl) {
      // If URL contains localhost or 127.0.0.1, replace with service name
      if (botServerUrl.includes('localhost') || botServerUrl.includes('127.0.0.1')) {
        // Extract protocol and port
        const urlMatch = botServerUrl.match(/^(https?:\/\/)([^:]+)(:\d+)?/);
        if (urlMatch) {
          const protocol = urlMatch[1];
          const port = urlMatch[3] || ':3001';
          botServerUrl = `${protocol}bot-server${port}`;
          console.log(`🔧 Fixed bot server URL for Docker: ${server.server_url} -> ${botServerUrl}`);
        }
      }
    } else if (botServerUrl && botServerUrl.includes('localhost')) {
      botServerUrl = botServerUrl.replace(/localhost/g, '127.0.0.1');
      console.log(`🔧 Fixed bot server URL: ${server.server_url} -> ${botServerUrl}`);
    }
    }
    
    // Ensure videoCount and audioCount are numbers
    // Validate inputs first
    if (typeof videoCount !== 'number' && typeof videoCount !== 'string') {
      console.error('❌ Invalid videoCount type:', typeof videoCount, videoCount);
      throw new Error(`Invalid videoCount: expected number or string, got ${typeof videoCount} (${videoCount})`);
    }
    if (typeof audioCount !== 'number' && typeof audioCount !== 'string') {
      console.error('❌ Invalid audioCount type:', typeof audioCount, audioCount);
      throw new Error(`Invalid audioCount: expected number or string, got ${typeof audioCount} (${audioCount})`);
    }
    
    // Parse videoCount and audioCount to numbers
    // If they're already numbers, parseInt will work fine
    // If they're strings that can be parsed, parseInt will work
    // If they're strings like "Indian", parseInt will return NaN
    const video = parseInt(videoCount, 10);
    const audio = parseInt(audioCount, 10);
    
    // Check for NaN immediately - this catches mis-assigned values
    if (isNaN(video) || isNaN(audio)) {
      console.error('❌ Failed to parse videoCount/audioCount:', {
        videoCount,
        audioCount,
        video,
        audio,
        videoCountType: typeof videoCount,
        audioCountType: typeof audioCount,
        allParams: { meetingId, password, membersCount, videoCount, audioCount, nameType, meetingType, timeoutSeconds }
      });
      throw new Error(`Invalid videoCount or audioCount: videoCount=${videoCount} (${typeof videoCount}), audioCount=${audioCount} (${typeof audioCount}). Parameters may be in wrong order.`);
    }
    
    // Additional check: if parsed values are 0 or negative, that's also invalid
    if (video < 0 || audio < 0 || (video === 0 && audio === 0)) {
      console.error('❌ Invalid videoCount/audioCount values:', {
        video,
        audio,
        videoCount,
        audioCount
      });
      throw new Error(`Invalid videoCount or audioCount: video=${video}, audio=${audio}. At least one must be greater than 0.`);
    }
    
    // Generate unique request ID (timestamp) to avoid conflicts when adding bots to same meeting
    // This ensures each bot creation request gets its own compose file and containers
    const requestId = Date.now().toString();
    
    // Log request payload for debugging
    console.log('📤 Sending request to bot server:', {
      url: `${botServerUrl}/api/bots/create`,
      payload: {
        meetingId,
        requestId,
        password: '***',
        joinUrl,
        videoCount: video,
        audioCount: audio,
        nameType,
        meetingType,
        accountId: '***',
        clientId: '***',
        clientSecret: '***',
        timeoutSeconds
      },
      originalParams: {
        videoCount,
        audioCount,
        nameType,
        meetingType
      }
    });
    
    // useSingleZak: 1 token for all bots = faster, but same profile pic
    // Default to false for Profile Pic Member so refill can use different ZAK tokens.
    const useSingleZak = meetingType === 'Profile Pic Member'
      ? ['1', 'true', 'yes'].includes(String(process.env.USE_SINGLE_ZAK || '').toLowerCase())
      : false;

    const response = await axios.post(`${botServerUrl}/api/bots/create`, {
      meetingId,
      requestId, // Unique ID for this bot creation request
      password,
      joinUrl,
      videoCount: video,
      audioCount: audio,
      nameType,
      meetingType,
      accountId,
      clientId,
      clientSecret,
      timeoutSeconds,
      useSingleZak
    }, {
      timeout: 180000 // 3 minute timeout (bot setup can take 2+ minutes for many bots)
    });
    
    // Update server load
    await updateServerLoad(server.id, membersCount);
    
    return {
      serverId: server.id,
      serverName: server.server_name,
      containerIds: response.data.containerIds || [],
      videoCount,
      audioCount
    };
  } catch (error) {
    console.error('Error creating bots:', error);
    if (error.response) {
      throw new Error(`Bot server error: ${error.response.data?.message || error.message}`);
    }
    throw error;
  }
}

/**
 * Get bot server URL for a server ID
 */
async function getBotServerUrl(serverId) {
  let serverUrl = process.env.BOT_SERVER_URL;
  if (!serverUrl) {
    const serverResult = await query('SELECT server_url FROM bot_servers WHERE id = $1', [serverId]);
    if (serverResult.rows.length === 0) throw new Error('Bot server not found');
    serverUrl = serverResult.rows[0].server_url;
    const isDocker = process.env.DB_HOST && process.env.DB_HOST !== 'localhost';
    if (isDocker && (serverUrl.includes('localhost') || serverUrl.includes('127.0.0.1'))) {
      const urlMatch = serverUrl.match(/^(https?:\/\/)([^:]+)(:\d+)?/);
      if (urlMatch) serverUrl = `${urlMatch[1]}bot-server${urlMatch[3] || ':3001'}`;
    } else if (serverUrl && serverUrl.includes('localhost')) {
      serverUrl = serverUrl.replace(/localhost/g, '127.0.0.1');
    }
  }
  return serverUrl;
}

/**
 * Stop bots on bot server - removes containers and deletes compose file
 */
async function stopBots(meetingId, containerIds, serverId) {
  const serverUrl = await getBotServerUrl(serverId);
  const batches = Math.ceil((containerIds?.length || 0) / 10);
  const timeoutMs = Math.min(Math.max(batches * 2000 + 30000, 60000), 600000);

  if (containerIds && containerIds.length > 0) {
    console.log(`[stopBots] Calling ${serverUrl}/api/bots/stop with ${containerIds.length} containers`);
    try {
      const res = await axios.post(`${serverUrl}/api/bots/stop`, { containerIds }, { timeout: timeoutMs });
      console.log(`[stopBots] /stop response:`, res.status, res.data?.message);
    } catch (err) {
      console.error(`[stopBots] /stop FAILED:`, err.code, err.message, err.response?.data);
      const first = containerIds[0] || '';
      const m = first.match(/^zoom-bot-(\d+)-(\d+)-\d+$/);
      if (m) {
        console.log(`[stopBots] Fallback: cleanup-compose meetingId=${m[1]} requestId=${m[2]}`);
        try {
          const res2 = await axios.post(`${serverUrl}/api/bots/cleanup-compose`, { meetingId: m[1], requestId: m[2] }, { timeout: 15000 });
          console.log(`[stopBots] cleanup-compose OK:`, res2.data);
          if (containerIds.length > 0) await updateServerLoad(serverId, -containerIds.length);
          return true;
        } catch (e2) {
          console.error(`[stopBots] cleanup-compose FAILED:`, e2.code, e2.message);
        }
      }
      throw err;
    }
  } else {
    console.log(`[stopBots] No container_ids, calling cleanup-by-meeting for ${meetingId}`);
    try {
      const res = await axios.post(`${serverUrl}/api/bots/cleanup-by-meeting`, { meetingId }, { timeout: 15000 });
      console.log(`[stopBots] cleanup-by-meeting OK:`, res.data);
    } catch (err) {
      console.error(`[stopBots] cleanup-by-meeting FAILED:`, err.code, err.message);
      throw new Error(`Cleanup failed: ${err.message}`);
    }
  }

  if (containerIds && containerIds.length > 0) {
    await updateServerLoad(serverId, -containerIds.length);
  }
  return true;
}

/**
 * Check if containers are still running (for auto-cleanup when bots leave due to timeout)
 */
async function checkContainersStatus(serverId, containerIds) {
  try {
    let serverUrl = process.env.BOT_SERVER_URL;
    if (!serverUrl) {
      const serverResult = await query(
        'SELECT server_url FROM bot_servers WHERE id = $1',
        [serverId]
      );
      if (serverResult.rows.length === 0) return { allStopped: false };
      serverUrl = serverResult.rows[0].server_url;
      const isDocker = process.env.DB_HOST && process.env.DB_HOST !== 'localhost';
      if (isDocker && (serverUrl.includes('localhost') || serverUrl.includes('127.0.0.1'))) {
        const urlMatch = serverUrl.match(/^(https?:\/\/)([^:]+)(:\d+)?/);
        if (urlMatch) serverUrl = `${urlMatch[1]}bot-server${urlMatch[3] || ':3001'}`;
      } else if (serverUrl && serverUrl.includes('localhost')) {
        serverUrl = serverUrl.replace(/localhost/g, '127.0.0.1');
      }
    }

    const { data } = await axios.post(`${serverUrl}/api/bots/containers-status`, {
      containerIds
    }, { timeout: 10000 });
    return { allStopped: data.allStopped === true };
  } catch (error) {
    console.error('[checkContainersStatus] FAILED:', error.code, error.message, error.config?.url);
    return { allStopped: false };
  }
}

module.exports = {
  createBots,
  stopBots,
  checkContainersStatus,
  calculateBotDistribution,
  selectBestServer,
  updateServerLoad
};
