const express = require('express');
const router = express.Router();
const bcrypt = require('bcrypt');
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

async function getUserById(userId) {
  const result = await query(
    `SELECT id, username, email, COALESCE(is_admin, false) as is_admin,
            COALESCE(is_blocked, false) as is_blocked,
            max_members_limit, created_by_admin_id
     FROM users WHERE id = $1`,
    [userId]
  );
  return result.rows[0] || null;
}

function canManageUser(targetUser, adminId) {
  if (!targetUser) return false;
  if (targetUser.is_admin && targetUser.id !== adminId) return false;
  if (targetUser.created_by_admin_id && targetUser.created_by_admin_id !== adminId) return false;
  return true;
}

/**
 * GET /api/admin/users - List all users (admin only)
 */
router.get('/users', async (req, res) => {
  try {
    const result = await query(
      `SELECT id, username, email, is_admin, COALESCE(is_blocked, false) as is_blocked,
        max_members_limit, created_by_admin_id, created_at,
        (SELECT COUNT(*) FROM meetings m WHERE m.user_id = users.id AND m.status = 'active') as active_meetings,
        (SELECT COALESCE(SUM(members_count), 0) FROM meetings m WHERE m.user_id = users.id) as total_bots_submitted
       FROM users
       ORDER BY created_at DESC`
    );
    res.json({ success: true, users: result.rows });
  } catch (error) {
    console.error('Error listing users:', error);
    res.status(500).json({ error: 'Failed to list users', message: error.message });
  }
});

/**
 * POST /api/admin/users - Create new user account (admin only)
 */
router.post('/users', async (req, res) => {
  try {
    const { username, email, password, maxMembersLimit } = req.body;
    if (!username || !email || !password) {
      return res.status(400).json({
        error: 'Missing required fields: username, email, password'
      });
    }
    if (password.length < 6) {
      return res.status(400).json({
        error: 'Password must be at least 6 characters'
      });
    }
    const existing = await query(
      'SELECT id FROM users WHERE username = $1 OR email = $2',
      [username, email]
    );
    if (existing.rows.length > 0) {
      return res.status(400).json({
        error: 'Username or email already exists'
      });
    }
    let maxLimit = null;
    if (maxMembersLimit !== undefined && maxMembersLimit !== null && String(maxMembersLimit).trim() !== '') {
      const parsed = parseInt(maxMembersLimit, 10);
      if (isNaN(parsed) || parsed <= 0) {
        return res.status(400).json({ error: 'Max members limit must be a positive number' });
      }
      maxLimit = parsed;
    }
    const saltRounds = 10;
    const passwordHash = await bcrypt.hash(password, saltRounds);
    const insert = await query(
      `INSERT INTO users (username, email, password_hash, max_members_limit, created_by_admin_id)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, username, email, max_members_limit, created_at`,
      [username, email, passwordHash, maxLimit, req.user?.id || null]
    );
    res.status(201).json({
      success: true,
      message: 'Account created. User can now login.',
      user: insert.rows[0]
    });
  } catch (error) {
    console.error('Error creating user:', error);
    res.status(500).json({ error: 'Failed to create user', message: error.message });
  }
});

/**
 * PUT /api/admin/users/:id - Update user details (admin only)
 */
