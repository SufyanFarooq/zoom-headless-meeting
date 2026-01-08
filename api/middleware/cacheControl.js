/**
 * Cache Control Middleware
 * Prevents caching of sensitive data (meeting IDs, passwords, etc.)
 * Required for Zoom Marketplace security review
 */

/**
 * Add no-cache headers to prevent sensitive data from being cached
 */
function noCacheSensitiveData(req, res, next) {
  // Add headers to prevent caching
  res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate, private');
  res.setHeader('Pragma', 'no-cache');
  res.setHeader('Expires', '0');
  
  next();
}

/**
 * Check if response contains sensitive data
 * If yes, apply no-cache headers
 */
function preventSensitiveDataCache(req, res, next) {
  // Override res.json to check for sensitive data
  const originalJson = res.json.bind(res);
  
  res.json = function(data) {
    // Check if response contains sensitive fields
    const hasSensitiveData = containsSensitiveData(data);
    
    if (hasSensitiveData) {
      // Add no-cache headers for sensitive data
      res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate, private');
      res.setHeader('Pragma', 'no-cache');
      res.setHeader('Expires', '0');
    }
    
    return originalJson(data);
  };
  
  next();
}

/**
 * Check if data contains sensitive information
 */
function containsSensitiveData(data) {
  if (!data || typeof data !== 'object') {
    return false;
  }
  
  // List of sensitive field names
  const sensitiveFields = [
    'meeting_id',
    'password',
    'passord', // typo in some fields
    'meetingId',
    'token',
    'zak',
    'joinToken',
    'onBehalfToken'
  ];
  
  // Recursively check object
  function checkObject(obj, depth = 0) {
    // Prevent infinite recursion
    if (depth > 10) return false;
    
    if (Array.isArray(obj)) {
      return obj.some(item => checkObject(item, depth + 1));
    }
    
    if (obj && typeof obj === 'object') {
      for (const key in obj) {
        const lowerKey = key.toLowerCase();
        
        // Check if key contains sensitive field name
        if (sensitiveFields.some(field => lowerKey.includes(field.toLowerCase()))) {
          return true;
        }
        
        // Recursively check nested objects
        if (obj[key] && typeof obj[key] === 'object') {
          if (checkObject(obj[key], depth + 1)) {
            return true;
          }
        }
      }
    }
    
    return false;
  }
  
  return checkObject(data);
}

module.exports = {
  noCacheSensitiveData,
  preventSensitiveDataCache
};

