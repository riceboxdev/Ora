import express from 'express';
import { protect, requireRole } from '../middleware/adminAuth.js';
import { apiRateLimiter } from '../middleware/rateLimit.js';
import admin from 'firebase-admin';
import multer from 'multer';
import FormData from 'form-data';

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  try {
    admin.initializeApp({
      credential: admin.credential.cert({
        projectId: process.env.FIREBASE_PROJECT_ID?.trim(),
        privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
        clientEmail: process.env.FIREBASE_CLIENT_EMAIL?.trim(),
      }),
    });
  } catch (error) {
    console.warn('Firebase Admin initialization warning:', error.message);
  }
}

const router = express.Router();

// All routes require authentication
router.use(protect);
router.use(apiRateLimiter);

// Helper to call Firebase Functions
const callFirebaseFunction = async (functionName, data, adminUser) => {
  // In production, you would call the actual Firebase Function
  // For now, we'll use Firebase Admin SDK to interact with Firestore directly
  // This is a simplified approach - in production, you'd want to use HTTP callable functions
  
  const db = admin.firestore();
  
  switch (functionName) {
    case 'getAdminUsers':
      return await getUsersFromFirestore(db);
    case 'getAdminAnalytics':
      return await getAnalyticsFromFirestore(db);
    case 'getModerationQueue':
      return await getModerationQueueFromFirestore(db, data?.status);
    default:
      throw new Error(`Unknown function: ${functionName}`);
  }
};

// Helper functions to interact with Firestore
async function getUsersFromFirestore(db) {
  const usersSnapshot = await db.collection('users').limit(100).get();
  const users = [];
  
  usersSnapshot.forEach(doc => {
    const data = doc.data();
    users.push({
      id: doc.id,
      email: data.email || null,
      displayName: data.displayName || null,
      photoURL: data.photoURL || null,
      createdAt: data.createdAt?.toMillis?.() || null,
      isBanned: data.isBanned || false,
      isAdmin: data.isAdmin || false
    });
  });
  
  return { 
    users, 
    count: users.length,
    total: users.length,
    limit: 100,
    offset: 0
  };
}

async function getAnalyticsFromFirestore(db) {
  const now = Date.now();
  const thirtyDaysAgo = now - (30 * 24 * 60 * 60 * 1000);
  
  // Get user count
  const usersSnapshot = await db.collection('users').get();
  const totalUsers = usersSnapshot.size;
  
  // Get posts in last 30 days
  const thirtyDaysAgoTimestamp = admin.firestore.Timestamp.fromMillis(thirtyDaysAgo);
  const postsSnapshot = await db.collection('posts')
    .where('createdAt', '>=', thirtyDaysAgoTimestamp)
    .get();
  
  const totalPosts = postsSnapshot.size;
  
  // Calculate engagement
  let totalLikes = 0;
  let totalComments = 0;
  let totalShares = 0;
  
  postsSnapshot.forEach(doc => {
    const data = doc.data();
    totalLikes += data.likeCount || 0;
    totalComments += data.commentCount || 0;
    totalShares += data.shareCount || 0;
  });
  
  // Get moderation status counts
  const pendingPosts = await db.collection('posts')
    .where('moderationStatus', '==', 'pending')
    .get();
  const flaggedPosts = await db.collection('posts')
    .where('moderationStatus', '==', 'flagged')
    .get();
  
  return {
    period: '30d',
    users: {
      total: totalUsers,
      new: 0 // Could calculate new users in period if needed
    },
    posts: {
      total: totalPosts,
      pending: pendingPosts.size,
      flagged: flaggedPosts.size
    },
    engagement: {
      likes: totalLikes,
      comments: totalComments,
      shares: totalShares,
      saves: 0, // Not tracked yet
      views: 0  // Not tracked yet
    }
  };
}

async function getModerationQueueFromFirestore(db, statusFilter = null) {
  let query = db.collection('posts');
  
  // Apply status filter if provided
  if (statusFilter && statusFilter !== 'all') {
    query = query.where('moderationStatus', '==', statusFilter);
  } else {
    // Default: get both pending and flagged posts
    query = query.where('moderationStatus', 'in', ['pending', 'flagged']);
  }
  
  // Order by createdAt descending
  query = query.orderBy('createdAt', 'desc').limit(50);
  
  const postsSnapshot = await query.get();
  
  const posts = [];
  postsSnapshot.forEach(doc => {
    const data = doc.data();
    posts.push({
      id: doc.id,
      userId: data.userId,
      username: data.username,
      userProfilePhotoUrl: data.userProfilePhotoUrl,
      imageUrl: data.imageUrl,
      thumbnailUrl: data.thumbnailUrl,
      caption: data.caption,
      tags: data.tags || [],
      moderationStatus: data.moderationStatus,
      moderationReason: data.moderationReason,
      moderatedAt: data.moderatedAt?.toMillis?.() || null,
      createdAt: data.createdAt?.toMillis?.() || null
    });
  });
  
  return { posts, count: posts.length };
}

