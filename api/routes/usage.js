const express = require('express');
const router = express.Router();
const { getUsage, getUsageForUser } = require('../services/usageService');

/**
 * GET /api/usage - Get usage statistics
 */
router.get('/', async (req, res) => {
  try {
    let usage;
    const maxLimit = req.user?.max_members_limit;
    if (maxLimit && parseInt(maxLimit, 10) > 0) {
      usage = await getUsageForUser(req.user.id, maxLimit);
    } else {
      usage = await getUsage();
    }
    
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
