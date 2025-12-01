const jwt = require('jsonwebtoken');
const AdminUser = require('../models/AdminUser.js');

const protect = async (req, res, next) => {
  let token;

  if (req.headers.authorization && req.headers.authorization.startsWith('Bearer')) {
    token = req.headers.authorization.split(' ')[1];
  }

  if (!token) {
    return res.status(401).json({ message: 'Not authorized, no token' });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.admin = await AdminUser.findById(decoded.id).select('-password');
    
    if (!req.admin) {
      return res.status(401).json({ message: 'Admin user not found' });
    }

    if (!req.admin.isActive) {
      return res.status(401).json({ message: 'Admin account is inactive' });
    }
    
    next();
  } catch (error) {
    return res.status(401).json({ message: 'Not authorized, token failed' });
  }
};

const requireRole = (...roles) => {
  return (req, res, next) => {
    if (!req.admin) {
      return res.status(401).json({ message: 'Not authorized' });
    }

    if (!roles.includes(req.admin.role)) {
      return res.status(403).json({ message: 'Insufficient permissions' });
    }

    next();
  };
};

module.exports = { protect, requireRole };

