const axios = require('axios');
const { query } = require('../db');
const { getNamesForBots } = require('./nameService');

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

/**
 * Select best bot server based on priority and capacity
 * Priority: Server 1 (priority=1) is used first, then Server 2 (priority=2)
 * Only moves to Server 2 when Server 1 is full
 */
async function selectBestServer(membersCount) {
  try {
    // First, try Server 1 (priority = 1)
    const server1Result = await query(
      `SELECT id, server_name, server_url, capacity, current_load, priority
       FROM bot_servers 
       WHERE status = 'active' 
       AND priority = 1
       AND (capacity - current_load) >= $1
       ORDER BY current_load ASC
       LIMIT 1`,
      [membersCount]
    );
    
    if (server1Result.rows.length > 0) {
      console.log(`✅ Selected Server 1 (${server1Result.rows[0].server_name}) - Load: ${server1Result.rows[0].current_load}/${server1Result.rows[0].capacity}`);
      return server1Result.rows[0];
    }
    
    // Server 1 is full, try Server 2 (priority = 2)
    console.log('⚠️  Server 1 is full, trying Server 2...');
    const server2Result = await query(
      `SELECT id, server_name, server_url, capacity, current_load, priority
       FROM bot_servers 
       WHERE status = 'active' 
       AND priority = 2
       AND (capacity - current_load) >= $1
       ORDER BY current_load ASC
       LIMIT 1`,
      [membersCount]
    );
    
    if (server2Result.rows.length > 0) {
      console.log(`✅ Selected Server 2 (${server2Result.rows[0].server_name}) - Load: ${server2Result.rows[0].current_load}/${server2Result.rows[0].capacity}`);
      return server2Result.rows[0];
    }
    
    // No server available
    throw new Error('No available bot server with sufficient capacity. Server 1 and Server 2 are both full.');
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
 */
async function createBots(meetingId, password, membersCount, videoCount, audioCount, nameType, meetingType, timeoutSeconds) {
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
    
    // Select best server
    const server = await selectBestServer(membersCount);
    
    // Build join URL
    const joinUrl = `https://zoom.us/j/${meetingId}?pwd=${password}`;
    
    // Get Zoom API credentials from environment
    const accountId = process.env.ZOOM_ACCOUNT_ID;
    const clientId = process.env.ZOOM_CLIENT_ID;
    const clientSecret = process.env.ZOOM_CLIENT_SECRET;
    
    if (!accountId || !clientId || !clientSecret) {
      throw new Error('Zoom API credentials not configured');
    }
    
    // Call bot server API to create bots
    let botServerUrl = server.server_url;
    
    // Fix Docker networking: In Docker Compose, containers communicate via service names
    // Replace localhost/127.0.0.1 with service name for internal Docker network
    // Check if we're running in Docker (via environment or network)
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
      // For non-Docker or external access, use 127.0.0.1 instead of localhost
      botServerUrl = botServerUrl.replace(/localhost/g, '127.0.0.1');
      console.log(`🔧 Fixed bot server URL: ${server.server_url} -> ${botServerUrl}`);
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
    
    // Log request payload for debugging
    console.log('📤 Sending request to bot server:', {
      url: `${botServerUrl}/api/bots/create`,
      payload: {
        meetingId,
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
    
    const response = await axios.post(`${botServerUrl}/api/bots/create`, {
      meetingId,
      password,
      joinUrl,
      videoCount: video,
      audioCount: audio,
      nameType,
      meetingType,
      accountId,
      clientId,
      clientSecret,
      timeoutSeconds
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
 * Stop bots on bot server
 */
async function stopBots(meetingId, containerIds, serverId) {
  try {
    // Get server info
    const serverResult = await query(
      'SELECT server_url FROM bot_servers WHERE id = $1',
      [serverId]
    );
    
    if (serverResult.rows.length === 0) {
      throw new Error('Bot server not found');
    }
    
    let serverUrl = serverResult.rows[0].server_url;
    
    // Fix Docker networking
    const isDocker = process.env.DB_HOST && process.env.DB_HOST !== 'localhost';
    
    if (isDocker && serverUrl) {
      if (serverUrl.includes('localhost') || serverUrl.includes('127.0.0.1')) {
        const urlMatch = serverUrl.match(/^(https?:\/\/)([^:]+)(:\d+)?/);
        if (urlMatch) {
          const protocol = urlMatch[1];
          const port = urlMatch[3] || ':3001';
          serverUrl = `${protocol}bot-server${port}`;
        }
      }
    } else if (serverUrl && serverUrl.includes('localhost')) {
      serverUrl = serverUrl.replace(/localhost/g, '127.0.0.1');
    }
    
    // Call bot server API to stop bots
    // Calculate timeout: 
    // - For parallel batching: ~2 seconds per batch (10 containers) + buffer
    // - Minimum 60 seconds, maximum 10 minutes
    // - For 80 bots: ~16 batches = 32 seconds + 30s buffer = 62 seconds minimum
    const batches = Math.ceil(containerIds.length / 10);
    const timeoutMs = Math.min(Math.max(batches * 2000 + 30000, 60000), 600000);
    
    await axios.post(`${serverUrl}/api/bots/stop`, {
      containerIds
    }, {
      timeout: timeoutMs
    });
    
    // Update server load
    if (containerIds && containerIds.length > 0) {
      await updateServerLoad(serverId, -containerIds.length);
    }
    
    return true;
  } catch (error) {
    console.error('Error stopping bots:', error);
    throw error;
  }
}

module.exports = {
  createBots,
  stopBots,
  calculateBotDistribution,
  selectBestServer,
  updateServerLoad
};

