const express = require('express');
const router = express.Router();
const { query } = require('../db');

function toDateKey(val) {
  if (!val) return null;
  if (val instanceof Date) {
    const y = val.getFullYear();
    const m = String(val.getMonth() + 1).padStart(2, '0');
    const d = String(val.getDate()).padStart(2, '0');
    return `${y}-${m}-${d}`;
  }
  const s = String(val).split('T')[0];
  return s && s.length >= 10 ? s.substring(0, 10) : null;
}

/**
 * GET /api/reports - Get usage report by date range
 * Query: startDate (YYYY-MM-DD), endDate (YYYY-MM-DD)
 * Returns aggregated data: { byDate: { "2026-01-01": { normal: 120, pic: 0, webinar: 0 } }, ... }
 */
router.get('/', async (req, res) => {
  try {
    const { startDate, endDate } = req.query;
    const userId = req.user?.id;

    if (!startDate || !endDate) {
      return res.status(400).json({
        error: 'Missing required params: startDate, endDate (format: YYYY-MM-DD)'
      });
    }

    const start = new Date(startDate);
    const end = new Date(endDate);
    if (isNaN(start.getTime()) || isNaN(end.getTime())) {
      return res.status(400).json({ error: 'Invalid date format' });
    }
    if (start > end) {
      return res.status(400).json({ error: 'startDate must be before endDate' });
    }

    let whereClause = `WHERE DATE(COALESCE(started_at, created_at)) >= $1 AND DATE(COALESCE(started_at, created_at)) <= $2`;
    const params = [startDate, endDate];
    if (userId) {
      whereClause += ` AND user_id = $3`;
      params.push(userId);
    }

    const result = await query(
      `SELECT 
        DATE(COALESCE(started_at, created_at)) as d,
        meeting_type,
        SUM(members_count) as total
       FROM meetings
       ${whereClause}
       GROUP BY DATE(COALESCE(started_at, created_at)), meeting_type
       ORDER BY d ASC`,
      params
    );

    const byDate = {};
    for (const row of result.rows) {
      const d = toDateKey(row.d);
      if (!d) continue;
      if (!byDate[d]) byDate[d] = { normal: 0, pic: 0, webinar: 0 };
      const t = row.meeting_type;
      const n = parseInt(row.total) || 0;
      if (t === 'Normal Member') byDate[d].normal = n;
      else if (t === 'Profile Pic Member') byDate[d].pic = n;
      else if (t === 'Webinar') byDate[d].webinar = n;
      else byDate[d].normal += n;
    }

    // Fill missing dates with zeros
    const curr = new Date(start);
    const endD = new Date(end);
    while (curr <= endD) {
      const d = curr.toISOString().split('T')[0];
      if (!byDate[d]) byDate[d] = { normal: 0, pic: 0, webinar: 0 };
      curr.setDate(curr.getDate() + 1);
    }

    res.json({ success: true, byDate, startDate, endDate });
  } catch (error) {
    console.error('Error fetching report:', error);
    res.status(500).json({ error: 'Failed to fetch report', message: error.message });
  }
});

module.exports = router;
