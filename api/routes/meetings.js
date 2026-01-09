const express = require('express');
const router = express.Router();
const { query } = require('../db');
const { validateMembersCount, updateUsage, decreaseUsage } = require('../services/usageService');
const { createBots, stopBots } = require('../services/botService');

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
    
    // Create bots on bot server
    let botResult;
    try {
      botResult = await createBots(
        meetingId,
        password,
        total,
        video,
        audio,
        nameType,
        meetingType,
        timeoutSeconds || 7200
      );
    } catch (botError) {
      console.error('Error creating bots:', botError);
      return res.status(500).json({ 
        error: 'Failed to create bots',
        message: botError.message || 'Bot creation failed. Please check meeting ID, password, and try again.',
        details: process.env.NODE_ENV === 'development' ? botError.stack : undefined
      });
    }
    
    // Store meeting in database
    const meetingResult = await query(
      `INSERT INTO meetings 
       (meeting_id, password, members_count, name_type, meeting_type, status, 
        timeout_seconds, bot_server_id, container_ids, video_count, audio_count, started_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, NOW())
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
        botResult.containerIds,
        botResult.videoCount,
        botResult.audioCount
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
    
    let queryText = 'SELECT * FROM meetings ORDER BY created_at DESC';
    let params = [];
    
    if (status) {
      queryText = 'SELECT * FROM meetings WHERE status = $1 ORDER BY created_at DESC';
      params = [status];
    }
    
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
    
    // Stop bots on bot server
    // container_ids is stored as PostgreSQL array, convert to proper array
    let containerIds = [];
    if (meeting.container_ids) {
      if (Array.isArray(meeting.container_ids)) {
        containerIds = meeting.container_ids.map(id => String(id).trim()).filter(id => id);
      } else if (typeof meeting.container_ids === 'string') {
        // Handle string format (comma-separated or newline-separated)
        containerIds = meeting.container_ids.split(/[,\n\r]+/).map(id => id.trim()).filter(id => id);
      }
    }
    
    // Clean container IDs - remove any invalid characters
    containerIds = containerIds.map(id => {
      // Remove any non-alphanumeric characters except hyphens and underscores
      return String(id).trim().replace(/[^a-zA-Z0-9_-]/g, '');
    }).filter(id => id && id.length > 0);
    
    // Try to stop bots, but don't fail if it times out
    // Bots may already be disconnected, so we proceed with marking meeting as stopped
    let stopBotsResult = null;
    if (containerIds.length > 0) {
      try {
        stopBotsResult = await stopBots(meeting.meeting_id, containerIds, meeting.bot_server_id);
      } catch (error) {
        console.error('Error stopping bots (continuing anyway):', error.message);
        // Continue even if bot stopping fails - bots may already be disconnected
        // We'll still mark the meeting as stopped
      }
    }
    
    // Update meeting status (always do this, even if bot stopping failed)
    await query(
      `UPDATE meetings 
       SET status = 'stopped', stopped_at = NOW()
       WHERE id = $1`,
      [req.params.id]
    );
    
    // Decrease usage
    await decreaseUsage(meeting.members_count);
    
    // Return success even if some bots failed to stop
    const message = stopBotsResult 
      ? 'Meeting stopped successfully' 
      : 'Meeting stopped (some bots may still be stopping in background)';
    
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

