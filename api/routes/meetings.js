const express = require('express');
const router = express.Router();
const { query } = require('../db');
const { validateMembersCount, updateUsage, decreaseUsage } = require('../services/usageService');
const { createBots, stopBots } = require('../services/botService');

function isTrue(val) {
  if (val === true) return true;
  if (val === false || val == null) return false;
  return ['1', 'true', 'yes', 'y', 'on'].includes(String(val).toLowerCase());
}

/**
 * POST /api/meetings - Create a new meeting
 */
router.post('/', async (req, res) => {
  try {
    const { meetingId, password, membersCount, videoCount, audioCount, nameType, meetingType, timeoutSeconds } = req.body;
    
    // Validate required fields
    if (!meetingId || !password || !membersCount || !nameType || !meetingType) {
      return res.status(400).json({ 
        error: 'Missing required fields: meetingId, password, membersCount, nameType, meetingType' 
      });
    }
    
    // Validate video and audio counts
    const video = parseInt(videoCount) || 0;
    const audio = parseInt(audioCount) || 0;
    const total = parseInt(membersCount);
    
    if (video < 0 || audio < 0) {
      return res.status(400).json({ 
        error: 'Video and audio counts must be 0 or greater' 
      });
    }
    
    if ((video + audio) !== total) {
      return res.status(400).json({ 
        error: 'Video count + Audio count must equal Total members' 
      });
    }
    
    // Validate members count
    const validation = await validateMembersCount(total);
    if (!validation.valid) {
      return res.status(400).json({ 
        error: 'Validation failed',
        errors: validation.errors
      });
    }

    const maxLimit = req.user?.max_members_limit;
    if (maxLimit && total > maxLimit) {
      return res.status(400).json({
        error: 'Max members limit exceeded',
        message: `Your account limit is ${maxLimit} members per meeting.`,
        limit: maxLimit
      });
    }
    
    // Create bots on bot server
    const botResult = await createBots(
      meetingId,
      password,
      total,
      video,
      audio,
      nameType,
      meetingType,
      timeoutSeconds || 7200
    );
    
    // Store meeting in database (with user who created it)
    const userId = req.user?.id || null;
    const meetingResult = await query(
      `INSERT INTO meetings 
       (meeting_id, password, members_count, name_type, meeting_type, status, 
        timeout_seconds, bot_server_id, request_id, container_ids, video_count, audio_count, started_at, user_id)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, NOW(), $13)
       RETURNING *`,
      [
        meetingId,
        password,
        parseInt(membersCount),
        nameType,
        meetingType,
        'active',
        timeoutSeconds || 7200,
        botResult.serverId,
        botResult.requestId,
        botResult.containerIds,
        botResult.videoCount,
        botResult.audioCount,
        userId
      ]
    );
    
    // Update usage
    await updateUsage(parseInt(membersCount));
    
    res.status(201).json({
      success: true,
      meeting: meetingResult.rows[0],
      botServer: botResult.serverName
    });
  } catch (error) {
    console.error('Error creating meeting:', error);
    if (error.code === 'MEETING_NOT_STARTED') {
      return res.status(400).json({
        error: 'Meeting not started',
        message: error.message
      });
    }
    res.status(500).json({ 
      error: 'Failed to create meeting',
      message: error.message 
    });
  }
});

/**
 * GET /api/meetings - Get all meetings
 */
router.get('/', async (req, res) => {
  try {
    const { status } = req.query;
    const userId = req.user?.id;
    
    let queryText = 'SELECT * FROM meetings';
    let params = [];
    
    if (userId) {
      queryText += ' WHERE user_id = $1';
      params.push(userId);
    }
    if (status) {
      queryText += (params.length ? ' AND' : ' WHERE') + ' status = $' + (params.length + 1);
      params.push(status);
    }
    queryText += ' ORDER BY created_at DESC';
    
    const result = await query(queryText, params);
    
    res.json({
      success: true,
      meetings: result.rows,
      count: result.rows.length
    });
  } catch (error) {
    console.error('Error getting meetings:', error);
    res.status(500).json({ 
      error: 'Failed to get meetings',
      message: error.message 
    });
  }
});

