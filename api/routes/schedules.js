const express = require('express');
const router = express.Router();
const { query } = require('../db');
const { validateMembersCount } = require('../services/usageService');

/**
 * POST /api/schedules - Create a scheduled task
 */
router.post('/', async (req, res) => {
  try {
    const { meetingId, password, membersCount, videoCount, audioCount, nameType, meetingType, scheduledTimeIST, timeoutSeconds } = req.body;
    
    // Validate required fields
    if (!meetingId || !password || !membersCount || !nameType || !meetingType || !scheduledTimeIST) {
      return res.status(400).json({ 
        error: 'Missing required fields: meetingId, password, membersCount, nameType, meetingType, scheduledTimeIST' 
      });
    }
    
    // Validate members count
    const validation = await validateMembersCount(parseInt(membersCount));
    if (!validation.valid) {
      return res.status(400).json({ 
        error: 'Validation failed',
        errors: validation.errors
      });
    }

    const maxLimit = req.user?.max_members_limit;
    const total = parseInt(membersCount);
    if (maxLimit && total > maxLimit) {
      return res.status(400).json({
        error: 'Max members limit exceeded',
        message: `Your account limit is ${maxLimit} members per meeting.`,
        limit: maxLimit
      });
    }
    
    // Accept time in UTC format (ISO 8601) or local timezone format
    // Input can be:
    // 1. ISO string with timezone: "2025-11-25T14:10:00Z" or "2025-11-25T14:10:00+05:30"
    // 2. Local datetime: "2025-11-25T19:40" (will be treated as user's local timezone)
    
    let scheduledTimeUTC;
    
    // Check if input is ISO string with timezone info
    if (scheduledTimeIST.includes('Z') || scheduledTimeIST.includes('+') || scheduledTimeIST.includes('-', 10)) {
      // ISO format with timezone - parse directly
      scheduledTimeUTC = new Date(scheduledTimeIST);
    } else {
      // Local datetime format (YYYY-MM-DDTHH:mm) - treat as UTC
      // Frontend should send UTC time, but if local time is sent, we'll parse it
      const [datePart, timePart] = scheduledTimeIST.split('T');
      const [year, month, day] = datePart.split('-').map(Number);
      const [hours, minutes] = timePart.split(':').map(Number);
      
      // Create UTC date directly (assuming input is already in UTC)
      scheduledTimeUTC = new Date(Date.UTC(year, month - 1, day, hours, minutes, 0, 0));
    }
    
    // Validate the date is valid
    if (isNaN(scheduledTimeUTC.getTime())) {
      return res.status(400).json({ 
        error: 'Invalid scheduled time format',
        message: `Invalid time format: ${scheduledTimeIST}. Please use UTC time format (YYYY-MM-DDTHH:mm) or ISO 8601 format.`
      });
    }
    
    // Validate: scheduled time must be in the future (at least 1 minute from now)
    const nowUTC = new Date();
    const minFutureTime = new Date(nowUTC.getTime() + 60000); // 1 minute from now
    
    // Debug logging
    console.log('[Schedule Validation]', {
      input: scheduledTimeIST,
      scheduledTimeUTC: scheduledTimeUTC.toISOString(),
      nowUTC: nowUTC.toISOString(),
      isPast: scheduledTimeUTC <= nowUTC,
      isTooSoon: scheduledTimeUTC < minFutureTime
    });
    
    if (scheduledTimeUTC <= nowUTC) {
      return res.status(400).json({ 
        error: 'Scheduled time must be in the future',
        message: `Scheduled time (${scheduledTimeUTC.toISOString()} UTC) is in the past. Current server time: ${nowUTC.toISOString()} UTC. Please schedule for at least 1 minute in the future.`
      });
    }
    
    if (scheduledTimeUTC < minFutureTime) {
      return res.status(400).json({ 
        error: 'Scheduled time too soon',
        message: `Scheduled time must be at least 1 minute in the future. Current time: ${nowUTC.toISOString()} UTC. Minimum scheduled time: ${minFutureTime.toISOString()} UTC. Your scheduled time: ${scheduledTimeUTC.toISOString()} UTC.`
      });
    }
    
    // Store scheduled task
    // Calculate video/audio counts if not provided (default: 50/50 split)
    // Use Number.isNaN to properly handle 0 values
    const video = (videoCount !== undefined && videoCount !== null && !isNaN(parseInt(videoCount)))
      ? parseInt(videoCount)
      : Math.floor(parseInt(membersCount) / 2);
    const audio = (audioCount !== undefined && audioCount !== null && !isNaN(parseInt(audioCount)))
      ? parseInt(audioCount)
      : (parseInt(membersCount) - video);
    
    const userId = req.user?.id || null;
    const result = await query(
      `INSERT INTO scheduled_tasks 
       (meeting_id, password, members_count, video_count, audio_count, name_type, meeting_type, scheduled_time_ist, timeout_seconds, user_id)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
       RETURNING *`,
      [
        meetingId,
        password,
        parseInt(membersCount),
        video,
        audio,
        nameType,
        meetingType,
        scheduledTimeUTC,
        timeoutSeconds || 7200,
        userId
      ]
    );
    
    // Return UTC time (stored in database)
    const scheduledTimeUTCFromDB = new Date(result.rows[0].scheduled_time_ist);
    
    // Format as UTC string (YYYY-MM-DDTHH:mm format)
    const year = scheduledTimeUTCFromDB.getUTCFullYear();
    const month = String(scheduledTimeUTCFromDB.getUTCMonth() + 1).padStart(2, '0');
    const day = String(scheduledTimeUTCFromDB.getUTCDate()).padStart(2, '0');
    const hours = String(scheduledTimeUTCFromDB.getUTCHours()).padStart(2, '0');
    const minutes = String(scheduledTimeUTCFromDB.getUTCMinutes()).padStart(2, '0');
    const utcString = `${year}-${month}-${day}T${hours}:${minutes}`;
    
    res.status(201).json({
      success: true,
      schedule: {
        ...result.rows[0],
        scheduled_time_ist: utcString // UTC format
      }
    });
  } catch (error) {
    console.error('Error creating schedule:', error);
    res.status(500).json({ 
      error: 'Failed to create schedule',
      message: error.message 
    });
  }
});

