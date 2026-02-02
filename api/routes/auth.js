const express = require('express');
const router = express.Router();
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { query } = require('../db');

const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production';
const JWT_EXPIRY = '1h'; // 1 hour

/**
 * POST /api/auth/register - Register a new user (Postman only)
 */
router.post('/register', async (req, res) => {
  try {
    const { username, email, password } = req.body;
    
    // Validate required fields
    if (!username || !email || !password) {
      return res.status(400).json({ 
        error: 'Missing required fields',
        message: 'Username, email, and password are required.' 
      });
    }
    
    // Validate password strength
    if (password.length < 6) {
      return res.status(400).json({ 
        error: 'Weak password',
        message: 'Password must be at least 6 characters long.' 
      });
    }
    
    // Check if user already exists
    const existingUser = await query(
      'SELECT id FROM users WHERE username = $1 OR email = $2',
      [username, email]
    );
    
    if (existingUser.rows.length > 0) {
      return res.status(400).json({ 
        error: 'User already exists',
        message: 'Username or email already registered.' 
      });
    }
    
    // Hash password
    const saltRounds = 10;
    const passwordHash = await bcrypt.hash(password, saltRounds);
    
    // Create user
    const result = await query(
      `INSERT INTO users (username, email, password_hash)
       VALUES ($1, $2, $3)
       RETURNING id, username, email, created_at`,
      [username, email, passwordHash]
    );
    
    res.status(201).json({
      success: true,
      message: 'User registered successfully',
      user: {
        id: result.rows[0].id,
        username: result.rows[0].username,
        email: result.rows[0].email,
        created_at: result.rows[0].created_at
      }
    });
  } catch (error) {
    console.error('Error registering user:', error);
    res.status(500).json({ 
      error: 'Failed to register user',
      message: error.message 
    });
  }
});

/**
 * POST /api/auth/login - Login user
 */
router.post('/login', async (req, res) => {
  try {
    const { username, password } = req.body;
    
    // Validate required fields
    if (!username || !password) {
      return res.status(400).json({ 
        error: 'Missing required fields',
        message: 'Username and password are required.' 
      });
    }
    
    // Find user by username or email
    const result = await query(
      'SELECT id, username, email, password_hash, COALESCE(is_admin, false) as is_admin FROM users WHERE username = $1 OR email = $1',
      [username]
    );
    
    if (result.rows.length === 0) {
      return res.status(401).json({ 
        error: 'Invalid credentials',
        message: 'Username or password is incorrect.' 
      });
    }
    
    const user = result.rows[0];
    
    // Verify password
    const isValidPassword = await bcrypt.compare(password, user.password_hash);
    
    if (!isValidPassword) {
      return res.status(401).json({ 
        error: 'Invalid credentials',
        message: 'Username or password is incorrect.' 
      });
    }
    
    // Generate JWT token
    const token = jwt.sign(
      { userId: user.id, username: user.username },
      JWT_SECRET,
      { expiresIn: JWT_EXPIRY }
    );
    
    res.json({
      success: true,
      message: 'Login successful',
      token,
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        is_admin: user.is_admin || false
      }
    });
  } catch (error) {
    console.error('Error logging in:', error);
    res.status(500).json({ 
      error: 'Failed to login',
      message: error.message 
    });
  }
});

/**
 * POST /api/auth/reset-password - Reset password (Postman only)
 * Requires: username/email and new password
 */