/**
 * POST /api/meetings/:id/refill - Copy meeting details and create new meeting request (same meeting ID, same bots count)
 * Does NOT merge/sum with existing record - creates a fresh meeting row
 */
router.post('/:id/refill', async (req, res) => {
  try {
    const meetingResult = await query(
      'SELECT * FROM meetings WHERE id = $1',
      [req.params.id]
    );
    if (meetingResult.rows.length === 0) {
      return res.status(404).json({ error: 'Meeting not found' });
    }
    const src = meetingResult.rows[0];
    if (src.status !== 'active') {
      return res.status(400).json({ error: 'Meeting is not active' });
    }
    if (src.user_id && req.user?.id && src.user_id !== req.user.id) {
      return res.status(403).json({ error: 'Not allowed to refill this meeting' });
    }

    const membersCount = parseInt(src.members_count);
    const maxLimit = req.user?.max_members_limit;
    if (maxLimit && membersCount > maxLimit) {
      return res.status(400).json({
        error: 'Max members limit exceeded',
        message: `Your account limit is ${maxLimit} members per meeting.`,
        limit: maxLimit
      });
    }
    const video = 0;
    const audio = membersCount;

    const botResult = await createBots(
      src.meeting_id,
      src.password,
      membersCount,
      video,
      audio,
      src.name_type,
      src.meeting_type,
      src.timeout_seconds || 7200
    );

    const userId = req.user?.id || src.user_id || null;
    await query(
      `INSERT INTO meetings 
       (meeting_id, password, members_count, name_type, meeting_type, status, 
        timeout_seconds, bot_server_id, request_id, container_ids, video_count, audio_count, started_at, user_id)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, NOW(), $13)
       RETURNING *`,
      [
        src.meeting_id,
        src.password,
        membersCount,
        src.name_type,
        src.meeting_type,
        'active',
        src.timeout_seconds || 7200,
        botResult.serverId,
        botResult.requestId,
        botResult.containerIds,
        video,
        audio,
        userId
      ]
    );

    await updateUsage(membersCount);

    res.json({
      success: true,
      added: membersCount,
      message: `Refill: ${membersCount} bots added to meeting ${src.meeting_id}`
    });
  } catch (error) {
    console.error('Error refilling meeting:', error);
    if (error.code === 'MEETING_NOT_STARTED') {
      return res.status(400).json({
        error: 'Meeting not started',
        message: error.message
      });
    }
    res.status(500).json({
      error: 'Failed to refill meeting',
      message: error.message
    });
  }
});

/**
 * GET /api/meetings/:id - Get meeting by ID
 */
router.get('/:id', async (req, res) => {
  try {
    const result = await query(
      'SELECT * FROM meetings WHERE id = $1',
      [req.params.id]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Meeting not found' });
    }
    
    res.json({
      success: true,
      meeting: result.rows[0]
    });
  } catch (error) {
    console.error('Error getting meeting:', error);
    res.status(500).json({ 
      error: 'Failed to get meeting',
      message: error.message 
    });
  }
});

/**
 * DELETE /api/meetings/:id - Stop a meeting
 */