router.put('/users/:id', async (req, res) => {
  try {
    const userId = parseInt(req.params.id, 10);
    const { username, email, password } = req.body;

    if (!userId) {
      return res.status(400).json({ error: 'Invalid user id' });
    }

    const hasUsername = username !== undefined;
    const hasEmail = email !== undefined;
    const hasPassword = password !== undefined && password !== null && String(password).length > 0;

    if (!hasUsername && !hasEmail && !hasPassword) {
      return res.status(400).json({ error: 'At least one field is required: username, email, or password' });
    }

    const target = await getUserById(userId);
    if (!target) return res.status(404).json({ error: 'User not found' });
    if (!canManageUser(target, req.user?.id)) {
      return res.status(403).json({ error: 'Not allowed to update this user' });
    }

    const nextUsername = hasUsername ? String(username).trim() : target.username;
    const nextEmail = hasEmail ? String(email).trim() : target.email;

    if (!nextUsername) {
      return res.status(400).json({ error: 'Username is required' });
    }
    if (!nextEmail) {
      return res.status(400).json({ error: 'Email is required' });
    }

    if (hasPassword && String(password).length < 6) {
      return res.status(400).json({ error: 'Password must be at least 6 characters' });
    }

    const existing = await query(
      `SELECT id FROM users
       WHERE id <> $1 AND (username = $2 OR email = $3)
       LIMIT 1`,
      [userId, nextUsername, nextEmail]
    );
    if (existing.rows.length > 0) {
      return res.status(400).json({ error: 'Username or email already exists' });
    }

    if (hasPassword) {
      const saltRounds = 10;
      const passwordHash = await bcrypt.hash(String(password), saltRounds);
      await query(
        `UPDATE users
         SET username = $1, email = $2, password_hash = $3, updated_at = NOW()
         WHERE id = $4`,
        [nextUsername, nextEmail, passwordHash, userId]
      );
    } else {
      await query(
        `UPDATE users
         SET username = $1, email = $2, updated_at = NOW()
         WHERE id = $3`,
        [nextUsername, nextEmail, userId]
      );
    }

    const updated = await getUserById(userId);
    res.json({
      success: true,
      message: 'User details updated',
      user: updated
    });
  } catch (error) {
    console.error('Error updating user details:', error);
    res.status(500).json({ error: 'Failed to update user details', message: error.message });
  }
});

/**
 * PUT /api/admin/users/:id/password - Update user password (admin only)
 */
router.put('/users/:id/password', async (req, res) => {
  try {
    const userId = parseInt(req.params.id, 10);
    const { newPassword } = req.body;
    if (!userId) {
      return res.status(400).json({ error: 'Invalid user id' });
    }
    if (!newPassword || newPassword.length < 6) {
      return res.status(400).json({ error: 'Password must be at least 6 characters' });
    }

    const target = await getUserById(userId);
    if (!target) return res.status(404).json({ error: 'User not found' });
    if (!canManageUser(target, req.user?.id)) {
      return res.status(403).json({ error: 'Not allowed to update this user' });
    }

    const saltRounds = 10;
    const passwordHash = await bcrypt.hash(newPassword, saltRounds);
    await query(
      `UPDATE users SET password_hash = $1, updated_at = NOW() WHERE id = $2`,
      [passwordHash, userId]
    );

    res.json({ success: true, message: 'Password updated' });
  } catch (error) {
    console.error('Error updating password:', error);
    res.status(500).json({ error: 'Failed to update password', message: error.message });
  }
});

/**
 * PUT /api/admin/users/:id/block - Block/unblock user (admin only)
 */
router.put('/users/:id/block', async (req, res) => {
  try {
    const userId = parseInt(req.params.id, 10);
    const { blocked } = req.body;
    if (!userId) {
      return res.status(400).json({ error: 'Invalid user id' });
    }
    if (typeof blocked !== 'boolean') {
      return res.status(400).json({ error: 'blocked must be a boolean' });
    }

    const target = await getUserById(userId);
    if (!target) return res.status(404).json({ error: 'User not found' });
    if (!canManageUser(target, req.user?.id)) {
      return res.status(403).json({ error: 'Not allowed to update this user' });
    }

    await query(
      `UPDATE users SET is_blocked = $1, updated_at = NOW() WHERE id = $2`,
      [blocked, userId]
    );

    res.json({ success: true, message: blocked ? 'User blocked' : 'User unblocked' });
  } catch (error) {
    console.error('Error updating user block status:', error);
    res.status(500).json({ error: 'Failed to update user status', message: error.message });
  }
});

/**
 * PUT /api/admin/users/:id/limit - Update max members limit (admin only)
 */