router.post('/reset-password', async (req, res) => {
  try {
    const { username, email, newPassword, resetToken } = req.body;
    
    // Validate required fields
    if (!newPassword) {
      return res.status(400).json({ 
        error: 'Missing required field',
        message: 'New password is required.' 
      });
    }
    
    // Validate password strength
    if (newPassword.length < 6) {
      return res.status(400).json({ 
        error: 'Weak password',
        message: 'Password must be at least 6 characters long.' 
      });
    }
    
    let user;
    
    // If reset token provided, use it
    if (resetToken) {
      const result = await query(
        `SELECT id, username, email FROM users 
         WHERE reset_token = $1 AND reset_token_expiry > NOW()`,
        [resetToken]
      );
      
      if (result.rows.length === 0) {
        return res.status(400).json({ 
          error: 'Invalid or expired token',
          message: 'Reset token is invalid or has expired.' 
        });
      }
      
      user = result.rows[0];
    } else if (username || email) {
      // Find user by username or email
      const result = await query(
        'SELECT id, username, email FROM users WHERE username = $1 OR email = $1',
        [username || email]
      );
      
      if (result.rows.length === 0) {
        return res.status(404).json({ 
          error: 'User not found',
          message: 'No user found with the provided username or email.' 
        });
      }
      
      user = result.rows[0];
    } else {
      return res.status(400).json({ 
        error: 'Missing required field',
        message: 'Either username/email or reset token is required.' 
      });
    }
    
    // Hash new password
    const saltRounds = 10;
    const passwordHash = await bcrypt.hash(newPassword, saltRounds);
    
    // Update password and clear reset token
    await query(
      `UPDATE users 
       SET password_hash = $1, reset_token = NULL, reset_token_expiry = NULL, updated_at = NOW()
       WHERE id = $2`,
      [passwordHash, user.id]
    );
    
    res.json({
      success: true,
      message: 'Password reset successfully'
    });
  } catch (error) {
    console.error('Error resetting password:', error);
    res.status(500).json({ 
      error: 'Failed to reset password',
      message: error.message 
    });
  }
});

/**
 * POST /api/auth/forgot-password - Generate reset token (Postman only)
 */
router.post('/forgot-password', async (req, res) => {
  try {
    const { username, email } = req.body;
    
    if (!username && !email) {
      return res.status(400).json({ 
        error: 'Missing required field',
        message: 'Username or email is required.' 
      });
    }
    
    // Find user
    const result = await query(
      'SELECT id, username, email FROM users WHERE username = $1 OR email = $1',
      [username || email]
    );
    
    if (result.rows.length === 0) {
      // Don't reveal if user exists or not (security best practice)
      return res.json({
        success: true,
        message: 'If the user exists, a reset token has been generated.'
      });
    }
    
    const user = result.rows[0];
    
    // Generate reset token
    const resetToken = crypto.randomBytes(32).toString('hex');
    const resetTokenExpiry = new Date(Date.now() + 3600000); // 1 hour from now
    
    // Save reset token
    await query(
      `UPDATE users 
       SET reset_token = $1, reset_token_expiry = $2, updated_at = NOW()
       WHERE id = $3`,
      [resetToken, resetTokenExpiry, user.id]
    );
    
    // In production, send email with reset token
    // For now, return token (Postman use only)
    res.json({
      success: true,
      message: 'Reset token generated',
      resetToken, // Only for Postman testing
      expiresAt: resetTokenExpiry
    });
  } catch (error) {
    console.error('Error generating reset token:', error);
    res.status(500).json({ 
      error: 'Failed to generate reset token',
      message: error.message 
    });
  }
});

/**
 * GET /api/auth/me - Get current user info (public route, verifies token)
 */
router.get('/me', async (req, res) => {
  try {
    // Get token from Authorization header
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ 
        error: 'Unauthorized',
        message: 'No token provided. Please login first.' 
      });
    }
    
    const token = authHeader.substring(7);
    
    // Verify token
    const decoded = jwt.verify(token, JWT_SECRET);
    
    // Get user from database (auth/me - include is_admin)
    const result = await query(
      'SELECT id, username, email, COALESCE(is_admin, false) as is_admin FROM users WHERE id = $1',
      [decoded.userId]
    );
    
    if (result.rows.length === 0) {
      return res.status(401).json({ 
        error: 'Unauthorized',
        message: 'User not found.' 
      });
    }
    
    res.json({
      success: true,
      user: result.rows[0]
    });
  } catch (error) {
    console.error('Error in /api/auth/me:', {
      error: error.message,
      name: error.name,
      stack: error.stack,
      authHeader: req.headers.authorization ? 'present' : 'missing'
    });
    
    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({ 
        error: 'Unauthorized',
        message: 'Invalid token. Please login again.',
        details: error.message
      });
    }
    
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({ 
        error: 'Unauthorized',
        message: 'Token expired. Please login again.' 
      });
    }
    
    res.status(500).json({ 
      error: 'Failed to get user info',
      message: error.message 
    });
  }
});

module.exports = router;