router.delete('/:id', async (req, res) => {
  try {
    // Get meeting details
    const meetingResult = await query(
      'SELECT * FROM meetings WHERE id = $1',
      [req.params.id]
    );
    
    if (meetingResult.rows.length === 0) {
      return res.status(404).json({ error: 'Meeting not found' });
    }
    
    const meeting = meetingResult.rows[0];
    
    if (meeting.status === 'stopped') {
      return res.status(400).json({ error: 'Meeting already stopped' });
    }
    if (meeting.user_id && req.user?.id && meeting.user_id !== req.user.id) {
      return res.status(403).json({ error: 'Not allowed to stop this meeting' });
    }
    
    // Stop bots on bot server
    // container_ids is stored as PostgreSQL array, convert to proper array
    let containerIds = [];
    if (meeting.container_ids) {
      if (Array.isArray(meeting.container_ids)) {
        containerIds = meeting.container_ids.map(id => String(id).trim()).filter(id => id);
      } else if (typeof meeting.container_ids === 'string') {
        const s = meeting.container_ids.replace(/^\{|\}$/g, '').trim();
        containerIds = s ? s.split(/[,\n\r]+/).map(id => id.trim().replace(/^"|"$/g, '')).filter(Boolean) : [];
      } else if (meeting.container_ids && typeof meeting.container_ids === 'object') {
        containerIds = Object.values(meeting.container_ids).map(id => String(id).trim()).filter(Boolean);
      }
    }
    
    // Clean container IDs - remove any invalid characters
    containerIds = containerIds.map(id => {
      // Remove any non-alphanumeric characters except hyphens and underscores
      return String(id).trim().replace(/[^a-zA-Z0-9_-]/g, '');
    }).filter(id => id && id.length > 0);
    
    let stopBotsResult = null;
    console.log(`[STOP] Meeting ${meeting.id}: meeting_id=${meeting.meeting_id}, bot_server_id=${meeting.bot_server_id}, container_ids count=${containerIds.length}`);
    if (containerIds.length > 0) {
      console.log(`[STOP] First 2 container_ids:`, JSON.stringify(containerIds.slice(0, 2)));
    } else {
      console.log(`[STOP] container_ids from DB:`, JSON.stringify(meeting.container_ids));
    }
    const stopAsync = isTrue(req.query?.async) || isTrue(process.env.BOT_STOP_ASYNC);
    if (stopAsync) {
      stopBots(meeting.meeting_id, containerIds, meeting.bot_server_id, meeting.request_id)
        .then(async () => {
          console.log(`[STOP] stopBots succeeded (async)`);
          try {
            const updateResult = await query(
              `UPDATE meetings
               SET status = 'stopped', stopped_at = NOW()
               WHERE id = $1 AND status <> 'stopped'`,
              [req.params.id]
            );
            if (updateResult.rowCount > 0) {
              await decreaseUsage(meeting.members_count);
            }
          } catch (markErr) {
            console.error('[STOP] Failed to mark meeting stopped after async stop:', markErr.message);
          }
        })
        .catch((error) => {
          console.error(`[STOP] stopBots FAILED (async):`, {
            message: error.message,
            code: error.code,
            status: error.response?.status,
            data: error.response?.data,
            configUrl: error.config?.url
          });
        });
      stopBotsResult = { async: true };
      return res.json({
        success: true,
        message: 'Stop requested. Bots are stopping in background.'
      });
    } else {
      try {
        stopBotsResult = await stopBots(meeting.meeting_id, containerIds, meeting.bot_server_id, meeting.request_id);
        console.log(`[STOP] stopBots succeeded`);
      } catch (error) {
        console.error(`[STOP] stopBots FAILED:`, {
          message: error.message,
          code: error.code,
          status: error.response?.status,
          data: error.response?.data,
          configUrl: error.config?.url
        });
        return res.status(502).json({
          error: 'Failed to stop bots on bot server',
          message: error.message
        });
      }
    }
    
    const updateResult = await query(
      `UPDATE meetings
       SET status = 'stopped', stopped_at = NOW()
       WHERE id = $1 AND status <> 'stopped'`,
      [req.params.id]
    );
    if (updateResult.rowCount > 0) {
      await decreaseUsage(meeting.members_count);
    }
    
    const message = stopBotsResult ? 'Meeting stopped successfully' : 'Meeting stopped';
    
    res.json({
      success: true,
      message: message
    });
  } catch (error) {
    console.error('Error stopping meeting:', error);
    res.status(500).json({ 
      error: 'Failed to stop meeting',
      message: error.message 
    });
  }
});

module.exports = router;
