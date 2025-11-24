const express = require('express');
const router = express.Router();
const { getUsage } = require('../services/usageService');

/**
 * GET /api/usage - Get usage statistics
 */
router.get('/', async (req, res) => {
  try {
    const usage = await getUsage();
    
    res.json({
      success: true,
      usage: {
        submitted: usage.submitted,
        remaining: usage.remaining,
        limit: usage.limit
      }
    });
  } catch (error) {
    console.error('Error getting usage:', error);
    res.status(500).json({ 
      error: 'Failed to get usage',
      message: error.message 
    });
  }
});

module.exports = router;

