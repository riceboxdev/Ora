const admin = require('firebase-admin');

/**
 * Middleware to log admin actions to Firestore
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next function
 */
const logActivity = async (req, res, next) => {
  // Store original json method
  const originalJson = res.json.bind(res);
  
  // Override json method to log after response
  res.json = function(data) {
    // Log activity asynchronously (don't block response)
    logActivityAsync(req, res, data).catch(err => {
      console.error('Error logging activity:', err);
    });
    
    // Call original json method
    return originalJson(data);
  };
  
  next();
};

/**
 * Async function to log activity
 */
async function logActivityAsync(req, res, responseData) {
  try {
    // Only log successful operations (2xx status codes)
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return;
    }
    
    // Extract action from route
    const action = extractAction(req);
    if (!action) {
      return; // Don't log if no action identified
    }
    
    const db = admin.firestore();
    const adminId = req.admin?.firebaseUid || req.admin?._id?.toString() || 'unknown';
    const ipAddress = req.ip || req.headers['x-forwarded-for'] || req.connection.remoteAddress;
    
    // Extract target information
    const targetType = extractTargetType(req);
    const targetId = extractTargetId(req);
    
    // Extract metadata from request
    const metadata = {
      method: req.method,
      path: req.path,
      ...(req.body && Object.keys(req.body).length > 0 && { requestBody: sanitizeBody(req.body) })
    };
    
    // Add response metadata if available
    if (responseData && typeof responseData === 'object') {
      if (responseData.success !== undefined) {
        metadata.success = responseData.success;
      }
      if (responseData.message) {
        metadata.message = responseData.message;
      }
    }
    
    // Create activity log document
    const activityLog = {
      adminId,
      action,
      targetType,
      targetId,
      metadata,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      ipAddress: ipAddress?.split(',')[0]?.trim() || 'unknown'
    };
    
    // Store in admin_logs collection
    await db.collection('admin_logs').add(activityLog);
    
  } catch (error) {
    // Don't throw - logging failures shouldn't break the API
    console.error('Error in activity logger:', error);
  }
}

/**
 * Extract action from request
 */
function extractAction(req) {
  const method = req.method;
  const path = req.path;
  
  // Map routes to actions
  if (path.includes('/users/ban')) return 'ban';
  if (path.includes('/users/unban')) return 'unban';
  if (path.includes('/users') && method === 'DELETE') return 'delete';
  if (path.includes('/users') && method === 'POST' && path.includes('/warn')) return 'warn';
  if (path.includes('/users') && method === 'POST' && path.includes('/temp-ban')) return 'temp_ban';
  if (path.includes('/users') && method === 'PUT' && path.includes('/role')) return 'role_change';
  if (path.includes('/users/bulk')) return 'bulk_action';
  if (path.includes('/users') && method === 'GET' && path.match(/\/users\/[^/]+$/)) return 'view_profile';
  if (path.includes('/users/export')) return 'export_data';
  if (path.includes('/moderation/approve')) return 'approve_post';
  if (path.includes('/moderation/reject')) return 'reject_post';
  if (path.includes('/moderation/flag')) return 'flag_post';
  
  // Default: log GET requests to user list as 'view_users'
  if (path === '/users' && method === 'GET') return 'view_users';
  
  return null; // Don't log if action not identified
}

/**
 * Extract target type from request
 */
function extractTargetType(req) {
  if (req.path.includes('/users')) return 'user';
  if (req.path.includes('/posts')) return 'post';
  if (req.path.includes('/moderation')) return 'post';
  return 'unknown';
}

/**
 * Extract target ID from request
 */
function extractTargetId(req) {
  // Try to get from params
  if (req.params.userId) return req.params.userId;
  if (req.params.id) return req.params.id;
  if (req.params.postId) return req.params.postId;
  
  // Try to get from body
  if (req.body.userId) return req.body.userId;
  if (req.body.postId) return req.body.postId;
  if (req.body.userIds && Array.isArray(req.body.userIds) && req.body.userIds.length > 0) {
    return req.body.userIds.join(',');
  }
  
  return null;
}

/**
 * Sanitize request body to remove sensitive data
 */
function sanitizeBody(body) {
  const sanitized = { ...body };
  
  // Remove sensitive fields
  delete sanitized.password;
  delete sanitized.token;
  delete sanitized.secret;
  
  // Limit size of metadata
  if (JSON.stringify(sanitized).length > 1000) {
    return { _truncated: true, _size: JSON.stringify(sanitized).length };
  }
  
  return sanitized;
}

/**
 * Manual logging function for custom actions
 */
const logCustomActivity = async (adminId, action, targetType, targetId, metadata = {}) => {
  try {
    const db = admin.firestore();
    
    const activityLog = {
      adminId,
      action,
      targetType,
      targetId,
      metadata,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      ipAddress: 'system'
    };
    
    await db.collection('admin_logs').add(activityLog);
  } catch (error) {
    console.error('Error logging custom activity:', error);
  }
};

module.exports = { logActivity, logCustomActivity };








