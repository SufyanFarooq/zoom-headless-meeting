const jwt = require('jsonwebtoken');
const { query } = require('../db');

/**
 * JWT Authentication Middleware
 * Verifies JWT token and attaches user info to request
 */
const authenticate = async (req, res, next) => {
  try {
    // Get token from Authorization header
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      // Set cache-control headers before returning 401
      res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate, private');
      res.setHeader('Pragma', 'no-cache');
      res.setHeader('Expires', '0');
      return res.status(401).json({ 
        error: 'Unauthorized',
        message: 'No token provided. Please login first.' 
      });
    }
    
    const token = authHeader.substring(7); // Remove 'Bearer ' prefix
    
    if (!token) {
      // Set cache-control headers before returning 401
      res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate, private');
      res.setHeader('Pragma', 'no-cache');
      res.setHeader('Expires', '0');
      return res.status(401).json({ 
        error: 'Unauthorized',
        message: 'Invalid token format.' 
      });
    }
    
    // Verify token
    const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production';
    const decoded = jwt.verify(token, JWT_SECRET);
    
    // Get user from database (include is_admin for admin routes)
    const result = await query(
      `SELECT id, username, email,
              COALESCE(is_admin, false) as is_admin,
              COALESCE(is_blocked, false) as is_blocked,
              max_members_limit
       FROM users WHERE id = $1`,
      [decoded.userId]
    );
    
    if (result.rows.length === 0) {
      // Set cache-control headers before returning 401
      res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate, private');
      res.setHeader('Pragma', 'no-cache');
      res.setHeader('Expires', '0');
      return res.status(401).json({ 
        error: 'Unauthorized',
        message: 'User not found.' 
      });
    }
    
    const user = result.rows[0];
    if (user.is_blocked) {
      res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate, private');
      res.setHeader('Pragma', 'no-cache');
      res.setHeader('Expires', '0');
      return res.status(403).json({
        error: 'Forbidden',
        message: 'Account is blocked. Please contact admin.'
      });
    }

    // Attach user to request
    req.user = user;
    next();
  } catch (error) {
    // Set cache-control headers before returning error responses
    res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate, private');
    res.setHeader('Pragma', 'no-cache');
    res.setHeader('Expires', '0');
    
    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({ 
        error: 'Unauthorized',
        message: 'Invalid token.' 
      });
    }
    
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({ 
        error: 'Unauthorized',
        message: 'Token expired. Please login again.' 
      });
    }
    
    console.error('Auth middleware error:', error);
    return res.status(500).json({ 
      error: 'Internal server error',
      message: 'Authentication failed.' 
    });
  }
};

module.exports = { authenticate };