router.put('/users/:id/limit', async (req, res) => {
  try {
    const userId = parseInt(req.params.id, 10);
    const { maxMembersLimit } = req.body;
    if (!userId) {
      return res.status(400).json({ error: 'Invalid user id' });
    }

    let maxLimit = null;
    if (maxMembersLimit !== undefined && maxMembersLimit !== null && String(maxMembersLimit).trim() !== '') {
      const parsed = parseInt(maxMembersLimit, 10);
      if (isNaN(parsed) || parsed <= 0) {
        return res.status(400).json({ error: 'Max members limit must be a positive number' });
      }
      maxLimit = parsed;
    }

    const target = await getUserById(userId);
    if (!target) return res.status(404).json({ error: 'User not found' });
    if (!canManageUser(target, req.user?.id)) {
      return res.status(403).json({ error: 'Not allowed to update this user' });
    }

    await query(
      `UPDATE users SET max_members_limit = $1, updated_at = NOW() WHERE id = $2`,
      [maxLimit, userId]
    );

    res.json({ success: true, message: 'Max members limit updated', maxMembersLimit: maxLimit });
  } catch (error) {
    console.error('Error updating max members limit:', error);
    res.status(500).json({ error: 'Failed to update max members limit', message: error.message });
  }
});

/**
 * GET /api/admin/reports - Get report for any user (admin only)
 * Query: userId, startDate, endDate
 */
