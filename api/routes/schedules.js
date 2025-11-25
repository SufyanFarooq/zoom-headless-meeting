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
    
    // Convert IST to UTC for storage
    // IST is UTC+5:30
    // Input format: "2025-11-24T04:41" (IST time, no timezone info)
    // We need to treat this as IST and convert to UTC
    
    // Parse the input string (format: YYYY-MM-DDTHH:mm)
    const [datePart, timePart] = scheduledTimeIST.split('T');
    const [year, month, day] = datePart.split('-').map(Number);
    const [hours, minutes] = timePart.split(':').map(Number);
    
    // Create a Date object treating the input as IST (UTC+5:30)
    // IST is UTC+5:30, so to convert IST to UTC, we subtract 5:30
    // Method: Create UTC date, then subtract 5 hours 30 minutes
    const scheduledTimeUTC = new Date(Date.UTC(year, month - 1, day, hours, minutes, 0, 0));
    
    // Subtract 5 hours 30 minutes to convert IST to UTC
    // Use getTime() to avoid date rollover issues
    const istOffsetMs = (5 * 60 + 30) * 60 * 1000; // 5:30 in milliseconds
    scheduledTimeUTC.setTime(scheduledTimeUTC.getTime() - istOffsetMs);
    
    // Validate: scheduled time must be in the future (at least 1 minute from now)
    const nowUTC = new Date();
    const minFutureTime = new Date(nowUTC.getTime() + 60000); // 1 minute from now
    
    // Calculate IST time for better error message (correctly)
    // IST = UTC + 5:30, so to get IST from UTC, we add 5:30
    const nowISTTimestamp = new Date(nowUTC.getTime() + istOffsetMs);
    // Format IST time correctly (using UTC methods since we've already added offset)
    const nowISTYear = nowISTTimestamp.getUTCFullYear();
    const nowISTMonth = String(nowISTTimestamp.getUTCMonth() + 1).padStart(2, '0');
    const nowISTDay = String(nowISTTimestamp.getUTCDate()).padStart(2, '0');
    const nowISTHours = String(nowISTTimestamp.getUTCHours()).padStart(2, '0');
    const nowISTMinutes = String(nowISTTimestamp.getUTCMinutes()).padStart(2, '0');
    const nowISTString = `${nowISTYear}-${nowISTMonth}-${nowISTDay}T${nowISTHours}:${nowISTMinutes}`;
    
    // Calculate minimum future time in IST
    const minFutureISTTimestamp = new Date(minFutureTime.getTime() + istOffsetMs);
    const minFutureISTYear = minFutureISTTimestamp.getUTCFullYear();
    const minFutureISTMonth = String(minFutureISTTimestamp.getUTCMonth() + 1).padStart(2, '0');
    const minFutureISTDay = String(minFutureISTTimestamp.getUTCDate()).padStart(2, '0');
    const minFutureISTHours = String(minFutureISTTimestamp.getUTCHours()).padStart(2, '0');
    const minFutureISTMinutes = String(minFutureISTTimestamp.getUTCMinutes()).padStart(2, '0');
    const minFutureISTString = `${minFutureISTYear}-${minFutureISTMonth}-${minFutureISTDay}T${minFutureISTHours}:${minFutureISTMinutes}`;
    
    if (scheduledTimeUTC <= nowUTC) {
      return res.status(400).json({ 
        error: 'Scheduled time must be in the future',
        message: `Scheduled time (${scheduledTimeIST} IST) is in the past. Current time is ${nowISTString} IST (${nowUTC.toISOString()} UTC). Please schedule for at least 1 minute in the future (minimum: ${minFutureISTString} IST).`
      });
    }
    
    if (scheduledTimeUTC < minFutureTime) {
      return res.status(400).json({ 
        error: 'Scheduled time too soon',
        message: `Scheduled time must be at least 1 minute in the future. Current time: ${nowISTString} IST. Minimum scheduled time: ${minFutureISTString} IST. Your scheduled time: ${scheduledTimeIST} IST.`
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
    
    const result = await query(
      `INSERT INTO scheduled_tasks 
       (meeting_id, password, members_count, video_count, audio_count, name_type, meeting_type, scheduled_time_ist, timeout_seconds)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
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
        timeoutSeconds || 7200
      ]
    );
    
    res.status(201).json({
      success: true,
      schedule: result.rows[0]
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
    
    let queryText = 'SELECT * FROM scheduled_tasks ORDER BY scheduled_time_ist ASC';
    let params = [];
    
    if (status) {
      queryText = 'SELECT * FROM scheduled_tasks WHERE status = $1 ORDER BY scheduled_time_ist ASC';
      params = [status];
    }
    
    const result = await query(queryText, params);
    
    // Convert UTC back to IST for display
    // IST is UTC+5:30
    const schedules = result.rows.map(row => {
      const scheduledTimeUTC = new Date(row.scheduled_time_ist);
      
      // Add 5 hours 30 minutes to convert UTC to IST
      const scheduledTimeIST = new Date(scheduledTimeUTC);
      scheduledTimeIST.setUTCHours(scheduledTimeIST.getUTCHours() + 5);
      scheduledTimeIST.setUTCMinutes(scheduledTimeIST.getUTCMinutes() + 30);
      
      // Format as IST string (YYYY-MM-DDTHH:mm format for datetime-local input)
      const year = scheduledTimeIST.getUTCFullYear();
      const month = String(scheduledTimeIST.getUTCMonth() + 1).padStart(2, '0');
      const day = String(scheduledTimeIST.getUTCDate()).padStart(2, '0');
      const hours = String(scheduledTimeIST.getUTCHours()).padStart(2, '0');
      const minutes = String(scheduledTimeIST.getUTCMinutes()).padStart(2, '0');
      const istString = `${year}-${month}-${day}T${hours}:${minutes}`;
      
      return {
        ...row,
        scheduled_time_ist: istString,
        scheduled_time_ist_iso: scheduledTimeIST.toISOString()
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
    const result = await query(
      `UPDATE scheduled_tasks 
       SET status = 'cancelled'
       WHERE id = $1 AND status = 'pending'
       RETURNING *`,
      [req.params.id]
    );
    
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

