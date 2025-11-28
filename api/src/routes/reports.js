import express from 'express';
import admin from 'firebase-admin';
import { apiRateLimiter } from '../middleware/rateLimit.js';

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  try {
    const projectId = process.env.FIREBASE_PROJECT_ID?.trim();
    let privateKey = process.env.FIREBASE_PRIVATE_KEY;
    const clientEmail = process.env.FIREBASE_CLIENT_EMAIL?.trim();
    
    // Validate required Firebase credentials
    if (!projectId || !privateKey || !clientEmail) {
      console.error('Firebase Admin initialization failed: Missing required credentials', {
        hasProjectId: !!projectId,
        hasPrivateKey: !!privateKey,
        hasClientEmail: !!clientEmail
      });
    } else {
      // Process private key: handle both escaped and literal newlines
      // Replace escaped newlines first, then ensure proper formatting
      privateKey = privateKey.replace(/\\n/g, '\n');
      
      // Remove any leading/trailing whitespace
      privateKey = privateKey.trim();
      
      // Validate private key format
      if (!privateKey.includes('BEGIN PRIVATE KEY') || !privateKey.includes('END PRIVATE KEY')) {
        console.error('Firebase Admin initialization failed: Invalid private key format. Private key must include BEGIN/END markers.');
      } else {
        // Ensure the private key has proper line breaks
        // If it's all on one line, try to format it properly
        if (!privateKey.includes('\n') && privateKey.length > 100) {
          // It might be a single-line key, try to add newlines after markers
          privateKey = privateKey.replace(/-----BEGIN PRIVATE KEY-----/, '-----BEGIN PRIVATE KEY-----\n');
          privateKey = privateKey.replace(/-----END PRIVATE KEY-----/, '\n-----END PRIVATE KEY-----');
        }
        
        try {
          admin.initializeApp({
            credential: admin.credential.cert({
              projectId,
              privateKey,
              clientEmail,
            }),
          });
          console.log('Firebase Admin initialized successfully');
        } catch (initError) {
          console.error('Firebase Admin credential error:', initError.message);
          console.error('Private key length:', privateKey.length);
          console.error('Private key starts with:', privateKey.substring(0, 50));
          throw initError;
        }
      }
    }
  } catch (error) {
    console.error('Firebase Admin initialization error:', error.message);
    console.error('Error details:', {
      code: error.code,
      stack: error.stack
    });
  }
}

const router = express.Router();

// Middleware to verify Firebase token (for regular users)
const verifyFirebaseToken = async (req, res, next) => {
  let token;

  if (req.headers.authorization && req.headers.authorization.startsWith('Bearer')) {
    token = req.headers.authorization.split(' ')[1];
  }

  if (!token) {
    return res.status(401).json({ message: 'Not authorized, no token' });
  }

  try {
    const decodedToken = await admin.auth().verifyIdToken(token);
    req.user = {
      uid: decodedToken.uid,
      email: decodedToken.email
    };
    next();
  } catch (error) {
    console.error('Firebase token verification error:', error);
    return res.status(401).json({ message: 'Invalid or expired token' });
  }
};

// Apply rate limiting to all routes
router.use(apiRateLimiter);

// @route   GET /api/reports/my-reports
// @desc    Get all reports made by the current user
// @access  Private (requires Firebase Auth)
router.get('/my-reports', verifyFirebaseToken, async (req, res) => {
  try {
    const reporterId = req.user.uid;
    const db = admin.firestore();
    
    const reportsSnapshot = await db.collection('post_reports')
      .where('reporterId', '==', reporterId)
      .orderBy('createdAt', 'desc')
      .limit(100)
      .get();
    
    const reports = [];
    
    for (const doc of reportsSnapshot.docs) {
      const reportData = doc.data();
      const postId = reportData.postId;
      
      // Get post details
      let postData = null;
      try {
        const postDoc = await db.collection('posts').doc(postId).get();
        if (postDoc.exists) {
          const post = postDoc.data();
          postData = {
            id: postDoc.id,
            imageUrl: post.imageUrl,
            thumbnailUrl: post.thumbnailUrl,
            caption: post.caption,
            moderationStatus: post.moderationStatus,
            moderatedAt: post.moderatedAt?.toMillis?.() || null,
            moderationReason: post.moderationReason
          };
        }
      } catch (error) {
        console.error(`Error fetching post ${postId}:`, error);
      }
      
      reports.push({
        id: doc.id,
        postId: postId,
        reason: reportData.reason,
        description: reportData.description,
        status: reportData.status,
        createdAt: reportData.createdAt?.toMillis?.() || null,
        post: postData
      });
    }
    
    res.json({ reports, count: reports.length });
  } catch (error) {
    console.error('Error fetching user reports:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   POST /api/reports/posts/:id
// @desc    Report a post (public endpoint for users)
// @access  Private (requires Firebase Auth)
router.post('/posts/:id', verifyFirebaseToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { reason, description } = req.body;
    const reporterId = req.user.uid;

    if (!reason) {
      return res.status(400).json({ message: 'Reason is required' });
    }

    const db = admin.firestore();
    const postRef = db.collection('posts').doc(id);
    const postDoc = await postRef.get();

    if (!postDoc.exists) {
      return res.status(404).json({ message: 'Post not found' });
    }

    const postData = postDoc.data();

    // Check if user already reported this post
    const existingReport = await db.collection('post_reports')
      .where('postId', '==', id)
      .where('reporterId', '==', reporterId)
      .limit(1)
      .get();

    if (!existingReport.empty) {
      return res.status(400).json({ message: 'You have already reported this post' });
    }

    // Create report record
    const reportData = {
      postId: id,
      reporterId: reporterId,
      reason: reason,
      description: description || null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      status: 'pending'
    };

    await db.collection('post_reports').add(reportData);

    // Update post moderation status to 'pending' to ensure it appears in moderation queue
    // Only update if currently approved (don't overwrite existing moderation decisions)
    const currentStatus = postData.moderationStatus || 'approved';
    if (currentStatus === 'approved') {
      await postRef.update({
        moderationStatus: 'pending',
        moderationReason: `Reported by user: ${reason}${description ? ': ' + description : ''}`,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      console.log(`Post ${id} set to pending due to report. Previous status: ${currentStatus}, Reason: ${reason}`);
    } else {
      console.log(`Post ${id} already has status ${currentStatus}, skipping status update but report recorded`);
    }

    res.json({ 
      success: true, 
      message: 'Post reported successfully. It will be reviewed by moderators.' 
    });
  } catch (error) {
    console.error('Error reporting post:', error);
    res.status(500).json({ message: error.message });
  }
});

export default router;