// @route   GET /api/admin/users
// @desc    Get all users (with pagination)
// @access  Private (moderator+)
router.get('/users', requireRole('super_admin', 'moderator', 'viewer'), async (req, res) => {
  try {
    const result = await callFirebaseFunction('getAdminUsers', {}, req.admin);
    res.json(result);
  } catch (error) {
    console.error('Error fetching users:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   GET /api/admin/analytics
// @desc    Get analytics data
// @access  Private (viewer+)
router.get('/analytics', requireRole('super_admin', 'moderator', 'viewer'), async (req, res) => {
  try {
    const result = await callFirebaseFunction('getAdminAnalytics', {}, req.admin);
    res.json(result);
  } catch (error) {
    console.error('Error fetching analytics:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   GET /api/admin/moderation/queue
// @desc    Get moderation queue
// @access  Private (moderator+)
router.get('/moderation/queue', requireRole('super_admin', 'moderator'), async (req, res) => {
  try {
    const { status } = req.query;
    const result = await callFirebaseFunction('getModerationQueue', { status }, req.admin);
    res.json(result);
  } catch (error) {
    console.error('Error fetching moderation queue:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   POST /api/admin/moderation/approve
// @desc    Approve a post
// @access  Private (moderator+)
router.post('/moderation/approve', requireRole('super_admin', 'moderator'), async (req, res) => {
  try {
    const { postId } = req.body;
    if (!postId) {
      return res.status(400).json({ message: 'postId is required' });
    }
    
    // Call Firebase Function to moderate post
    const db = admin.firestore();
    const postRef = db.collection('posts').doc(postId);
    await postRef.update({
      moderationStatus: 'approved',
      moderatedAt: admin.firestore.FieldValue.serverTimestamp(),
      moderatedBy: req.admin.firebaseUid || req.admin._id.toString(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    res.json({ success: true, message: 'Post approved' });
  } catch (error) {
    console.error('Error approving post:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   POST /api/admin/moderation/reject
// @desc    Reject a post
// @access  Private (moderator+)
router.post('/moderation/reject', requireRole('super_admin', 'moderator'), async (req, res) => {
  try {
    const { postId } = req.body;
    if (!postId) {
      return res.status(400).json({ message: 'postId is required' });
    }
    
    const db = admin.firestore();
    const postRef = db.collection('posts').doc(postId);
    await postRef.update({
      moderationStatus: 'rejected',
      moderatedAt: admin.firestore.FieldValue.serverTimestamp(),
      moderatedBy: req.admin.firebaseUid || req.admin._id.toString(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    res.json({ success: true, message: 'Post rejected' });
  } catch (error) {
    console.error('Error rejecting post:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   POST /api/admin/moderation/flag
// @desc    Flag a post
// @access  Private (moderator+)
router.post('/moderation/flag', requireRole('super_admin', 'moderator'), async (req, res) => {
  try {
    const { postId } = req.body;
    if (!postId) {
      return res.status(400).json({ message: 'postId is required' });
    }
    
    const db = admin.firestore();
    const postRef = db.collection('posts').doc(postId);
    await postRef.update({
      moderationStatus: 'flagged',
      moderatedAt: admin.firestore.FieldValue.serverTimestamp(),
      moderatedBy: req.admin.firebaseUid || req.admin._id.toString(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    res.json({ success: true, message: 'Post flagged' });
  } catch (error) {
    console.error('Error flagging post:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   POST /api/admin/users/ban
// @desc    Ban a user
// @access  Private (super_admin+)
router.post('/users/ban', requireRole('super_admin', 'moderator'), async (req, res) => {
  try {
    const { userId } = req.body;
    if (!userId) {
      return res.status(400).json({ message: 'userId is required' });
    }
    
    const db = admin.firestore();
    const userRef = db.collection('users').doc(userId);
    await userRef.update({
      isBanned: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    res.json({ success: true, message: 'User banned' });
  } catch (error) {
    console.error('Error banning user:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   POST /api/admin/users/unban
// @desc    Unban a user
// @access  Private (super_admin+)
router.post('/users/unban', requireRole('super_admin', 'moderator'), async (req, res) => {
  try {
    const { userId } = req.body;
    if (!userId) {
      return res.status(400).json({ message: 'userId is required' });
    }
    
    const db = admin.firestore();
    const userRef = db.collection('users').doc(userId);
    await userRef.update({
      isBanned: false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    res.json({ success: true, message: 'User unbanned' });
  } catch (error) {
    console.error('Error unbanning user:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   GET /api/admin/appeals
// @desc    Get ban appeals
// @access  Private (super_admin+)
router.get('/appeals', requireRole('super_admin', 'moderator'), async (req, res) => {
  try {
    const { status, limit = 50 } = req.query;
    const db = admin.firestore();
    
    let query = db.collection('ban_appeals');
    
    if (status) {
      query = query.where('status', '==', status);
    }
    
    query = query.orderBy('submittedAt', 'desc').limit(parseInt(limit));
    
    const snapshot = await query.get();
    const appeals = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));
    
    res.json({ success: true, appeals });
  } catch (error) {
    console.error('Error fetching appeals:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   POST /api/admin/appeals/:appealId/review
// @desc    Review a ban appeal
// @access  Private (super_admin+)
router.post('/appeals/:appealId/review', requireRole('super_admin', 'moderator'), async (req, res) => {
  try {
    const { appealId } = req.params;
    const { status, reviewNotes } = req.body;
    
    if (!status || !['approved', 'rejected'].includes(status)) {
      return res.status(400).json({ message: "status must be 'approved' or 'rejected'" });
    }
    
    const db = admin.firestore();
    const appealRef = db.collection('ban_appeals').doc(appealId);
    const appealDoc = await appealRef.get();
    
    if (!appealDoc.exists) {
      return res.status(404).json({ message: 'Appeal not found' });
    }
    
    const appealData = appealDoc.data();
    if (appealData.status !== 'pending') {
      return res.status(400).json({ message: 'Appeal has already been reviewed' });
    }
    
    const adminId = req.admin.firebaseUid || req.admin._id.toString();
    const userId = appealData.userId;
    
    // Update appeal
    await appealRef.update({
      status: status,
      reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
      reviewedBy: adminId,
      reviewNotes: reviewNotes || null
    });
    
    // If approved, unban the user
    if (status === 'approved') {
      const userRef = db.collection('users').doc(userId);
      await userRef.update({
        isBanned: false,
        banReason: null,
        bannedAt: null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }
    
    res.json({ success: true, message: `Appeal ${status}` });
  } catch (error) {
    console.error('Error reviewing appeal:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   GET /api/admin/settings
// @desc    Get system settings
// @access  Private (viewer+)
router.get('/settings', requireRole('super_admin', 'moderator', 'viewer'), async (req, res) => {
  try {
    const db = admin.firestore();
    const settingsDoc = await db.collection('system_settings').doc('main').get();
    
    if (!settingsDoc.exists) {
      return res.json({
        settings: {
          featureFlags: {},
          remoteConfig: {},
          maintenanceMode: false
        }
      });
    }
    
    res.json({ settings: settingsDoc.data() });
  } catch (error) {
    console.error('Error fetching settings:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   POST /api/admin/settings
// @desc    Update system settings
// @access  Private (super_admin only)
router.post('/settings', requireRole('super_admin'), async (req, res) => {
  try {
    const { featureFlags, remoteConfig, maintenanceMode } = req.body;
    const db = admin.firestore();
    const settingsRef = db.collection('system_settings').doc('main');
    
    const updateData = {
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: req.admin.firebaseUid || req.admin._id.toString()
    };
    
    if (featureFlags !== undefined) {
      updateData.featureFlags = featureFlags;
    }
    if (remoteConfig !== undefined) {
      updateData.remoteConfig = remoteConfig;
    }
    if (maintenanceMode !== undefined) {
      updateData.maintenanceMode = maintenanceMode;
    }
    
    await settingsRef.set(updateData, { merge: true });
    
    res.json({ success: true, settings: updateData });
  } catch (error) {
    console.error('Error updating settings:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   GET /api/admin/posts
// @desc    Get posts (for content management) with filtering and sorting
// @access  Private (viewer+)
router.get('/posts', requireRole('super_admin', 'moderator', 'viewer'), async (req, res) => {
  try {
    const { 
      limit = 50, 
      offset = 0, 
      status, 
      userId, 
      startDate, 
      endDate,
      tag,
      sortBy = 'createdAt',
      sortOrder = 'desc'
    } = req.query;
    
    const db = admin.firestore();
    let query = db.collection('posts');
    
    // Apply filters
    if (status && status !== 'all') {
      query = query.where('moderationStatus', '==', status);
    }
    
    if (userId) {
      query = query.where('userId', '==', userId);
    }
    
    if (startDate) {
      const startTimestamp = admin.firestore.Timestamp.fromMillis(parseInt(startDate));
      query = query.where('createdAt', '>=', startTimestamp);
    }
    
    if (endDate) {
      const endTimestamp = admin.firestore.Timestamp.fromMillis(parseInt(endDate));
      query = query.where('createdAt', '<=', endTimestamp);
    }
    
    // Apply sorting
    const orderByField = sortBy || 'createdAt';
    const orderDirection = sortOrder === 'asc' ? 'asc' : 'desc';
    query = query.orderBy(orderByField, orderDirection);
    
    // Apply pagination
    const limitNum = parseInt(limit);
    const offsetNum = parseInt(offset);
    query = query.limit(limitNum).offset(offsetNum);
    
    const postsSnapshot = await query.get();
    
    const posts = [];
    postsSnapshot.forEach(doc => {
      const data = doc.data();
      const post = {
        id: doc.id,
        activityId: data.activityId || doc.id,
        userId: data.userId,
        username: data.username,
        userProfilePhotoUrl: data.userProfilePhotoUrl,
        imageUrl: data.imageUrl,
        thumbnailUrl: data.thumbnailUrl,
        imageWidth: data.imageWidth,
        imageHeight: data.imageHeight,
        caption: data.caption,
        tags: data.tags || [],
        categories: data.categories || [],
        likeCount: data.likeCount || 0,
        commentCount: data.commentCount || 0,
        viewCount: data.viewCount || 0,
        shareCount: data.shareCount || 0,
        saveCount: data.saveCount || 0,
        moderationStatus: data.moderationStatus || 'pending',
        moderatedAt: data.moderatedAt?.toMillis?.() || null,
        moderatedBy: data.moderatedBy,
        moderationReason: data.moderationReason,
        createdAt: data.createdAt?.toMillis?.() || null,
        updatedAt: data.updatedAt?.toMillis?.() || null
      };
      
      // Filter by tag if specified (client-side filter since Firestore doesn't support array-contains with other filters easily)
      if (tag && post.tags && !post.tags.includes(tag)) {
        return; // Skip this post
      }
      
      posts.push(post);
    });
    
    // Get total count for pagination (simplified - in production, you might want a separate count query)
    const totalSnapshot = await db.collection('posts').get();
    const total = totalSnapshot.size;
    
    res.json({ posts, count: posts.length, total, limit: limitNum, offset: offsetNum });
  } catch (error) {
    console.error('Error fetching posts:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   GET /api/admin/posts/:id
// @desc    Get detailed post view
// @access  Private (viewer+)
router.get('/posts/:id', requireRole('super_admin', 'moderator', 'viewer'), async (req, res) => {
  try {
    const { id } = req.params;
    const db = admin.firestore();
    
    const postDoc = await db.collection('posts').doc(id).get();
    
    if (!postDoc.exists) {
      return res.status(404).json({ message: 'Post not found' });
    }
    
    const data = postDoc.data();
    
    // Get user info
    let userInfo = null;
    if (data.userId) {
      try {
        const userDoc = await db.collection('users').doc(data.userId).get();
        if (userDoc.exists) {
          const userData = userDoc.data();
          userInfo = {
            id: userDoc.id,
            email: userData.email,
            displayName: userData.displayName,
            photoURL: userData.photoURL,
            isBanned: userData.isBanned || false
          };
        }
      } catch (error) {
        console.error('Error fetching user info:', error);
      }
    }
    
    const post = {
      id: postDoc.id,
      activityId: data.activityId || postDoc.id,
      userId: data.userId,
      username: data.username,
      userProfilePhotoUrl: data.userProfilePhotoUrl,
      imageUrl: data.imageUrl,
      thumbnailUrl: data.thumbnailUrl,
      imageWidth: data.imageWidth,
      imageHeight: data.imageHeight,
      caption: data.caption,
      tags: data.tags || [],
      categories: data.categories || [],
      likeCount: data.likeCount || 0,
      commentCount: data.commentCount || 0,
      viewCount: data.viewCount || 0,
      shareCount: data.shareCount || 0,
      saveCount: data.saveCount || 0,
      moderationStatus: data.moderationStatus || 'pending',
      moderatedAt: data.moderatedAt?.toMillis?.() || null,
      moderatedBy: data.moderatedBy,
      moderationReason: data.moderationReason,
      moderationMetadata: data.moderationMetadata || {},
      createdAt: data.createdAt?.toMillis?.() || null,
      updatedAt: data.updatedAt?.toMillis?.() || null,
      edited: data.edited || false,
      user: userInfo
    };
    
    res.json({ post });
  } catch (error) {
    console.error('Error fetching post:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   PUT /api/admin/posts/:id
// @desc    Update a post
// @access  Private (moderator+)
router.put('/posts/:id', requireRole('super_admin', 'moderator'), async (req, res) => {
  try {
    const { id } = req.params;
    const { caption, tags, categories, moderationStatus } = req.body;
    
    const db = admin.firestore();
    const postRef = db.collection('posts').doc(id);
    
    // Check if post exists
    const postDoc = await postRef.get();
    if (!postDoc.exists) {
      return res.status(404).json({ message: 'Post not found' });
    }
    
    const updateData = {
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      edited: true
    };
    
    if (caption !== undefined) {
      updateData.caption = caption;
    }
    
    if (tags !== undefined) {
      updateData.tags = Array.isArray(tags) ? tags : tags.split(',').map(t => t.trim()).filter(t => t);
    }
    
    if (categories !== undefined) {
      updateData.categories = Array.isArray(categories) ? categories : categories.split(',').map(c => c.trim()).filter(c => c);
    }
    
    if (moderationStatus !== undefined) {
      updateData.moderationStatus = moderationStatus;
      updateData.moderatedAt = admin.firestore.FieldValue.serverTimestamp();
      updateData.moderatedBy = req.admin.firebaseUid || req.admin._id.toString();
    }
    
    await postRef.update(updateData);
    
    // Fetch updated post
    const updatedDoc = await postRef.get();
    const data = updatedDoc.data();
    
    const updatedPost = {
      id: updatedDoc.id,
      ...data,
      createdAt: data.createdAt?.toMillis?.() || null,
      updatedAt: data.updatedAt?.toMillis?.() || null,
      moderatedAt: data.moderatedAt?.toMillis?.() || null
    };
    
    res.json({ success: true, post: updatedPost, message: 'Post updated successfully' });
  } catch (error) {
    console.error('Error updating post:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   POST /api/admin/posts/bulk
// @desc    Perform bulk actions on posts
// @access  Private (moderator+)
router.post('/posts/bulk', requireRole('super_admin', 'moderator'), async (req, res) => {
  try {
    const { postIds, action, moderationStatus, moderationReason } = req.body;
    
    if (!postIds || !Array.isArray(postIds) || postIds.length === 0) {
      return res.status(400).json({ message: 'postIds array is required' });
    }
    
    if (!action) {
      return res.status(400).json({ message: 'action is required' });
    }
    
    const db = admin.firestore();
    const batch = db.batch();
    const adminId = req.admin.firebaseUid || req.admin._id.toString();
    
    let updateData = {};
    
    switch (action) {
      case 'delete':
        // Delete posts
        postIds.forEach(postId => {
          const postRef = db.collection('posts').doc(postId);
          batch.delete(postRef);
        });
        break;
        
      case 'approve':
        updateData = {
          moderationStatus: 'approved',
          moderatedAt: admin.firestore.FieldValue.serverTimestamp(),
          moderatedBy: adminId,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        };
        if (moderationReason) {
          updateData.moderationReason = moderationReason;
        }
        postIds.forEach(postId => {
          const postRef = db.collection('posts').doc(postId);
          batch.update(postRef, updateData);
        });
        break;
        
      case 'reject':
        updateData = {
          moderationStatus: 'rejected',
          moderatedAt: admin.firestore.FieldValue.serverTimestamp(),
          moderatedBy: adminId,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        };
        if (moderationReason) {
          updateData.moderationReason = moderationReason;
        }
        postIds.forEach(postId => {
          const postRef = db.collection('posts').doc(postId);
          batch.update(postRef, updateData);
        });
        break;
        
      case 'flag':
        updateData = {
          moderationStatus: 'flagged',
          moderatedAt: admin.firestore.FieldValue.serverTimestamp(),
          moderatedBy: adminId,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        };
        if (moderationReason) {
          updateData.moderationReason = moderationReason;
        }
        postIds.forEach(postId => {
          const postRef = db.collection('posts').doc(postId);
          batch.update(postRef, updateData);
        });
        break;
        
      default:
        return res.status(400).json({ message: 'Invalid action. Must be: delete, approve, reject, or flag' });
    }
    
    await batch.commit();
    
    res.json({ 
      success: true, 
      message: `Successfully ${action}d ${postIds.length} post(s)`,
      count: postIds.length
    });
  } catch (error) {
    console.error('Error performing bulk action:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   DELETE /api/admin/posts/:id
// @desc    Delete a post
// @access  Private (moderator+)
router.delete('/posts/:id', requireRole('super_admin', 'moderator'), async (req, res) => {
  try {
    const { id } = req.params;
    const db = admin.firestore();
    await db.collection('posts').doc(id).delete();
    
    res.json({ success: true, message: 'Post deleted' });
  } catch (error) {
    console.error('Error deleting post:', error);
    res.status(500).json({ message: error.message });
  }
});

// =========================
// Bulk Upload Routes
// =========================

// Configure multer for file uploads
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 50 * 1024 * 1024 // 50MB limit
  },
  fileFilter: (req, file, cb) => {
    // Accept image files
    const allowedMimes = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp', 'image/heic', 'image/heif'];
    if (allowedMimes.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('Invalid file type. Only image files are allowed.'));
    }
  }
});

// @route   POST /api/admin/posts/upload-image
// @desc    Upload a single image to Cloudflare Images
// @access  Private (moderator+)
router.post('/posts/upload-image', requireRole('super_admin', 'moderator'), upload.single('image'), async (req, res) => {
  try {
    // Debug logging
    console.log('Upload request received:', {
      hasFile: !!req.file,
      fileField: req.file?.fieldname,
      fileName: req.file?.originalname,
      fileSize: req.file?.size,
      bodyKeys: Object.keys(req.body || {}),
      contentType: req.headers['content-type']
    });

    if (!req.file) {
      console.error('No file in request:', {
        files: req.files,
        body: req.body,
        headers: req.headers
      });
      return res.status(400).json({ 
        message: 'No image file provided',
        debug: {
          hasFiles: !!req.files,
          bodyKeys: Object.keys(req.body || {}),
          contentType: req.headers['content-type']
        }
      });
    }

    // Get Cloudflare credentials from environment (same as Firebase Function)
    const accountId = process.env.CLOUDFLARE_ACCOUNT_ID || "9f5f4bb22646ea1c62d1019e99026a66";
    const apiToken = process.env.CLOUDFLARE_API_TOKEN || "11HhvRaGba4Xc9hye24x5MOqEy90SMrh";

    if (!accountId || !apiToken) {
      console.error('Cloudflare credentials missing:', {
        hasAccountId: !!accountId,
        hasApiToken: !!apiToken,
        accountIdLength: accountId?.length,
        apiTokenLength: apiToken?.length
      });
      return res.status(500).json({ 
        message: 'Cloudflare credentials not configured',
        debug: {
          hasAccountId: !!accountId,
          hasApiToken: !!apiToken
        }
      });
    }

    // Log token info (without exposing the full token)
    console.log('Cloudflare credentials check:', {
      accountId: accountId.substring(0, 10) + '...',
      apiTokenLength: apiToken.length,
      apiTokenPrefix: apiToken.substring(0, 10) + '...'
    });

    // Build upload URL
    const uploadUrl = `https://api.cloudflare.com/client/v4/accounts/${accountId}/images/v1`;

    // Manually build multipart form data (matching iOS implementation)
    const boundary = `----WebKitFormBoundary${Math.random().toString(36).substring(2, 15)}`;
    const CRLF = '\r\n';
    
    // Build multipart body parts
    const parts = [];
    
    // Part 1: File
    parts.push(Buffer.from(`--${boundary}${CRLF}`, 'utf8'));
    parts.push(Buffer.from(`Content-Disposition: form-data; name="file"; filename="${req.file.originalname || 'image.jpg'}"${CRLF}`, 'utf8'));
    parts.push(Buffer.from(`Content-Type: ${req.file.mimetype || 'image/jpeg'}${CRLF}${CRLF}`, 'utf8'));
    parts.push(req.file.buffer);
    parts.push(Buffer.from(CRLF, 'utf8'));
    
    // Part 2: Metadata
    const metadata = { userId: req.admin.firebaseUid || req.admin._id?.toString() || 'admin' };
    const metadataJson = JSON.stringify(metadata);
    parts.push(Buffer.from(`--${boundary}${CRLF}`, 'utf8'));
    parts.push(Buffer.from(`Content-Disposition: form-data; name="metadata"${CRLF}${CRLF}`, 'utf8'));
    parts.push(Buffer.from(metadataJson, 'utf8'));
    parts.push(Buffer.from(CRLF, 'utf8'));
    
    // Part 3: requireSignedURLs
    parts.push(Buffer.from(`--${boundary}${CRLF}`, 'utf8'));
    parts.push(Buffer.from(`Content-Disposition: form-data; name="requireSignedURLs"${CRLF}${CRLF}`, 'utf8'));
    parts.push(Buffer.from('false', 'utf8'));
    parts.push(Buffer.from(CRLF, 'utf8'));
    
    // Close boundary
    parts.push(Buffer.from(`--${boundary}--${CRLF}`, 'utf8'));
    
    // Combine all parts
    const multipartBody = Buffer.concat(parts);

    const headers = {
      'Authorization': `Bearer ${apiToken}`,
      'Content-Type': `multipart/form-data; boundary=${boundary}`,
      'Content-Length': multipartBody.length.toString()
    };

    console.log('Uploading to Cloudflare:', {
      url: uploadUrl,
      hasAuthHeader: !!headers.Authorization,
      authHeaderLength: headers.Authorization?.length,
      contentType: headers['Content-Type'],
      contentLength: headers['Content-Length'],
      fileSize: req.file.size,
      boundary: boundary.substring(0, 20) + '...'
    });

    const response = await fetch(uploadUrl, {
      method: 'POST',
      headers: headers,
      body: multipartBody
    });

    if (!response.ok) {
      const errorText = await response.text();
      let errorData;
      try {
        errorData = JSON.parse(errorText);
      } catch (e) {
        errorData = { message: errorText };
      }
      
      console.error('Cloudflare upload error:', {
        status: response.status,
        statusText: response.statusText,
        error: errorData,
        hasToken: !!apiToken,
        tokenLength: apiToken?.length,
        accountId: accountId?.substring(0, 10) + '...'
      });
      
      // Provide more helpful error messages
      if (errorData.errors && errorData.errors[0]?.code === 10001) {
        return res.status(401).json({ 
          message: 'Cloudflare authentication failed. Please check CLOUDFLARE_API_TOKEN environment variable.',
          error: 'Unable to authenticate request',
          hint: 'The API token may be missing, invalid, or expired. Check Vercel environment variables.'
        });
      }
      
      return res.status(response.status).json({ 
        message: 'Failed to upload image to Cloudflare',
        error: errorData.message || errorText,
        details: errorData
      });
    }

    const result = await response.json();
    
    // Extract image URL from Cloudflare response
    // Cloudflare returns: { result: { id, filename, uploaded, requireSignedURLs, variants: [...] } }
    if (!result.result || !result.result.variants || result.result.variants.length === 0) {
      return res.status(500).json({ message: 'Invalid response from Cloudflare' });
    }

    // The first variant is typically the full image URL
    const imageUrl = result.result.variants[0];
    // For now, use the same URL for thumbnail (as per iOS implementation)
    const thumbnailUrl = imageUrl;

    // Extract image dimensions if available
    let imageWidth = null;
    let imageHeight = null;
    
    // Try to get dimensions from the file buffer
    // For now, we'll extract them client-side, but we can add server-side extraction if needed
    if (req.body.imageWidth) {
      imageWidth = parseInt(req.body.imageWidth);
    }
    if (req.body.imageHeight) {
      imageHeight = parseInt(req.body.imageHeight);
    }

    res.json({
      success: true,
      imageUrl,
      thumbnailUrl,
      imageWidth,
      imageHeight
    });
  } catch (error) {
    console.error('Error uploading image:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   POST /api/admin/posts/bulk-create
// @desc    Create multiple posts in Firestore
// @access  Private (moderator+)
router.post('/posts/bulk-create', requireRole('super_admin', 'moderator'), async (req, res) => {
  const db = admin.firestore();
  const createdPostIds = [];
  const uploadedImageUrls = [];

  try {
    const { posts } = req.body;

    if (!posts || !Array.isArray(posts) || posts.length === 0) {
      return res.status(400).json({ message: 'posts array is required and must not be empty' });
    }

    // Validate all posts have required fields
    const validationErrors = [];
    for (let i = 0; i < posts.length; i++) {
      const post = posts[i];
      if (!post.userId || !post.imageUrl || !post.thumbnailUrl) {
        validationErrors.push(`Post ${i + 1}: missing required fields (userId, imageUrl, or thumbnailUrl)`);
      } else {
        uploadedImageUrls.push(post.imageUrl);
      }
    }

    if (validationErrors.length > 0) {
      return res.status(400).json({ 
        message: 'Validation failed',
        errors: validationErrors
      });
    }

    const batch = db.batch();
    const createdPosts = [];

    // Create posts in batch
    for (const postData of posts) {
      // Generate post ID
      const postId = `post_${postData.userId}_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
      const postRef = db.collection('posts').doc(postId);
      createdPostIds.push(postId);

      // Get user info for username and profile photo
      let username = 'Admin';
      let userProfilePhotoUrl = null;
      try {
        const userDoc = await db.collection('users').doc(postData.userId).get();
        if (userDoc.exists) {
          const userData = userDoc.data();
          username = userData.displayName || userData.email || 'Admin';
          userProfilePhotoUrl = userData.photoURL || null;
        }
      } catch (error) {
        console.warn(`Could not fetch user info for ${postData.userId}:`, error.message);
      }

      // Build post document
      const postDoc = {
        activityId: postId,
        userId: postData.userId,
        username: username,
        userProfilePhotoUrl: userProfilePhotoUrl,
        imageUrl: postData.imageUrl,
        thumbnailUrl: postData.thumbnailUrl,
        caption: postData.caption || null,
        tags: Array.isArray(postData.tags) ? postData.tags : [],
        categories: Array.isArray(postData.categories) ? postData.categories : [],
        likeCount: 0,
        commentCount: 0,
        viewCount: 0,
        shareCount: 0,
        saveCount: 0,
        moderationStatus: 'approved', // Admin-created posts are auto-approved
        moderatedAt: null,
        moderatedBy: null,
        moderationReason: null,
        moderationMetadata: null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };

      // Add optional image dimensions
      if (postData.imageWidth) {
        postDoc.imageWidth = parseInt(postData.imageWidth);
      }
      if (postData.imageHeight) {
        postDoc.imageHeight = parseInt(postData.imageHeight);
      }

      batch.set(postRef, postDoc);
      createdPosts.push({ id: postId, ...postDoc });
    }

    // Commit batch
    await batch.commit();

    console.log(`Successfully created ${createdPosts.length} posts`);

    res.json({
      success: true,
      message: `Successfully created ${createdPosts.length} post(s)`,
      posts: createdPosts.map(p => ({ id: p.id, userId: p.userId, imageUrl: p.imageUrl }))
    });
  } catch (error) {
    console.error('Error creating posts:', error);
    
    // Rollback: Delete any posts that were created
    if (createdPostIds.length > 0) {
      console.log(`Rolling back: Deleting ${createdPostIds.length} created posts`);
      const rollbackBatch = db.batch();
      for (const postId of createdPostIds) {
        const postRef = db.collection('posts').doc(postId);
        rollbackBatch.delete(postRef);
      }
      
      try {
        await rollbackBatch.commit();
        console.log('Rollback completed: All created posts deleted');
      } catch (rollbackError) {
        console.error('Rollback failed:', rollbackError);
        // Log the post IDs that need manual cleanup
        console.error('Posts that may need manual cleanup:', createdPostIds);
      }
    }

    res.status(500).json({ 
      message: error.message || 'Failed to create posts',
      rollbackAttempted: createdPostIds.length > 0,
      createdPostIds: createdPostIds.length > 0 ? createdPostIds : undefined
    });
  }
});

// =========================
// Notification Management Routes
// =========================

// @route   POST /api/admin/notifications
// @desc    Create promotional notification
// @access  Private (super_admin+)
router.post('/notifications', requireRole('super_admin'), async (req, res) => {
  try {
    const { title, body, type, targetAudience, imageUrl, deepLink, scheduledFor } = req.body;
    
    if (!title || !body || !type || !targetAudience) {
      return res.status(400).json({ message: 'title, body, type, and targetAudience are required' });
    }
    
    const validTypes = ['announcement', 'promo', 'feature_update', 'event'];
    if (!validTypes.includes(type)) {
      return res.status(400).json({ message: `type must be one of: ${validTypes.join(', ')}` });
    }
    
    const db = admin.firestore();
    const adminId = req.admin.firebaseUid || req.admin._id?.toString() || 'unknown';
    
    // Create promotional notification document
    const promoNotification = {
      title,
      body,
      type,
      targetAudience,
      sentBy: adminId,
      status: scheduledFor ? 'scheduled' : 'sending', // Send immediately if not scheduled
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      stats: {
        totalRecipients: 0,
        delivered: 0,
        opened: 0,
        clicked: 0,
      },
    };
    
    if (imageUrl) {
      promoNotification.imageUrl = imageUrl;
    }
    if (deepLink) {
      promoNotification.deepLink = deepLink;
    }
    if (scheduledFor) {
      // Convert scheduledFor to Firestore Timestamp if it's a string or number
      const scheduledDate = scheduledFor instanceof Date 
        ? admin.firestore.Timestamp.fromDate(scheduledFor)
        : typeof scheduledFor === 'string' || typeof scheduledFor === 'number'
        ? admin.firestore.Timestamp.fromDate(new Date(scheduledFor))
        : scheduledFor;
      promoNotification.scheduledFor = scheduledDate;
    } else {
      // If not scheduled, set sentAt timestamp
      promoNotification.sentAt = admin.firestore.FieldValue.serverTimestamp();
    }
    
    const notificationRef = await db.collection('promotional_notifications').add(promoNotification);
    const notificationId = notificationRef.id;
    
    // If not scheduled, send immediately using Firebase Admin SDK
    if (!scheduledFor) {
      try {
        // Get target user IDs based on audience
        let targetUserIds = [];
        
        if (targetAudience.type === 'all') {
          const usersSnapshot = await db.collection('users').get();
          targetUserIds = usersSnapshot.docs.map(doc => doc.id);
        } else if (targetAudience.type === 'role') {
          const role = targetAudience.filters?.role || 'user';
          const usersSnapshot = await db.collection('users')
            .where('isAdmin', '==', role === 'admin')
            .get();
          targetUserIds = usersSnapshot.docs.map(doc => doc.id);
        } else if (targetAudience.type === 'activity') {
          const days = targetAudience.filters?.days || 30;
          const cutoffDate = new Date();
          cutoffDate.setDate(cutoffDate.getDate() - days);
          const cutoffTimestamp = admin.firestore.Timestamp.fromDate(cutoffDate);
          
          const recentPostsSnapshot = await db.collection('posts')
            .where('createdAt', '>=', cutoffTimestamp)
            .get();
          
          const userIds = new Set();
          recentPostsSnapshot.docs.forEach(doc => {
            const userId = doc.data().userId;
            if (userId) userIds.add(userId);
          });
          targetUserIds = Array.from(userIds);
        } else if (targetAudience.type === 'custom') {
          targetUserIds = targetAudience.filters?.userIds || [];
        }
        
        // Filter by user preferences (simplified - check if user has promotional enabled)
        const eligibleUserIds = [];
        const skippedUsers = [];
        
        for (const userId of targetUserIds) {
          try {
            const prefsDoc = await db.collection('users')
              .doc(userId)
              .collection('notification_preferences')
              .doc('settings')
              .get();
            
            let shouldReceive = false;
            
            if (!prefsDoc.exists) {
              // If preferences don't exist, default to opt-out (promotional is opt-in)
              // BUT: For testing, we'll include users without preferences if they're in "all" audience
              if (targetAudience.type === 'all') {
                // Include user even without preferences for testing
                eligibleUserIds.push(userId);
                continue;
              }
              skippedUsers.push({ userId, reason: 'no_preferences' });
              continue;
            }
            
            const prefs = prefsDoc.data();
            const promoPrefs = prefs?.promotional || {};
            
            // Must have promotional notifications enabled
            // BUT: For testing with "all" audience, bypass this check
            if (!promoPrefs.enabled) {
              if (targetAudience.type === 'all') {
                // Include user even if promotional disabled for testing
                eligibleUserIds.push(userId);
                continue;
              }
              skippedUsers.push({ userId, reason: 'promotional_disabled' });
              continue;
            }
            
            // Check specific type preference
            switch (type) {
              case 'announcement':
                shouldReceive = promoPrefs.announcements !== false;
                break;
              case 'promo':
                shouldReceive = promoPrefs.promos !== false;
                break;
              case 'feature_update':
                shouldReceive = promoPrefs.featureUpdates !== false;
                break;
              case 'event':
                shouldReceive = promoPrefs.events !== false;
                break;
              default:
                shouldReceive = true;
            }
            
            if (shouldReceive) {
              eligibleUserIds.push(userId);
            } else {
              skippedUsers.push({ userId, reason: `type_${type}_disabled` });
            }
          } catch (error) {
            console.error(`Error checking preferences for user ${userId}:`, error);
            skippedUsers.push({ userId, reason: `error: ${error.message}` });
          }
        }
        
        console.log(`Notification targeting: ${targetUserIds.length} total, ${eligibleUserIds.length} eligible, ${skippedUsers.length} skipped`);
        if (skippedUsers.length > 0 && skippedUsers.length <= 10) {
          console.log('Skipped users:', skippedUsers);
        }
        
        // Update stats with recipient count
        await notificationRef.update({
          'stats.totalRecipients': eligibleUserIds.length
        });
        
        // Send push notifications to eligible users
        let totalSent = 0;
        let totalFailed = 0;
        
        // Process in batches
        const batchSize = 100;
        for (let i = 0; i < eligibleUserIds.length; i += batchSize) {
          const batch = eligibleUserIds.slice(i, i + batchSize);
          
          const sendPromises = batch.map(async (userId) => {
            try {
              // Get FCM tokens for user
              const tokensSnapshot = await db.collection('users')
                .doc(userId)
                .collection('fcm_tokens')
                .get();
              
              const tokens = [];
              tokensSnapshot.forEach(doc => {
                const tokenData = doc.data();
                if (tokenData.token && tokenData.enabled !== false) {
                  tokens.push(tokenData.token);
                }
              });
              
              if (tokens.length === 0) return { sent: 0, failed: 0 };
              
              // Build deep link
              const notificationDeepLink = deepLink || `ora://notification/${notificationId}`;
              
              // Build FCM message for background delivery
              const message = {
                notification: {
                  title,
                  body,
                },
                data: {
                  type,
                  category: 'promotional',
                  targetId: notificationId,
                  notificationId,
                  deepLink: notificationDeepLink,
                  ...(imageUrl && { imageUrl }),
                },
                apns: {
                  payload: {
                    aps: {
                      sound: 'default',
                      badge: 1,
                      'content-available': 1, // Enable background delivery
                      'mutable-content': 1,
                    },
                  },
                  ...(imageUrl && {
                    fcmOptions: {
                      imageUrl,
                    },
                  }),
                },
                android: {
                  priority: 'high',
                  notification: {
                    sound: 'default',
                    channelId: 'promotional',
                  },
                },
                tokens,
              };
              
              const response = await admin.messaging().sendEachForMulticast(message);
              
              // Remove invalid tokens
              if (response.failureCount > 0) {
                response.responses.forEach((resp, idx) => {
                  if (!resp.success && (
                    resp.error?.code === 'messaging/invalid-registration-token' ||
                    resp.error?.code === 'messaging/registration-token-not-registered'
                  )) {
                    const token = tokens[idx];
                    db.collection('users')
                      .doc(userId)
                      .collection('fcm_tokens')
                      .where('token', '==', token)
                      .get()
                      .then(snapshot => {
                        const batch = db.batch();
                        snapshot.forEach(doc => batch.delete(doc.ref));
                        return batch.commit();
                      })
                      .catch(err => console.error('Error removing token:', err));
                  }
                });
              }
              
              return { sent: response.successCount, failed: response.failureCount };
            } catch (error) {
              console.error(`Error sending to user ${userId}:`, error);
              return { sent: 0, failed: 1 };
            }
          });
          
          const results = await Promise.all(sendPromises);
          results.forEach(result => {
            totalSent += result.sent;
            totalFailed += result.failed;
          });
          
          // Small delay between batches
          if (i + batchSize < eligibleUserIds.length) {
            await new Promise(resolve => setTimeout(resolve, 100));
          }
        }
        
        // Create in-app notification documents for each user
        const notificationBatch = db.batch();
        let batchCount = 0;
        const maxBatchSize = 500;
        
        for (const userId of eligibleUserIds) {
          const userNotificationRef = db.collection('users')
            .doc(userId)
            .collection('notifications')
            .doc();
          
          // Ensure type matches iOS NotificationType enum values exactly
          let notificationType = type;
          if (type === 'feature_update') {
            notificationType = 'feature_update'; // Keep as-is
          } else if (type === 'announcement') {
            notificationType = 'announcement'; // Keep as-is
          } else if (type === 'promo') {
            notificationType = 'promo'; // Keep as-is
          } else if (type === 'event') {
            notificationType = 'event'; // Keep as-is
          }
          
          const notificationData = {
            type: notificationType,
            category: 'promotional',
            message: body, // Required field
            promoTitle: title,
            promoBody: body,
            targetId: notificationId, // Required field
            isRead: false, // Required field
            actorCount: 0, // Required field
            actors: [], // Required field (can be empty array)
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            lastActivityAt: admin.firestore.FieldValue.serverTimestamp(),
            ...(imageUrl && { promoImageUrl: imageUrl }),
            ...(deepLink && { deepLink }),
          };
          
          // Log first notification document for debugging
          if (userId === eligibleUserIds[0]) {
            console.log('Sample notification document:', JSON.stringify(notificationData, null, 2));
          }
          
          notificationBatch.set(userNotificationRef, notificationData);
          batchCount++;
          
          if (batchCount >= maxBatchSize) {
            await notificationBatch.commit();
            batchCount = 0;
          }
        }
        
        if (batchCount > 0) {
          await notificationBatch.commit();
        }
        
        // Update notification with final stats
        await notificationRef.update({
          status: 'sent',
          'stats.delivered': totalSent,
          sentAt: admin.firestore.FieldValue.serverTimestamp()
        });
        
        const updatedDoc = await notificationRef.get();
        const updatedData = updatedDoc.data();
        
        return res.json({
          success: true,
          notificationId,
          stats: updatedData.stats,
          status: updatedData.status
        });
      } catch (error) {
        console.error('Error sending notification:', error);
        // Mark as draft on error so it can be retried
        await notificationRef.update({ status: 'draft' });
      }
    }
    
    // Fetch updated notification
    const updatedDoc = await notificationRef.get();
    const updatedData = updatedDoc.data();
    
    res.json({
      success: true,
      notificationId,
      stats: updatedData.stats || promoNotification.stats,
      status: updatedData.status || promoNotification.status
    });
  } catch (error) {
    console.error('Error creating promotional notification:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   GET /api/admin/notifications
// @desc    Get all promotional notifications
// @access  Private (super_admin+)
router.get('/notifications', requireRole('super_admin'), async (req, res) => {
  try {
    const db = admin.firestore();
    const snapshot = await db.collection('promotional_notifications')
      .orderBy('createdAt', 'desc')
      .limit(100)
      .get();
    
    const notifications = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));
    
    res.json({ success: true, notifications });
  } catch (error) {
    console.error('Error fetching notifications:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   GET /api/admin/notifications/:id
// @desc    Get notification details
// @access  Private (super_admin+)
router.get('/notifications/:id', requireRole('super_admin'), async (req, res) => {
  try {
    const { id } = req.params;
    const db = admin.firestore();
    const doc = await db.collection('promotional_notifications').doc(id).get();
    
    if (!doc.exists) {
      return res.status(404).json({ message: 'Notification not found' });
    }
    
    res.json({ success: true, notification: { id: doc.id, ...doc.data() } });
  } catch (error) {
    console.error('Error fetching notification:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   POST /api/admin/notifications/:id/send
// @desc    Send a draft notification
// @access  Private (super_admin+)
router.post('/notifications/:id/send', requireRole('super_admin'), async (req, res) => {
  try {
    const { id } = req.params;
    const db = admin.firestore();
    const notificationRef = db.collection('promotional_notifications').doc(id);
    const doc = await notificationRef.get();
    
    if (!doc.exists) {
      return res.status(404).json({ message: 'Notification not found' });
    }
    
    const notification = doc.data();
    
    if (notification.status !== 'draft') {
      return res.status(400).json({ message: `Cannot send notification with status: ${notification.status}` });
    }
    
    // Update status to sending - this will be processed by the Firebase Function
    // The function will handle getting users, filtering by preferences, and sending push notifications
    await notificationRef.update({
      status: 'sending',
      sentAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    // Note: The actual sending logic is in the Firebase Function
    // For now, we mark it as sending. In production, you would:
    // 1. Call the Firebase Function via HTTP with proper auth
    // 2. Or implement the sending logic directly here using Firebase Admin SDK
    
    // For now, return success - the notification is marked as sending
    // The Firebase Function should process notifications with status 'sending'
    const updatedDoc = await notificationRef.get();
    
    res.json({
      success: true,
      notification: { id: doc.id, ...updatedDoc.data() },
      message: 'Notification is being sent'
    });
  } catch (error) {
    console.error('Error sending notification:', error);
    res.status(500).json({ message: error.message });
  }
});

export default router;