/**
 * GET /api/schedules - Get all scheduled tasks
 */
router.get('/', async (req, res) => {
  try {
    const { status } = req.query;
    const userId = req.user?.id;
    
    let queryText = 'SELECT * FROM scheduled_tasks';
    let params = [];
    
    if (userId) {
      queryText += ' WHERE user_id = $1';
      params.push(userId);
    }
    if (status) {
      queryText += (params.length ? ' AND' : ' WHERE') + ' status = $' + (params.length + 1);
      params.push(status);
    }
    queryText += ' ORDER BY scheduled_time_ist ASC';
    
    const result = await query(queryText, params);
    
    // Return UTC time (stored in database)
    // Frontend will handle timezone conversion for display
    const schedules = result.rows.map(row => {
      const scheduledTimeUTC = new Date(row.scheduled_time_ist);
      
      // Format as UTC string (YYYY-MM-DDTHH:mm format)
      const year = scheduledTimeUTC.getUTCFullYear();
      const month = String(scheduledTimeUTC.getUTCMonth() + 1).padStart(2, '0');
      const day = String(scheduledTimeUTC.getUTCDate()).padStart(2, '0');
      const hours = String(scheduledTimeUTC.getUTCHours()).padStart(2, '0');
      const minutes = String(scheduledTimeUTC.getUTCMinutes()).padStart(2, '0');
      const utcString = `${year}-${month}-${day}T${hours}:${minutes}`;
      
      return {
        ...row,
        scheduled_time_ist: utcString, // UTC format
        scheduled_time_ist_iso: scheduledTimeUTC.toISOString()
      };
    });
    
    res.json({
      success: true,
      schedules,
      count: schedules.length
    });
  } catch (error) {
    console.error('Error getting schedules:', error);
    res.status(500).json({ 
      error: 'Failed to get schedules',
      message: error.message 
    });
  }
});

/**
 * DELETE /api/schedules/:id - Cancel a scheduled task
 */
router.delete('/:id', async (req, res) => {
  try {
    const userId = req.user?.id;
    let queryText = `UPDATE scheduled_tasks SET status = 'cancelled' WHERE id = $1 AND status = 'pending'`;
    const params = [req.params.id];
    if (userId) {
      queryText += ' AND user_id = $2';
      params.push(userId);
    }
    queryText += ' RETURNING *';
    const result = await query(queryText, params);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Scheduled task not found or already executed/cancelled' });
    }
    
    res.json({
      success: true,
      message: 'Scheduled task cancelled successfully'
    });
  } catch (error) {
    console.error('Error cancelling schedule:', error);
    res.status(500).json({ 
      error: 'Failed to cancel schedule',
      message: error.message 
    });
  }
});

module.exports = router;
