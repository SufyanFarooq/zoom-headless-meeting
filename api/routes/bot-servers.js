const express = require('express');
const router = express.Router();
const { query } = require('../db');

/**
 * POST /api/bot-servers - Register a bot server
 */
router.post('/', async (req, res) => {
  try {
    const { serverName, serverUrl, capacity, priority } = req.body;
    
    if (!serverName || !serverUrl) {
      return res.status(400).json({ 
        error: 'Missing required fields: serverName, serverUrl' 
      });
    }
    
    const result = await query(
      `INSERT INTO bot_servers (server_name, server_url, capacity, status, priority)
       VALUES ($1, $2, $3, 'active', $4)
       ON CONFLICT (server_name) 
       DO UPDATE SET 
         server_url = EXCLUDED.server_url,
         capacity = EXCLUDED.capacity,
         priority = EXCLUDED.priority,
         status = 'active',
         last_heartbeat = NOW()
       RETURNING *`,
      [serverName, serverUrl, capacity || 100, priority || 100]
    );
    
    res.json({
      success: true,
      server: result.rows[0]
    });
  } catch (error) {
    console.error('Error registering bot server:', error);
    res.status(500).json({ 
      error: 'Failed to register bot server',
      message: error.message 
    });
  }
});

/**
 * GET /api/bot-servers - Get all bot servers
 */
router.get('/', async (req, res) => {
  try {
    const result = await query(
      'SELECT * FROM bot_servers ORDER BY created_at DESC'
    );
    
    res.json({
      success: true,
      servers: result.rows,
      count: result.rows.length
    });
  } catch (error) {
    console.error('Error getting bot servers:', error);
    res.status(500).json({ 
      error: 'Failed to get bot servers',
      message: error.message 
    });
  }
});

/**
 * DELETE /api/bot-servers/:id - Remove bot server
 */
router.delete('/:id', async (req, res) => {
  try {
    const result = await query(
      'DELETE FROM bot_servers WHERE id = $1 RETURNING *',
      [req.params.id]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Bot server not found' });
    }
    
    res.json({
      success: true,
      message: 'Bot server removed successfully'
    });
  } catch (error) {
    console.error('Error removing bot server:', error);
    res.status(500).json({ 
      error: 'Failed to remove bot server',
      message: error.message 
    });
  }
});

module.exports = router;

