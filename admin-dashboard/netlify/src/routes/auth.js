import express from 'express';
import jwt from 'jsonwebtoken';
import { body, validationResult } from 'express-validator';
import AdminUser from '../models/AdminUser.js';
import { protect } from '../middleware/adminAuth.js';
import { authRateLimiter } from '../middleware/rateLimit.js';
import admin from 'firebase-admin';
import { processFirebasePrivateKey, validateFirebaseCredentials } from '../utils/firebaseKeyProcessor.js';

const router = express.Router();

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  try {
    const projectId = process.env.FIREBASE_PROJECT_ID?.trim();
    const rawPrivateKey = process.env.FIREBASE_PRIVATE_KEY;
    const clientEmail = process.env.FIREBASE_CLIENT_EMAIL?.trim();
    
    // Validate credentials first
    validateFirebaseCredentials(projectId, rawPrivateKey, clientEmail);
    
    // Process and format the private key
    const privateKey = processFirebasePrivateKey(rawPrivateKey);
    
    // Initialize Firebase Admin
    admin.initializeApp({
      credential: admin.credential.cert({
        projectId,
        privateKey,
        clientEmail,
      }),
    });
    console.log('Firebase Admin initialized successfully');
  } catch (error) {
    console.error('Firebase Admin initialization error:', error.message);
    console.error('Error details:', {
      code: error.code,
      name: error.name,
      stack: error.stack
    });
    // Log environment variable status (without sensitive values)
    console.error('Environment variable status:', {
      hasProjectId: !!process.env.FIREBASE_PROJECT_ID,
      hasPrivateKey: !!process.env.FIREBASE_PRIVATE_KEY,
      hasClientEmail: !!process.env.FIREBASE_CLIENT_EMAIL,
      privateKeyLength: process.env.FIREBASE_PRIVATE_KEY?.length || 0,
      projectIdValue: process.env.FIREBASE_PROJECT_ID || 'NOT SET',
      clientEmailValue: process.env.FIREBASE_CLIENT_EMAIL || 'NOT SET'
    });
  }
}

// Generate JWT token
const generateToken = (id) => {
  return jwt.sign({ id }, process.env.JWT_SECRET, {
    expiresIn: '24h'
  });
};

// @route   POST /api/admin/auth/login
// @desc    Admin login (with Firebase token or email/password)
// @access  Public
router.post(
  '/login',
  authRateLimiter,
  [
    body('firebaseToken').optional().isString(),
    body('email').optional().isEmail(),
    body('password').optional().isLength({ min: 6 })
  ],
  async (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
      }

      const { firebaseToken, email, password } = req.body;

      let adminUser;

      // Firebase token login
      if (firebaseToken) {
        try {
          const decodedToken = await admin.auth().verifyIdToken(firebaseToken);
          const firebaseUid = decodedToken.uid;
          const email = decodedToken.email;

          // Find or create admin user by Firebase UID
          adminUser = await AdminUser.findOne({ firebaseUid });

          if (!adminUser) {
            // Check if user exists by email
            adminUser = await AdminUser.findOne({ email: email?.toLowerCase()?.trim() });

            if (adminUser) {
              // Link Firebase UID to existing admin user
              adminUser.firebaseUid = firebaseUid;
              await adminUser.save();
            } else {
              // Check if user is admin in Firestore
              try {
                const userDoc = await admin.firestore().collection('users').doc(firebaseUid).get();
                const userData = userDoc.data();
                
                if (userData?.isAdmin) {
                  // User is admin in Firestore, create AdminUser record
                  adminUser = await AdminUser.create({
                    email: email?.toLowerCase()?.trim() || `admin-${firebaseUid}@orabeta.app`,
                    password: 'temp-password-' + Math.random().toString(36), // Temporary, won't be used
                    firebaseUid: firebaseUid,
                    role: 'super_admin', // Default to super_admin for existing admins
                    isActive: true
                  });
                  console.log(`Created AdminUser for existing Firebase admin: ${email}`);
                } else {
                  // User is not admin in Firestore
                  return res.status(403).json({ 
                    message: 'Admin account not found. Please contact administrator.' 
                  });
                }
              } catch (firestoreError) {
                console.error('Error checking Firestore admin status:', firestoreError);
                return res.status(403).json({ 
                  message: 'Admin account not found. Please contact administrator.' 
                });
              }
            }
          }

          if (!adminUser.isActive) {
            return res.status(403).json({ message: 'Admin account is inactive' });
          }

          adminUser.lastLogin = new Date();
          await adminUser.save();
        } catch (error) {
          console.error('Firebase token verification error:', error);
          return res.status(401).json({ message: 'Invalid Firebase token' });
        }
      } 
      // Email/password login
      else if (email && password) {
        const normalizedEmail = email.toLowerCase().trim();
        adminUser = await AdminUser.findOne({ email: normalizedEmail }).select('+password');

        if (!adminUser) {
          return res.status(401).json({ message: 'Invalid email or password' });
        }

        const isMatch = await adminUser.matchPassword(password);
        if (!isMatch) {
          return res.status(401).json({ message: 'Invalid email or password' });
        }

        if (!adminUser.isActive) {
          return res.status(403).json({ message: 'Admin account is inactive' });
        }

        adminUser.lastLogin = new Date();
        await adminUser.save();
      } else {
        return res.status(400).json({ message: 'Either firebaseToken or email/password required' });
      }

      const token = generateToken(adminUser._id);

      res.json({
        token,
        admin: {
          id: adminUser._id,
          email: adminUser.email,
          role: adminUser.role,
          firebaseUid: adminUser.firebaseUid
        }
      });
    } catch (error) {
      console.error('Login error:', error);
      res.status(500).json({ message: error.message });
    }
  }
);

// @route   GET /api/admin/auth/me
// @desc    Get current admin user
// @access  Private
router.get('/me', protect, async (req, res) => {
  try {
    res.json({
      id: req.admin._id,
      email: req.admin.email,
      role: req.admin.role,
      firebaseUid: req.admin.firebaseUid,
      lastLogin: req.admin.lastLogin,
      createdAt: req.admin.createdAt
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// @route   POST /api/admin/auth/refresh
// @desc    Refresh JWT token
// @access  Private
router.post('/refresh', protect, async (req, res) => {
  try {
    const token = generateToken(req.admin._id);
    res.json({ token });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

export default router;

