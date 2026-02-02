const express = require('express');
const router = express.Router();
const { query } = require('../db');

/**
 * GET /api/cost-settings - Get cost rates per currency (for report calculation)
 * Any authenticated user can read
 */
router.get('/', async (req, res) => {
  try {
    let result;
    try {
      result = await query(
      'SELECT currency, normal_cost_per_bot, profile_cost_per_bot, webinar_cost_per_bot FROM cost_settings ORDER BY currency'
      );
    } catch (tableErr) {
      if (tableErr.code === '42P01' || (tableErr.message && tableErr.message.includes('cost_settings'))) {
        return res.json({ success: true, settings: {} });
      }
      throw tableErr;
    }
    const settings = {};
    for (const row of result.rows) {
      settings[row.currency] = {
        normal: parseFloat(row.normal_cost_per_bot) || 0,
        profile: parseFloat(row.profile_cost_per_bot) || 0,
        webinar: parseFloat(row.webinar_cost_per_bot) || 0
      };
    }
    res.json({ success: true, settings });
  } catch (error) {
    console.error('Error fetching cost settings:', error);
    res.status(500).json({ error: 'Failed to fetch cost settings', message: error.message });
  }
});

module.exports = router;
