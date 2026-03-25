const { query } = require('../db');

/**
 * Get current usage statistics
 */
async function getUsage() {
  try {
    const result = await query(
      'SELECT total_submitted, remaining, limit_value FROM usage_tracking ORDER BY id DESC LIMIT 1'
    );
    
    if (result.rows.length === 0) {
      // Initialize if not exists
      await query(
        'INSERT INTO usage_tracking (total_submitted, remaining, limit_value) VALUES ($1, $2, $3)',
        [0, 2000, 2000]
      );
      return { submitted: 0, remaining: 2000, limit: 2000 };
    }
    
    const usage = result.rows[0];
    return {
      submitted: usage.total_submitted,
      remaining: usage.remaining,
      limit: usage.limit_value
    };
  } catch (error) {
    console.error('Error getting usage:', error);
    throw error;
  }
}

/**
 * Get usage for a specific user (active meetings only)
 */
async function getUsageForUser(userId, limit) {
  try {
    const result = await query(
      `SELECT COALESCE(SUM(members_count), 0) as used
       FROM meetings
       WHERE user_id = $1 AND status = 'active'`,
      [userId]
    );
    const used = parseInt(result.rows[0]?.used, 10) || 0;
    const maxLimit = parseInt(limit, 10) || 0;
    const remaining = maxLimit > 0 ? Math.max(0, maxLimit - used) : 0;
    return { submitted: used, remaining, limit: maxLimit };
  } catch (error) {
    console.error('Error getting user usage:', error);
    throw error;
  }
}

/**
 * Check if members count is valid (greater than zero, within limit)
 */
async function validateMembersCount(membersCount) {
  const errors = [];

  // Must be greater than zero
  if (membersCount <= 0) {
    errors.push('Members count must be greater than 0');
  }
  
  // Must not exceed 500 (as per requirement: 100+ not allowed)
  if (membersCount > 500) {
    errors.push('Members count cannot exceed 500');
  }
  
  // Check usage limit
  const usage = await getUsage();
  if (usage.submitted + membersCount > usage.limit) {
    errors.push(`Cannot add ${membersCount} members. Remaining capacity: ${usage.remaining}`);
  }
  
  return {
    valid: errors.length === 0,
    errors
  };
}

/**
 * Update usage after meeting creation
 */
async function updateUsage(membersCount) {
  try {
    const result = await query(
      `UPDATE usage_tracking 
       SET total_submitted = total_submitted + $1,
           remaining = remaining - $1,
           updated_at = NOW()
       WHERE id = (SELECT id FROM usage_tracking ORDER BY id DESC LIMIT 1)
       RETURNING total_submitted, remaining, limit_value`,
      [membersCount]
    );
    
    if (result.rows.length === 0) {
      // Initialize if not exists
      await query(
        'INSERT INTO usage_tracking (total_submitted, remaining, limit_value) VALUES ($1, $2, $3)',
        [membersCount, 2000 - membersCount, 2000]
      );
      return { submitted: membersCount, remaining: 2000 - membersCount, limit: 2000 };
    }
    
    return {
      submitted: result.rows[0].total_submitted,
      remaining: result.rows[0].remaining,
      limit: result.rows[0].limit_value
    };
  } catch (error) {
    console.error('Error updating usage:', error);
    throw error;
  }
}

/**
 * Decrease usage when meeting is stopped
 */
async function decreaseUsage(membersCount) {
  try {
    const result = await query(
      `UPDATE usage_tracking 
       SET total_submitted = GREATEST(0, total_submitted - $1),
           remaining = LEAST(limit_value, remaining + $1),
           updated_at = NOW()
       WHERE id = (SELECT id FROM usage_tracking ORDER BY id DESC LIMIT 1)
       RETURNING total_submitted, remaining, limit_value`,
      [membersCount]
    );
    
    return {
      submitted: result.rows[0].total_submitted,
      remaining: result.rows[0].remaining,
      limit: result.rows[0].limit_value
    };
  } catch (error) {
    console.error('Error decreasing usage:', error);
    throw error;
  }
}

module.exports = {
  getUsage,
  getUsageForUser,
  validateMembersCount,
  updateUsage,
  decreaseUsage
};