router.get('/reports', async (req, res) => {
  try {
    const { userId, startDate, endDate } = req.query;
    if (!userId || !startDate || !endDate) {
      return res.status(400).json({
        error: 'Missing required params: userId, startDate, endDate'
      });
    }
    const start = new Date(startDate);
    const end = new Date(endDate);
    if (isNaN(start.getTime()) || isNaN(end.getTime())) {
      return res.status(400).json({ error: 'Invalid date format' });
    }

    const result = await query(
      `SELECT 
        DATE(COALESCE(started_at, created_at)) as d,
        meeting_type,
        SUM(members_count) as total
       FROM meetings
       WHERE user_id = $1
         AND DATE(COALESCE(started_at, created_at)) >= $2
         AND DATE(COALESCE(started_at, created_at)) <= $3
       GROUP BY DATE(COALESCE(started_at, created_at)), meeting_type
       ORDER BY d ASC`,
      [userId, startDate, endDate]
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

    const curr = new Date(start);
    const endD = new Date(end);
    while (curr <= endD) {
      const d = curr.toISOString().split('T')[0];
      if (!byDate[d]) byDate[d] = { normal: 0, pic: 0, webinar: 0 };
      curr.setDate(curr.getDate() + 1);
    }

    res.json({ success: true, byDate, startDate, endDate, userId });
  } catch (error) {
    console.error('Error fetching admin report:', error);
    res.status(500).json({ error: 'Failed to fetch report', message: error.message });
  }
});

/**
 * GET /api/admin/cost-settings - Get all cost settings (admin only)
 */
router.get('/cost-settings', async (req, res) => {
  try {
    const result = await query(
      'SELECT currency, normal_cost_per_bot, profile_cost_per_bot, webinar_cost_per_bot, updated_at FROM cost_settings ORDER BY currency'
    );
    const settings = {};
    for (const row of result.rows) {
      settings[row.currency] = {
        normal: parseFloat(row.normal_cost_per_bot) || 0,
        profile: parseFloat(row.profile_cost_per_bot) || 0,
        webinar: parseFloat(row.webinar_cost_per_bot) || 0,
        updated_at: row.updated_at
      };
    }
    res.json({ success: true, settings });
  } catch (error) {
    console.error('Error fetching cost settings:', error);
    res.status(500).json({ error: 'Failed to fetch cost settings', message: error.message });
  }
});

/**
 * PUT /api/admin/cost-settings - Update cost for a currency (admin only)
 * Body: { currency, normal_cost_per_bot, profile_cost_per_bot, webinar_cost_per_bot }
 */
router.put('/cost-settings', async (req, res) => {
  try {
    const { currency, normal_cost_per_bot, profile_cost_per_bot, webinar_cost_per_bot } = req.body;
    if (!currency || typeof currency !== 'string' || currency.length > 10) {
      return res.status(400).json({ error: 'Valid currency required (e.g. INR, USD, EUR)' });
    }
    const normal = parseFloat(normal_cost_per_bot);
    const profile = parseFloat(profile_cost_per_bot);
    const webinar = parseFloat(webinar_cost_per_bot);
    if (isNaN(normal) || normal < 0 || isNaN(profile) || profile < 0 || isNaN(webinar) || webinar < 0) {
      return res.status(400).json({ error: 'Costs must be non-negative numbers' });
    }
    await query(
      `INSERT INTO cost_settings (currency, normal_cost_per_bot, profile_cost_per_bot, webinar_cost_per_bot, updated_at)
       VALUES ($1, $2, $3, $4, NOW())
       ON CONFLICT (currency) DO UPDATE SET
         normal_cost_per_bot = $2, profile_cost_per_bot = $3, webinar_cost_per_bot = $4, updated_at = NOW()`,
      [currency.toUpperCase(), normal, profile, webinar]
    );
    res.json({
      success: true,
      message: `Cost settings updated for ${currency.toUpperCase()}`
    });
  } catch (error) {
    console.error('Error updating cost settings:', error);
    res.status(500).json({ error: 'Failed to update cost settings', message: error.message });
  }
});

/**
 * GET /api/admin/meetings - Get meetings for any user (admin only)
 * Query: userId, status, meetingId, date, range(today|week), page, pageSize
 */
router.get('/meetings', async (req, res) => {
  try {
    const { userId, status, meetingId, date, range } = req.query;
    if (!userId) {
      return res.status(400).json({ error: 'userId required' });
    }

    const parsedUserId = parseInt(userId, 10);
    if (!parsedUserId) {
      return res.status(400).json({ error: 'Invalid userId' });
    }

    const page = Math.max(1, parseInt(req.query.page, 10) || 1);
    const pageSize = Math.min(100, Math.max(1, parseInt(req.query.pageSize, 10) || 20));
    const offset = (page - 1) * pageSize;

    let where = 'WHERE user_id = $1';
    const params = [parsedUserId];

    if (status) {
      where += ` AND status = $${params.length + 1}`;
      params.push(status);
    }

    if (meetingId && String(meetingId).trim()) {
      where += ` AND meeting_id::text ILIKE $${params.length + 1}`;
      params.push(`%${String(meetingId).trim()}%`);
    }

    const hasExactDate = Boolean(date && String(date).trim());
    if (hasExactDate) {
      const exactDate = String(date).trim();
      if (!/^\d{4}-\d{2}-\d{2}$/.test(exactDate)) {
        return res.status(400).json({ error: 'Invalid date format. Use YYYY-MM-DD' });
      }
      where += ` AND DATE(COALESCE(started_at, created_at)) = $${params.length + 1}::date`;
      params.push(exactDate);
    } else if (range === 'today') {
      where += ' AND DATE(COALESCE(started_at, created_at)) = CURRENT_DATE';
    } else if (range === 'week') {
      where += " AND DATE(COALESCE(started_at, created_at)) >= (CURRENT_DATE - INTERVAL '6 days')";
    }

    const countQuery = `SELECT COUNT(*)::int AS total FROM meetings ${where}`;
    const countResult = await query(countQuery, params);
    const total = countResult.rows[0]?.total || 0;
    const totalPages = Math.max(1, Math.ceil(total / pageSize));

    const dataParams = [...params, pageSize, offset];
    const dataQuery = `
      SELECT *
      FROM meetings
      ${where}
      ORDER BY created_at DESC
      LIMIT $${dataParams.length - 1}
      OFFSET $${dataParams.length}
    `;
    const result = await query(dataQuery, dataParams);

    res.json({
      success: true,
      meetings: result.rows,
      count: result.rows.length,
      pagination: {
        page,
        pageSize,
        total,
        totalPages,
        hasPrev: page > 1,
        hasNext: page < totalPages
      },
      filters: {
        status: status || null,
        meetingId: meetingId || null,
        date: hasExactDate ? String(date).trim() : null,
        range: hasExactDate ? null : (range || null)
      }
    });
  } catch (error) {
    console.error('Error fetching admin meetings:', error);
    res.status(500).json({ error: 'Failed to fetch meetings', message: error.message });
  }
});

module.exports = router;
