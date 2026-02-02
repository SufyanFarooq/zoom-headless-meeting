/**
 * Require admin - must be used after authenticate
 */
const requireAdmin = (req, res, next) => {
  if (!req.user?.is_admin) {
    return res.status(403).json({
      error: 'Forbidden',
      message: 'Admin access required.'
    });
  }
  next();
};

module.exports = { requireAdmin };
