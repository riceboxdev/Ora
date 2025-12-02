import jwt from 'jsonwebtoken';
import AdminUser from '../models/AdminUser.js';
import connectDB from '../config/database.js';

export const protect = async (req, res, next) => {
  let token;

  if (req.headers.authorization && req.headers.authorization.startsWith('Bearer')) {
    token = req.headers.authorization.split(' ')[1];
  }

  if (!token) {
    return res.status(401).json({ message: 'Not authorized, no token' });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    // Try to connect to MongoDB if needed (only if MONGODB_URI is configured)
    if (process.env.MONGODB_URI) {
      try {
        await connectDB();
      } catch (dbError) {
        console.warn('MongoDB connection warning in protect middleware:', dbError.message);
        // If MongoDB connection fails, return error since we need it for AdminUser
        return res.status(500).json({ 
          message: 'Database connection error. Please check your MongoDB configuration.' 
        });
      }
    } else {
      // If MONGODB_URI is not configured, we can't authenticate with AdminUser
      return res.status(500).json({ 
        message: 'MongoDB not configured. Admin authentication requires MongoDB.' 
      });
    }
    
    req.admin = await AdminUser.findById(decoded.id).select('-password');
    
    if (!req.admin) {
      return res.status(401).json({ message: 'Admin user not found' });
    }

    if (!req.admin.isActive) {
      return res.status(401).json({ message: 'Admin account is inactive' });
    }
    
    next();
  } catch (error) {
    console.error('Auth error:', error);
    if (error.name === 'JsonWebTokenError' || error.name === 'TokenExpiredError') {
      return res.status(401).json({ message: 'Not authorized, token failed' });
    }
    if (error.name === 'MongooseError' || error.name === 'MongoServerError' || error.message?.includes('connection')) {
      return res.status(500).json({ message: 'Database connection error. Please try again.' });
    }
    return res.status(401).json({ message: 'Not authorized, token failed' });
  }
};

export const requireRole = (...roles) => {
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










