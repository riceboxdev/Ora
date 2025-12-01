import express from 'express';
import { protect, requireRole } from '../middleware/adminAuth.js';
import { apiRateLimiter } from '../middleware/rateLimit.js';
import { logActivity } from '../middleware/activityLogger.js';
import admin from '../config/firebase.js';
import multer from 'multer';
import FormData from 'form-data';

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
      return await getUsersFromFirestore(db, data || {});
    case 'getAdminAnalytics':
      return await getAnalyticsFromFirestore(db);
    case 'getModerationQueue':
      return await getModerationQueueFromFirestore(db, data?.status);
    default:
      throw new Error(`Unknown function: ${functionName}`);
  }
};

// Helper functions to interact with Firestore

/**
 * Get user statistics (post count, engagement metrics, etc.)
 */
async function getUserStats(db, userId) {
  try {
    // Get post count
    const postsSnapshot = await db.collection('posts')
      .where('userId', '==', userId)
      .get();
    const postCount = postsSnapshot.size;

    // Get comment count
    const commentsSnapshot = await db.collection('comments')
      .where('userId', '==', userId)
      .get();
    const commentCount = commentsSnapshot.size;

    // Get like count (likes given by user)
    const likesSnapshot = await db.collection('likes')
      .where('userId', '==', userId)
      .get();
    const likeCount = likesSnapshot.size;

    // Calculate total engagements
    let totalEngagements = 0;
    postsSnapshot.forEach(doc => {
      const data = doc.data();
      totalEngagements += (data.likeCount || 0) + (data.commentCount || 0) + (data.shareCount || 0) + (data.saveCount || 0);
    });

    // Get last activity (most recent post or comment)
    let lastActivityAt = null;
    if (postsSnapshot.size > 0) {
      const latestPost = postsSnapshot.docs.reduce((latest, doc) => {
        const postTime = doc.data().createdAt;
        if (!latest || !postTime) return latest || doc;
        if (!latest.data().createdAt) return doc;
        return postTime.toMillis() > latest.data().createdAt.toMillis() ? doc : latest;
      }, null);
      if (latestPost?.data()?.createdAt) {
        lastActivityAt = latestPost.data().createdAt.toMillis();
      }
    }

    // Get follower/following counts from user document or user_stats
    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.data();
    const followerCount = userData?.followerCount || 0;
    const followingCount = userData?.followingCount || 0;

    return {
      postCount,
      commentCount,
      likeCount,
      followerCount,
      followingCount,
      totalEngagements,
      lastActivityAt
    };
  } catch (error) {
    console.error(`Error getting stats for user ${userId}:`, error);
    return {
      postCount: 0,
      commentCount: 0,
      likeCount: 0,
      followerCount: 0,
      followingCount: 0,
      totalEngagements: 0,
      lastActivityAt: null
    };
  }
}

/**
 * Enhanced getUsersFromFirestore with filtering, sorting, and pagination
 */
async function getUsersFromFirestore(db, options = {}) {
  const {
    limit = 50,
    offset = 0,
    status = 'all', // all, active, banned, admin
    search = '',
    sortBy = 'createdAt',
    sortOrder = 'desc',
    dateRange = null, // { start: timestamp, end: timestamp }
    activityLevel = null // active, inactive, new
  } = options;

  let query = db.collection('users');

  // Apply status filter
  if (status === 'banned') {
    query = query.where('isBanned', '==', true);
  } else if (status === 'active') {
    query = query.where('isBanned', '==', false);
  } else if (status === 'admin') {
    query = query.where('isAdmin', '==', true);
  }

  // Apply date range filter (createdAt)
  if (dateRange?.start) {
    const startTimestamp = admin.firestore.Timestamp.fromMillis(parseInt(dateRange.start));
    query = query.where('createdAt', '>=', startTimestamp);
  }
  if (dateRange?.end) {
    const endTimestamp = admin.firestore.Timestamp.fromMillis(parseInt(dateRange.end));
    query = query.where('createdAt', '<=', endTimestamp);
  }

  // Get total count before pagination (for status filter)
  const totalSnapshot = await query.get();
  const total = totalSnapshot.size;

  // Apply sorting
  // Note: Firestore requires composite indexes for multiple where clauses + orderBy
  // For now, we'll do client-side sorting if needed, or use single field sorting
  const orderDirection = sortOrder === 'asc' ? 'asc' : 'desc';

  // Firestore can only orderBy fields that are in a where clause or indexed
  // For createdAt, we can use orderBy directly
  if (sortBy === 'createdAt') {
    query = query.orderBy('createdAt', orderDirection);
  } else if (sortBy === 'email') {
    query = query.orderBy('email', orderDirection);
  } else if (sortBy === 'displayName') {
    query = query.orderBy('displayName', orderDirection);
  } else {
    // Default to createdAt
    query = query.orderBy('createdAt', orderDirection);
  }

  // Apply pagination
  const limitNum = parseInt(limit);
  const offsetNum = parseInt(offset);
  query = query.limit(limitNum);

  // Note: Firestore doesn't support offset directly, so we'll need to use startAfter
  // For simplicity, we'll fetch and skip client-side for now (not ideal for large datasets)
  const usersSnapshot = await query.get();

  // Process users
  const users = [];
  const userPromises = [];

  for (let i = offsetNum; i < Math.min(offsetNum + limitNum, usersSnapshot.docs.length); i++) {
    const doc = usersSnapshot.docs[i];
    if (!doc) continue;

    const data = doc.data();
    const userId = doc.id;

    // Apply search filter (client-side for now)
    if (search) {
      const searchLower = search.toLowerCase();
      const matchesSearch =
        (data.email && data.email.toLowerCase().includes(searchLower)) ||
        (data.displayName && data.displayName.toLowerCase().includes(searchLower)) ||
        (data.username && data.username.toLowerCase().includes(searchLower)) ||
        userId.toLowerCase().includes(searchLower);

      if (!matchesSearch) continue;
    }

    // Get user stats (async, but we'll await later)
    const statsPromise = getUserStats(db, userId).then(stats => ({
      id: userId,
      email: data.email || null,
      username: data.username || null,
      displayName: data.displayName || null,
      photoURL: data.photoURL || null,
      bio: data.bio || null,
      location: data.location || null,
      websiteLink: data.websiteLink || null,
      createdAt: data.createdAt?.toMillis?.() || null,
      isBanned: data.isBanned || false,
      bannedAt: data.bannedAt?.toMillis?.() || null,
      banReason: data.banReason || null,
      isAdmin: data.isAdmin || false,
      stats
    }));

    userPromises.push(statsPromise);
  }

  // Wait for all stats to be fetched
  const usersWithStats = await Promise.all(userPromises);

  // Apply activity level filter
  let filteredUsers = usersWithStats;
  if (activityLevel === 'active') {
    const thirtyDaysAgo = Date.now() - (30 * 24 * 60 * 60 * 1000);
    filteredUsers = usersWithStats.filter(u => u.stats.lastActivityAt && u.stats.lastActivityAt > thirtyDaysAgo);
  } else if (activityLevel === 'inactive') {
    const thirtyDaysAgo = Date.now() - (30 * 24 * 60 * 60 * 1000);
    filteredUsers = usersWithStats.filter(u => !u.stats.lastActivityAt || u.stats.lastActivityAt <= thirtyDaysAgo);
  } else if (activityLevel === 'new') {
    const sevenDaysAgo = Date.now() - (7 * 24 * 60 * 60 * 1000);
    filteredUsers = usersWithStats.filter(u => u.createdAt && u.createdAt > sevenDaysAgo);
  }

  // Client-side sorting for fields that can't be sorted in Firestore
  if (sortBy === 'followerCount' || sortBy === 'postCount' || sortBy === 'totalEngagements') {
    filteredUsers.sort((a, b) => {
      const aVal = a.stats[sortBy === 'followerCount' ? 'followerCount' : sortBy === 'postCount' ? 'postCount' : 'totalEngagements'] || 0;
      const bVal = b.stats[sortBy === 'followerCount' ? 'followerCount' : sortBy === 'postCount' ? 'postCount' : 'totalEngagements'] || 0;
      return sortOrder === 'asc' ? aVal - bVal : bVal - aVal;
    });
  }

  return {
    users: filteredUsers,
    count: filteredUsers.length,
    total: total,
    limit: limitNum,
    offset: offsetNum
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
// @desc    Get all users (with pagination, filtering, sorting)
// @access  Private (moderator+)
router.get('/users', logActivity, requireRole('super_admin', 'moderator', 'viewer'), async (req, res) => {
  try {
    const {
      limit = 50,
      offset = 0,
      status = 'all',
      search = '',
      sortBy = 'createdAt',
      sortOrder = 'desc',
      startDate,
      endDate,
      activityLevel
    } = req.query;

    const db = admin.firestore();

    const dateRange = (startDate || endDate) ? {
      start: startDate ? parseInt(startDate) : null,
      end: endDate ? parseInt(endDate) : null
    } : null;

    const result = await getUsersFromFirestore(db, {
      limit: parseInt(limit),
      offset: parseInt(offset),
      status,
      search,
      sortBy,
      sortOrder,
      dateRange,
      activityLevel
    });

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
router.post('/users/ban', logActivity, requireRole('super_admin', 'moderator'), async (req, res) => {
  try {
    const { userId, reason } = req.body;
    if (!userId) {
      return res.status(400).json({ message: 'userId is required' });
    }

    const db = admin.firestore();
    const userRef = db.collection('users').doc(userId);
    await userRef.update({
      isBanned: true,
      bannedAt: admin.firestore.FieldValue.serverTimestamp(),
      banReason: reason || null,
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
router.post('/users/unban', logActivity, requireRole('super_admin', 'moderator'), async (req, res) => {
  try {
    const { userId } = req.body;
    if (!userId) {
      return res.status(400).json({ message: 'userId is required' });
    }

    const db = admin.firestore();
    const userRef = db.collection('users').doc(userId);
    await userRef.update({
      isBanned: false,
      bannedAt: admin.firestore.FieldValue.delete(),
      banReason: admin.firestore.FieldValue.delete(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    res.json({ success: true, message: 'User unbanned' });
  } catch (error) {
    console.error('Error unbanning user:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   DELETE /api/admin/users/:userId
// @desc    Delete a user and all their data
// @access  Private (super_admin only)
router.delete('/users/:userId', logActivity, requireRole('super_admin'), async (req, res) => {
  try {
    const { userId } = req.params;
    if (!userId) {
      return res.status(400).json({ message: 'userId is required' });
    }

    // Call Firebase Function to delete user and all their data
    const result = await callFirebaseFunction('deleteUser', { userId }, req.admin);

    res.json({ success: true, message: result.message || 'User deleted successfully' });
  } catch (error) {
    console.error('Error deleting user:', error);
    res.status(500).json({ message: error.message || 'Failed to delete user' });
  }
});

// @route   GET /api/admin/users/:userId
// @desc    Get detailed user profile
// @access  Private (moderator+)
router.get('/users/:userId', logActivity, requireRole('super_admin', 'moderator', 'viewer'), async (req, res) => {
  try {
    const { userId } = req.params;
    const db = admin.firestore();

    // Get user document
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      return res.status(404).json({ message: 'User not found' });
    }

    const userData = userDoc.data();

    // Get user statistics
    const stats = await getUserStats(db, userId);

    // Get warnings
    const warningsSnapshot = await db.collection('users').doc(userId)
      .collection('warnings')
      .orderBy('timestamp', 'desc')
      .get();
    const warnings = warningsSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      timestamp: doc.data().timestamp?.toMillis?.() || null
    }));

    // Get moderation history (from admin_logs)
    const moderationHistorySnapshot = await db.collection('admin_logs')
      .where('targetId', '==', userId)
      .where('targetType', '==', 'user')
      .orderBy('timestamp', 'desc')
      .limit(50)
      .get();
    const moderationHistory = moderationHistorySnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      timestamp: doc.data().timestamp?.toMillis?.() || null
    }));

    const user = {
      id: userDoc.id,
      email: userData.email || null,
      username: userData.username || null,
      displayName: userData.displayName || null,
      photoURL: userData.photoURL || null,
      bio: userData.bio || null,
      location: userData.location || null,
      websiteLink: userData.websiteLink || null,
      socialLinks: userData.socialLinks || null,
      isAdmin: userData.isAdmin || false,
      isBanned: userData.isBanned || false,
      bannedAt: userData.bannedAt?.toMillis?.() || null,
      banReason: userData.banReason || null,
      createdAt: userData.createdAt?.toMillis?.() || null,
      updatedAt: userData.updatedAt?.toMillis?.() || null,
      isOnboardingCompleted: userData.isOnboardingCompleted || false,
      stats,
      warnings,
      moderationHistory
    };

    res.json({ user });
  } catch (error) {
    console.error('Error fetching user:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   GET /api/admin/users/:userId/activity
// @desc    Get user activity log
// @access  Private (moderator+)
router.get('/users/:userId/activity', requireRole('super_admin', 'moderator', 'viewer'), async (req, res) => {
  try {
    const { userId } = req.params;
    const { limit = 50, offset = 0, activityType, startDate, endDate } = req.query;
    const db = admin.firestore();

    // Get user's posts
    let postsQuery = db.collection('posts').where('userId', '==', userId);
    if (startDate) {
      const startTimestamp = admin.firestore.Timestamp.fromMillis(parseInt(startDate));
      postsQuery = postsQuery.where('createdAt', '>=', startTimestamp);
    }
    if (endDate) {
      const endTimestamp = admin.firestore.Timestamp.fromMillis(parseInt(endDate));
      postsQuery = postsQuery.where('createdAt', '<=', endTimestamp);
    }
    postsQuery = postsQuery.orderBy('createdAt', 'desc').limit(parseInt(limit));

    const postsSnapshot = await postsQuery.get();
    const activities = [];

    postsSnapshot.forEach(doc => {
      const data = doc.data();
      if (!activityType || activityType === 'post') {
        activities.push({
          id: doc.id,
          type: 'post',
          timestamp: data.createdAt?.toMillis?.() || null,
          postId: doc.id,
          metadata: {
            caption: data.caption,
            moderationStatus: data.moderationStatus
          }
        });
      }
    });

    // Get comments if requested
    if (!activityType || activityType === 'comment') {
      let commentsQuery = db.collection('comments').where('userId', '==', userId);
      if (startDate) {
        const startTimestamp = admin.firestore.Timestamp.fromMillis(parseInt(startDate));
        commentsQuery = commentsQuery.where('createdAt', '>=', startTimestamp);
      }
      if (endDate) {
        const endTimestamp = admin.firestore.Timestamp.fromMillis(parseInt(endDate));
        commentsQuery = commentsQuery.where('createdAt', '<=', endTimestamp);
      }
      commentsQuery = commentsQuery.orderBy('createdAt', 'desc').limit(parseInt(limit));

      const commentsSnapshot = await commentsQuery.get();
      commentsSnapshot.forEach(doc => {
        const data = doc.data();
        activities.push({
          id: doc.id,
          type: 'comment',
          timestamp: data.createdAt?.toMillis?.() || null,
          postId: data.postId,
          metadata: {
            text: data.text
          }
        });
      });
    }

    // Sort by timestamp descending
    activities.sort((a, b) => (b.timestamp || 0) - (a.timestamp || 0));

    // Apply pagination
    const offsetNum = parseInt(offset);
    const limitNum = parseInt(limit);
    const paginatedActivities = activities.slice(offsetNum, offsetNum + limitNum);

    res.json({
      activities: paginatedActivities,
      count: paginatedActivities.length,
      total: activities.length,
      limit: limitNum,
      offset: offsetNum
    });
  } catch (error) {
    console.error('Error fetching user activity:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   GET /api/admin/users/:userId/posts
// @desc    Get user's posts
// @access  Private (moderator+)
router.get('/users/:userId/posts', requireRole('super_admin', 'moderator', 'viewer'), async (req, res) => {
  try {
    const { userId } = req.params;
    const { limit = 50, offset = 0, status, startDate, endDate } = req.query;
    const db = admin.firestore();

    let query = db.collection('posts').where('userId', '==', userId);

    if (status && status !== 'all') {
      query = query.where('moderationStatus', '==', status);
    }

    if (startDate) {
      const startTimestamp = admin.firestore.Timestamp.fromMillis(parseInt(startDate));
      query = query.where('createdAt', '>=', startTimestamp);
    }

    if (endDate) {
      const endTimestamp = admin.firestore.Timestamp.fromMillis(parseInt(endDate));
      query = query.where('createdAt', '<=', endTimestamp);
    }

    query = query.orderBy('createdAt', 'desc').limit(parseInt(limit));

    const postsSnapshot = await query.get();
    const posts = postsSnapshot.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        imageUrl: data.imageUrl,
        thumbnailUrl: data.thumbnailUrl,
        caption: data.caption,
        tags: data.tags || [],
        moderationStatus: data.moderationStatus,
        likeCount: data.likeCount || 0,
        commentCount: data.commentCount || 0,
        createdAt: data.createdAt?.toMillis?.() || null
      };
    });

    res.json({
      posts,
      count: posts.length,
      limit: parseInt(limit),
      offset: parseInt(offset)
    });
  } catch (error) {
    console.error('Error fetching user posts:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   POST /api/admin/users/bulk
// @desc    Perform bulk operations on users
// @access  Private (super_admin+)
router.post('/users/bulk', logActivity, requireRole('super_admin', 'moderator'), async (req, res) => {
  try {
    const { userIds, action, reason } = req.body;

    if (!userIds || !Array.isArray(userIds) || userIds.length === 0) {
      return res.status(400).json({ message: 'userIds array is required' });
    }

    if (!action || !['ban', 'unban', 'delete', 'assignRole'].includes(action)) {
      return res.status(400).json({ message: 'action must be one of: ban, unban, delete, assignRole' });
    }

    const db = admin.firestore();
    const batch = db.batch();
    const results = [];
    const adminId = req.admin.firebaseUid || req.admin._id.toString();

    for (const userId of userIds) {
      try {
        const userRef = db.collection('users').doc(userId);
        const userDoc = await userRef.get();

        if (!userDoc.exists) {
          results.push({ userId, success: false, error: 'User not found' });
          continue;
        }

        switch (action) {
          case 'ban':
            batch.update(userRef, {
              isBanned: true,
              bannedAt: admin.firestore.FieldValue.serverTimestamp(),
              banReason: reason || null,
              updatedAt: admin.firestore.FieldValue.serverTimestamp()
            });
            results.push({ userId, success: true });
            break;

          case 'unban':
            batch.update(userRef, {
              isBanned: false,
              bannedAt: admin.firestore.FieldValue.delete(),
              banReason: admin.firestore.FieldValue.delete(),
              updatedAt: admin.firestore.FieldValue.serverTimestamp()
            });
            results.push({ userId, success: true });
            break;

          case 'delete':
            // Note: Actual deletion should be handled by a Firebase Function
            // This just marks for deletion or calls the function
            results.push({ userId, success: false, error: 'Bulk delete not supported. Use individual delete endpoint.' });
            break;

          case 'assignRole':
            const { role } = req.body;
            if (!role) {
              results.push({ userId, success: false, error: 'role is required for assignRole action' });
              continue;
            }
            batch.update(userRef, {
              isAdmin: role === 'admin',
              updatedAt: admin.firestore.FieldValue.serverTimestamp()
            });
            results.push({ userId, success: true });
            break;
        }
      } catch (error) {
        results.push({ userId, success: false, error: error.message });
      }
    }

    // Commit batch (Firestore batch limit is 500, but we'll process in chunks if needed)
    if (userIds.length <= 500) {
      await batch.commit();
    } else {
      // Process in chunks of 500
      const chunks = [];
      for (let i = 0; i < userIds.length; i += 500) {
        chunks.push(userIds.slice(i, i + 500));
      }
      // For now, return error if too many users
      return res.status(400).json({ message: 'Too many users. Maximum 500 per batch.' });
    }

    const successCount = results.filter(r => r.success).length;
    const failureCount = results.filter(r => !r.success).length;

    res.json({
      success: true,
      message: `Processed ${successCount} users successfully, ${failureCount} failed`,
      results,
      successCount,
      failureCount
    });
  } catch (error) {
    console.error('Error performing bulk operation:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   POST /api/admin/users/:userId/warn
// @desc    Issue warning to user
// @access  Private (super_admin+)
router.post('/users/:userId/warn', logActivity, requireRole('super_admin', 'moderator'), async (req, res) => {
  try {
    const { userId } = req.params;
    const { warningType, reason, notes } = req.body;

    if (!warningType || !reason) {
      return res.status(400).json({ message: 'warningType and reason are required' });
    }

    const validTypes = ['spam', 'harassment', 'inappropriate_content', 'terms_violation', 'other'];
    if (!validTypes.includes(warningType)) {
      return res.status(400).json({ message: `warningType must be one of: ${validTypes.join(', ')}` });
    }

    const db = admin.firestore();
    const adminId = req.admin.firebaseUid || req.admin._id.toString();

    // Check if user exists
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Create warning document
    const warningRef = db.collection('users').doc(userId).collection('warnings').doc();
    await warningRef.set({
      warningType,
      reason,
      notes: notes || null,
      adminId,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      acknowledged: false
    });

    // Get warning count
    const warningsSnapshot = await db.collection('users').doc(userId)
      .collection('warnings')
      .get();
    const warningCount = warningsSnapshot.size;

    res.json({
      success: true,
      message: 'Warning issued',
      warning: {
        id: warningRef.id,
        warningType,
        reason,
        timestamp: Date.now()
      },
      warningCount
    });
  } catch (error) {
    console.error('Error issuing warning:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   POST /api/admin/users/:userId/temp-ban
// @desc    Temporarily ban a user
// @access  Private (super_admin+)
router.post('/users/:userId/temp-ban', logActivity, requireRole('super_admin', 'moderator'), async (req, res) => {
  try {
    const { userId } = req.params;
    const { duration, reason, notes } = req.body;

    if (!duration || !reason) {
      return res.status(400).json({ message: 'duration (in hours) and reason are required' });
    }

    const durationHours = parseInt(duration);
    if (isNaN(durationHours) || durationHours <= 0) {
      return res.status(400).json({ message: 'duration must be a positive number of hours' });
    }

    const db = admin.firestore();
    const adminId = req.admin.firebaseUid || req.admin._id.toString();

    // Check if user exists
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Calculate expiration time
    const expiresAt = new Date();
    expiresAt.setHours(expiresAt.getHours() + durationHours);
    const expiresAtTimestamp = admin.firestore.Timestamp.fromDate(expiresAt);

    // Update user document
    const userRef = db.collection('users').doc(userId);
    await userRef.update({
      isBanned: true,
      bannedAt: admin.firestore.FieldValue.serverTimestamp(),
      banReason: reason,
      banExpiresAt: expiresAtTimestamp,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Store temp ban record in moderation history
    await db.collection('users').doc(userId).collection('moderation_history').add({
      action: 'temp_ban',
      adminId,
      reason,
      notes: notes || null,
      durationHours,
      expiresAt: expiresAtTimestamp,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });

    res.json({
      success: true,
      message: `User temporarily banned for ${durationHours} hours`,
      expiresAt: expiresAt.getTime()
    });
  } catch (error) {
    console.error('Error issuing temporary ban:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   PUT /api/admin/users/:userId/role
// @desc    Assign/remove user role
// @access  Private (super_admin only)
router.put('/users/:userId/role', logActivity, requireRole('super_admin'), async (req, res) => {
  try {
    const { userId } = req.params;
    const { role } = req.body;

    if (!role || !['admin', 'moderator', 'user'].includes(role)) {
      return res.status(400).json({ message: "role must be one of: 'admin', 'moderator', 'user'" });
    }

    const db = admin.firestore();
    const userRef = db.collection('users').doc(userId);
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
      return res.status(404).json({ message: 'User not found' });
    }

    const currentData = userDoc.data();
    const oldRole = currentData.isAdmin ? 'admin' : 'user';

    await userRef.update({
      isAdmin: role === 'admin',
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    res.json({
      success: true,
      message: `User role updated to ${role}`,
      oldRole,
      newRole: role
    });
  } catch (error) {
    console.error('Error updating user role:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   GET /api/admin/users/export
// @desc    Export users to CSV/JSON
// @access  Private (moderator+)
router.get('/users/export', logActivity, requireRole('super_admin', 'moderator', 'viewer'), async (req, res) => {
  try {
    const { format = 'json', ...filters } = req.query;
    const db = admin.firestore();

    // Get users with same filters as GET /users
    const dateRange = (filters.startDate || filters.endDate) ? {
      start: filters.startDate ? parseInt(filters.startDate) : null,
      end: filters.endDate ? parseInt(filters.endDate) : null
    } : null;

    const result = await getUsersFromFirestore(db, {
      limit: 10000, // Large limit for export
      offset: 0,
      status: filters.status || 'all',
      search: filters.search || '',
      sortBy: filters.sortBy || 'createdAt',
      sortOrder: filters.sortOrder || 'desc',
      dateRange,
      activityLevel: filters.activityLevel
    });

    if (format === 'csv') {
      // Convert to CSV
      const headers = ['id', 'email', 'username', 'displayName', 'isBanned', 'isAdmin', 'createdAt', 'postCount', 'followerCount', 'followingCount'];
      const rows = result.users.map(user => [
        user.id,
        user.email || '',
        user.username || '',
        user.displayName || '',
        user.isBanned ? 'Yes' : 'No',
        user.isAdmin ? 'Yes' : 'No',
        user.createdAt ? new Date(user.createdAt).toISOString() : '',
        user.stats?.postCount || 0,
        user.stats?.followerCount || 0,
        user.stats?.followingCount || 0
      ]);

      const csv = [
        headers.join(','),
        ...rows.map(row => row.map(cell => `"${String(cell).replace(/"/g, '""')}"`).join(','))
      ].join('\n');

      res.setHeader('Content-Type', 'text/csv');
      res.setHeader('Content-Disposition', 'attachment; filename=users-export.csv');
      res.send(csv);
    } else {
      // JSON format
      res.setHeader('Content-Type', 'application/json');
      res.setHeader('Content-Disposition', 'attachment; filename=users-export.json');
      res.json(result.users);
    }
  } catch (error) {
    console.error('Error exporting users:', error);
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
          maintenanceMode: false,
          uiSettings: {}
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
    // Verify Firebase Admin is initialized
    if (!admin.apps.length) {
      throw new Error('Firebase Admin not initialized');
    }

    const { featureFlags, remoteConfig, maintenanceMode, uiSettings } = req.body;
    console.log('Settings update request received:', {
      hasFeatureFlags: featureFlags !== undefined,
      hasRemoteConfig: remoteConfig !== undefined,
      hasMaintenanceMode: maintenanceMode !== undefined,
      hasUISettings: uiSettings !== undefined,
      uiSettings: uiSettings
    });

    const db = admin.firestore();
    const settingsRef = db.collection('system_settings').doc('main');

    const updateData = {
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: req.admin.firebaseUid || req.admin._id.toString()
    };

    // Track Remote Config sync errors
    let remoteConfigError = null;

    // Sync to Firebase Remote Config if feature flags, remote config, or maintenance mode are being updated
    // Do this in a single template update to avoid conflicts
    const shouldSyncToRemoteConfig = featureFlags !== undefined || remoteConfig !== undefined || maintenanceMode !== undefined;
    console.log('Checking if should sync to Remote Config:', {
      shouldSync: shouldSyncToRemoteConfig,
      featureFlags: featureFlags !== undefined,
      remoteConfig: remoteConfig !== undefined,
      maintenanceMode: maintenanceMode !== undefined,
      maintenanceModeValue: maintenanceMode
    });

    if (shouldSyncToRemoteConfig) {
      if (featureFlags !== undefined) {
        updateData.featureFlags = featureFlags;
      }
      if (remoteConfig !== undefined) {
        updateData.remoteConfig = remoteConfig;
      }
      if (maintenanceMode !== undefined) {
        updateData.maintenanceMode = maintenanceMode;
      }

      // Sync to Firebase Remote Config in a single update
      try {
        console.log('Attempting to sync to Firebase Remote Config...', {
          hasFeatureFlags: featureFlags !== undefined,
          hasRemoteConfig: remoteConfig !== undefined,
          hasMaintenanceMode: maintenanceMode !== undefined,
          maintenanceModeValue: maintenanceMode
        });
        await syncToFirebaseRemoteConfig(featureFlags, remoteConfig, maintenanceMode);
        console.log('Settings synced to Firebase Remote Config successfully');
      } catch (rcError) {
        console.error('Failed to sync to Remote Config:', rcError);
        console.error('Remote Config error details:', {
          message: rcError?.message,
          code: rcError?.code,
          status: rcError?.status,
          stack: rcError?.stack
        });
        // Store the error to return to the user
        // Settings are still saved to Firestore, but Remote Config sync failed
        remoteConfigError = {
          message: rcError?.message || 'Failed to sync to Firebase Remote Config',
          code: rcError?.code,
          status: rcError?.status
        };
      }
    } else {
      console.log('Skipping Remote Config sync - no relevant fields to sync');
    }
    if (uiSettings !== undefined) {
      updateData.uiSettings = uiSettings;
      console.log('Saving UI settings:', uiSettings);
    }

    console.log('Update data to save:', JSON.stringify(updateData, null, 2));

    // Use set with merge to preserve existing fields
    await settingsRef.set(updateData, { merge: true });

    // Verify the save by reading it back immediately
    const savedDoc = await settingsRef.get();
    let savedData = savedDoc.data() || {};
    console.log('Settings saved successfully. Saved data:', JSON.stringify(savedData, null, 2));

    // Build response data, ensuring uiSettings is included if it was updated
    const responseData = { ...savedData };

    // If uiSettings was in the update, ensure it's in the response
    // (Firestore merge might not immediately reflect in the read, so we include what we saved)
    if (updateData.uiSettings !== undefined) {
      responseData.uiSettings = savedData.uiSettings || updateData.uiSettings;
      console.log('UI Settings in response:', JSON.stringify(responseData.uiSettings, null, 2));
    }

    // Log specifically what uiSettings were saved
    if (responseData.uiSettings) {
      console.log('UI Settings will be returned in response:', JSON.stringify(responseData.uiSettings, null, 2));
    } else {
      console.warn('WARNING: uiSettings not found in response data!');
    }

    console.log('Returning response data:', JSON.stringify(responseData, null, 2));

    // Return the actual saved data, ensuring uiSettings is included
    // Also include Remote Config sync error if it occurred
    const response = { success: true, settings: responseData };
    if (remoteConfigError) {
      response.remoteConfigError = remoteConfigError;
      response.warning = 'Settings saved to database, but failed to sync to Firebase Remote Config. The iOS app may not receive the updates until this is resolved.';
    }
    res.json(response);
  } catch (error) {
    console.error('Error updating settings:', error);
    console.error('Error details:', {
      message: error.message,
      code: error.code,
      stack: error.stack
    });

    // Provide more helpful error messages
    let errorMessage = error.message || 'Failed to save settings';
    if (error.code === 7) {
      errorMessage = 'Permission denied. Please check Firestore security rules.';
    } else if (error.code === 14) {
      errorMessage = 'Firestore unavailable. Please check your connection.';
    } else if (error.message?.includes('not initialized')) {
      errorMessage = 'Firebase Admin not initialized. Please check environment variables.';
    } else if (error.message?.includes('Database connection')) {
      errorMessage = 'Database connection error. Please check your Firestore configuration.';
    }

    res.status(500).json({
      message: errorMessage,
      ...(process.env.NODE_ENV === 'development' && { details: error.message })
    });
  }
});

/**
 * Sync feature flags, remote config, and maintenance mode to Firebase Remote Config in a single update
 * This ensures all are published together and avoids conflicts
 * 
 * Implements proper ETag handling and retry logic per Firebase Remote Config best practices:
 * https://firebase.google.com/docs/remote-config/automate-rc
 */
async function syncToFirebaseRemoteConfig(featureFlags, remoteConfig, maintenanceMode) {
  console.log('syncToFirebaseRemoteConfig called with:', {
    hasFeatureFlags: featureFlags !== undefined,
    hasRemoteConfig: remoteConfig !== undefined,
    hasMaintenanceMode: maintenanceMode !== undefined,
    maintenanceModeValue: maintenanceMode
  });

  const remoteConfigService = admin.remoteConfig();
  const maxRetries = 3;
  let lastError;

  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      console.log(`[Attempt ${attempt + 1}/${maxRetries}] Getting Remote Config template...`);
      // Get current template (this includes the ETag for version control)
      // The Firebase Admin SDK handles ETags automatically when publishing
      const template = await remoteConfigService.getTemplate();
      console.log('Template retrieved successfully');

      // Initialize parameters if they don't exist
      if (!template.parameters) {
        template.parameters = {};
      }

      // Sync feature flags if provided
      if (featureFlags !== undefined) {
        // Map admin dashboard flags to iOS app expected format
        // The iOS app expects specific keys: storiesEnabled, adsEnabled, waitlistEnabled
        // But we also support any custom flags
        const iosCompatibleFlags = {
          // Map common flag names to iOS expected format
          storiesEnabled: featureFlags.storiesEnabled ?? featureFlags.enableStories ?? false,
          adsEnabled: featureFlags.adsEnabled ?? featureFlags.showAds ?? featureFlags.enableAds ?? true,
          waitlistEnabled: featureFlags.waitlistEnabled ?? featureFlags.enableWaitlist ?? false,
          // Include all other flags as-is for custom flags
          ...Object.fromEntries(
            Object.entries(featureFlags).filter(([key]) =>
              !['storiesEnabled', 'adsEnabled', 'waitlistEnabled', 'enableStories', 'showAds', 'enableAds', 'enableWaitlist'].includes(key)
            )
          )
        };

        // Convert to JSON string for the iOS app
        // The iOS app reads this from the "featureFlags" key as a JSON string
        const featureFlagsJSON = JSON.stringify(iosCompatibleFlags);

        // Update the featureFlags parameter (JSON format)
        // Per Firebase docs: boolean values must be "true" or "false" (lowercase strings)
        template.parameters['featureFlags'] = {
          defaultValue: {
            value: featureFlagsJSON
          },
          description: 'Feature flags managed from admin dashboard. JSON format with boolean values.'
        };

        // Also update individual flags for backward compatibility
        // These are read directly by the iOS app as separate keys
        if (featureFlags.showAds !== undefined || featureFlags.adsEnabled !== undefined || featureFlags.enableAds !== undefined) {
          const adsValue = featureFlags.showAds ?? featureFlags.adsEnabled ?? featureFlags.enableAds ?? true;
          template.parameters['showAds'] = {
            defaultValue: {
              value: String(adsValue).toLowerCase() // Ensure "true" or "false"
            },
            description: 'Enable/disable ads display'
          };
        }

        if (featureFlags.waitlistEnabled !== undefined || featureFlags.enableWaitlist !== undefined) {
          const waitlistValue = featureFlags.waitlistEnabled ?? featureFlags.enableWaitlist ?? false;
          template.parameters['waitlistEnabled'] = {
            defaultValue: {
              value: String(waitlistValue).toLowerCase() // Ensure "true" or "false"
            },
            description: 'Enable/disable waitlist feature'
          };
        }

        if (featureFlags.storiesEnabled !== undefined || featureFlags.enableStories !== undefined) {
          const storiesValue = featureFlags.storiesEnabled ?? featureFlags.enableStories ?? false;
          template.parameters['storiesEnabled'] = {
            defaultValue: {
              value: String(storiesValue).toLowerCase() // Ensure "true" or "false"
            },
            description: 'Enable/disable stories feature'
          };
        }

        console.log('Updated feature flags in template:', iosCompatibleFlags);
      }

      // Sync remote config key-value pairs if provided
      if (remoteConfig !== undefined) {
        // Update each remote config key-value pair
        for (const [key, value] of Object.entries(remoteConfig)) {
          // Convert value to string (Firebase Remote Config stores all values as strings)
          // For booleans, ensure "true" or "false" (lowercase)
          let stringValue = String(value);
          if (typeof value === 'boolean') {
            stringValue = value ? 'true' : 'false';
          }

          template.parameters[key] = {
            defaultValue: {
              value: stringValue
            },
            description: `Remote config value managed from admin dashboard`
          };
          console.log(`Updated Remote Config parameter: ${key} = ${stringValue}`);
        }
      }

      // Sync maintenance mode if provided
      if (maintenanceMode !== undefined) {
        // Per Firebase docs: booleans must be "true" or "false" (lowercase strings)
        template.parameters['maintenanceMode'] = {
          defaultValue: {
            value: maintenanceMode ? 'true' : 'false'
          },
          description: 'Maintenance mode flag - when true, app shows maintenance screen'
        };
        console.log(`Updated maintenance mode parameter in template: ${maintenanceMode} -> "${maintenanceMode ? 'true' : 'false'}"`);
      }

      console.log('Validating Remote Config template...');
      // Validate the template before publishing
      // This checks for validation errors (e.g., too many parameters, invalid conditions)
      const validatedTemplate = await remoteConfigService.validateTemplate(template);
      console.log('Template validation successful');

      console.log('Publishing Remote Config template...');
      // Publish the updated template
      // The Firebase Admin SDK automatically handles ETags and If-Match headers
      // If there's a version conflict (409), it will throw an error that we can catch and retry
      const publishedTemplate = await remoteConfigService.publishTemplate(validatedTemplate);

      console.log('Remote Config template published successfully. Version:', publishedTemplate.version?.versionNumber);
      if (featureFlags !== undefined) {
        console.log('Synced feature flags');
      }
      if (remoteConfig !== undefined) {
        console.log('Synced remote config keys:', Object.keys(remoteConfig));
      }
      if (maintenanceMode !== undefined) {
        console.log('Synced maintenance mode:', maintenanceMode);
      }
      return publishedTemplate;

    } catch (error) {
      lastError = error;
      const errorCode = error.code || error.status || '';
      const errorMessage = error.message || String(error);

      // Handle specific error codes per Firebase Remote Config API documentation
      // 400: Validation error (e.g., too many parameters, invalid template)
      if (errorCode === 400 || errorMessage.includes('400') || errorMessage.includes('validation')) {
        console.error('Remote Config validation error (400):', errorMessage);
        throw new Error(`Remote Config validation failed: ${errorMessage}`);
      }

      // 401: Authorization error (no access token or Remote Config API not enabled)
      if (errorCode === 401 || errorMessage.includes('401') || errorMessage.includes('unauthorized')) {
        console.error('Remote Config authorization error (401):', errorMessage);
        throw new Error(`Remote Config authorization failed. Ensure Remote Config API is enabled in Firebase Console.`);
      }

      // 403: Authentication error (wrong access token)
      if (errorCode === 403 || errorMessage.includes('403') || errorMessage.includes('forbidden')) {
        console.error('Remote Config authentication error (403):', errorMessage);
        throw new Error(`Remote Config authentication failed. Check Firebase service account credentials.`);
      }

      // 409: Version mismatch (ETag conflict) - retry with fresh template
      // This happens when the template was updated between GET and PUT
      if (errorCode === 409 || errorMessage.includes('409') || errorMessage.includes('conflict') || errorMessage.includes('version')) {
        if (attempt < maxRetries - 1) {
          console.warn(`Remote Config version conflict (409) on attempt ${attempt + 1}. Retrying with fresh template...`);
          // Wait a bit before retrying to avoid immediate conflicts
          await new Promise(resolve => setTimeout(resolve, 1000 * (attempt + 1)));
          continue; // Retry with fresh template
        } else {
          console.error('Remote Config version conflict (409) after max retries:', errorMessage);
          throw new Error(`Remote Config update conflict. Template was modified by another process. Please try again.`);
        }
      }

      // 500: Internal server error
      if (errorCode === 500 || errorMessage.includes('500') || errorMessage.includes('internal')) {
        console.error('Remote Config internal server error (500):', errorMessage);
        if (attempt < maxRetries - 1) {
          console.warn(`Retrying after internal server error (attempt ${attempt + 1}/${maxRetries})...`);
          await new Promise(resolve => setTimeout(resolve, 2000 * (attempt + 1)));
          continue; // Retry on server errors
        } else {
          throw new Error(`Remote Config server error. Please try again later or contact Firebase support.`);
        }
      }

      // For other errors, log and throw
      console.error('Error syncing to Remote Config:', error);
      throw error;
    }
  }

  // If we exhausted all retries, throw the last error
  if (lastError) {
    throw lastError;
  }

  throw new Error('Failed to sync to Remote Config after multiple attempts');
}

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

// =========================
// Announcement Management Routes
// =========================

// @route   POST /api/admin/announcements
// @desc    Create announcement
// @access  Private (super_admin+)
router.post('/announcements', requireRole('super_admin'), async (req, res) => {
  try {
    const { title, pages, targetAudience, status } = req.body;

    if (!title || !pages || !Array.isArray(pages) || pages.length === 0) {
      return res.status(400).json({ message: 'title and pages (non-empty array) are required' });
    }

    if (!targetAudience || !targetAudience.type) {
      return res.status(400).json({ message: 'targetAudience with type is required' });
    }

    const validStatuses = ['draft', 'active', 'archived'];
    const announcementStatus = status || 'draft';
    if (!validStatuses.includes(announcementStatus)) {
      return res.status(400).json({ message: `status must be one of: ${validStatuses.join(', ')}` });
    }

    const db = admin.firestore();
    const adminId = req.admin.firebaseUid || req.admin._id?.toString() || 'unknown';

    // Validate pages structure
    for (const page of pages) {
      if (!page.body || typeof page.body !== 'string') {
        return res.status(400).json({ message: 'Each page must have a body string' });
      }
    }

    const announcement = {
      title,
      pages,
      targetAudience,
      status: announcementStatus,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: adminId,
      version: 1
    };

    const announcementRef = await db.collection('announcements').add(announcement);
    const announcementId = announcementRef.id;

    const doc = await announcementRef.get();
    const data = doc.data();

    res.status(201).json({
      success: true,
      announcement: {
        id: announcementId,
        ...data
      }
    });
  } catch (error) {
    console.error('Error creating announcement:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   GET /api/admin/announcements
// @desc    Get all announcements
// @access  Private (super_admin+)
router.get('/announcements', requireRole('super_admin'), async (req, res) => {
  try {
    // Verify Firebase Admin is initialized
    if (!admin.apps.length) {
      throw new Error('Firebase Admin not initialized');
    }

    const db = admin.firestore();
    const { status } = req.query;

    let query = db.collection('announcements');

    // If status filter is provided, apply it before ordering
    if (status) {
      query = query.where('status', '==', status);
    }

    // Order by createdAt (descending) - if this fails, it might need a Firestore index
    try {
      query = query.orderBy('createdAt', 'desc');
    } catch (orderError) {
      console.warn('Could not order by createdAt, fetching without order:', orderError.message);
      // Continue without ordering if index is missing
    }

    const snapshot = await query.get();
    const announcements = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));

    res.json({
      success: true,
      announcements
    });
  } catch (error) {
    console.error('Error fetching announcements:', error);
    console.error('Error details:', {
      message: error.message,
      code: error.code,
      stack: error.stack
    });

    // Provide more helpful error messages
    let errorMessage = error.message || 'Failed to load announcements';
    if (error.code === 8) {
      errorMessage = 'Firestore index missing. Please create a composite index for announcements collection.';
    } else if (error.code === 7) {
      errorMessage = 'Permission denied. Please check Firestore security rules.';
    } else if (error.message?.includes('not initialized')) {
      errorMessage = 'Firebase Admin not initialized. Please check environment variables.';
    }

    res.status(500).json({
      message: errorMessage,
      ...(process.env.NODE_ENV === 'development' && { details: error.message })
    });
  }
});

// @route   GET /api/admin/announcements/:id
// @desc    Get single announcement
// @access  Private (super_admin+)
router.get('/announcements/:id', requireRole('super_admin'), async (req, res) => {
  try {
    const db = admin.firestore();
    const { id } = req.params;

    const doc = await db.collection('announcements').doc(id).get();

    if (!doc.exists) {
      return res.status(404).json({ message: 'Announcement not found' });
    }

    res.json({
      success: true,
      announcement: {
        id: doc.id,
        ...doc.data()
      }
    });
  } catch (error) {
    console.error('Error fetching announcement:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   PUT /api/admin/announcements/:id
// @desc    Update announcement
// @access  Private (super_admin+)
router.put('/announcements/:id', requireRole('super_admin'), async (req, res) => {
  try {
    const db = admin.firestore();
    const { id } = req.params;
    const { title, pages, targetAudience, status } = req.body;

    const announcementRef = db.collection('announcements').doc(id);
    const doc = await announcementRef.get();

    if (!doc.exists) {
      return res.status(404).json({ message: 'Announcement not found' });
    }

    const existingData = doc.data();
    const updateData = {
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    if (title !== undefined) updateData.title = title;
    if (pages !== undefined) {
      if (!Array.isArray(pages) || pages.length === 0) {
        return res.status(400).json({ message: 'pages must be a non-empty array' });
      }
      // Validate pages
      for (const page of pages) {
        if (!page.body || typeof page.body !== 'string') {
          return res.status(400).json({ message: 'Each page must have a body string' });
        }
      }
      updateData.pages = pages;
    }
    if (targetAudience !== undefined) updateData.targetAudience = targetAudience;
    if (status !== undefined) {
      const validStatuses = ['draft', 'active', 'archived'];
      if (!validStatuses.includes(status)) {
        return res.status(400).json({ message: `status must be one of: ${validStatuses.join(', ')}` });
      }
      updateData.status = status;
    }

    // Increment version if content changed
    if (title !== undefined || pages !== undefined || targetAudience !== undefined) {
      updateData.version = (existingData.version || 1) + 1;
    }

    await announcementRef.update(updateData);

    const updatedDoc = await announcementRef.get();

    res.json({
      success: true,
      announcement: {
        id: updatedDoc.id,
        ...updatedDoc.data()
      }
    });
  } catch (error) {
    console.error('Error updating announcement:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   DELETE /api/admin/announcements/:id
// @desc    Delete/archive announcement
// @access  Private (super_admin+)
router.delete('/announcements/:id', requireRole('super_admin'), async (req, res) => {
  try {
    const db = admin.firestore();
    const { id } = req.params;

    const announcementRef = db.collection('announcements').doc(id);
    const doc = await announcementRef.get();

    if (!doc.exists) {
      return res.status(404).json({ message: 'Announcement not found' });
    }

    // Archive instead of deleting to preserve history
    await announcementRef.update({
      status: 'archived',
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    res.json({
      success: true,
      message: 'Announcement archived'
    });
  } catch (error) {
    console.error('Error archiving announcement:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   GET /api/admin/announcements/:id/stats
// @desc    Get announcement view statistics
// @access  Private (super_admin+)
router.get('/announcements/:id/stats', requireRole('super_admin'), async (req, res) => {
  try {
    const db = admin.firestore();
    const { id } = req.params;

    // Get all views for this announcement
    const viewsSnapshot = await db.collection('announcement_views')
      .where('announcementId', '==', id)
      .get();

    const totalViews = viewsSnapshot.size;
    const views = viewsSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));

    res.json({
      success: true,
      stats: {
        totalViews,
        views
      }
    });
  } catch (error) {
    console.error('Error fetching announcement stats:', error);
    res.status(500).json({ message: error.message });
  }
});

// =========================
// Welcome Screen Images Routes
// =========================

// @route   GET /api/admin/welcome-images
// @desc    Get all welcome screen images
// @access  Private (viewer+)
router.get('/welcome-images', requireRole('super_admin', 'moderator', 'viewer'), async (req, res) => {
  try {
    const db = admin.firestore();
    const doc = await db.collection('welcome_screen_images').doc('main').get();

    if (!doc.exists) {
      return res.json({
        success: true,
        images: []
      });
    }

    const data = doc.data();
    const images = data.images || [];

    // Sort by order
    images.sort((a, b) => (a.order || 0) - (b.order || 0));

    res.json({
      success: true,
      images
    });
  } catch (error) {
    console.error('Error fetching welcome images:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   POST /api/admin/welcome-images
// @desc    Upload a new welcome screen image
// @access  Private (moderator+)
router.post('/welcome-images', requireRole('super_admin', 'moderator'), upload.single('image'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ message: 'No image file provided' });
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

    // Build upload URL
    const uploadUrl = `https://api.cloudflare.com/client/v4/accounts/${accountId}/images/v1`;

    // Manually build multipart form data (matching existing upload logic)
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
    const metadata = { userId: req.admin.firebaseUid || req.admin._id?.toString() || 'admin', type: 'welcome_screen' };
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

    console.log('Uploading welcome image to Cloudflare:', {
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

      // Log full error details
      const errorDetails = {
        status: response.status,
        statusText: response.statusText,
        error: errorData,
        hasToken: !!apiToken,
        tokenLength: apiToken?.length,
        tokenPrefix: apiToken?.substring(0, 10) + '...',
        accountId: accountId?.substring(0, 10) + '...',
        errorText: errorText
      };

      console.error('Cloudflare upload error (welcome-images):', JSON.stringify(errorDetails, null, 2));

      // Provide more helpful error messages
      // Return 500 instead of 401 to avoid triggering auth interceptor
      if (errorData.errors && errorData.errors[0]?.code === 10001) {
        return res.status(500).json({
          message: 'Cloudflare authentication failed. Please check CLOUDFLARE_API_TOKEN environment variable.',
          error: 'Unable to authenticate request',
          hint: 'The API token may be missing, invalid, or expired. Check Vercel environment variables.',
          details: {
            tokenLength: apiToken?.length,
            hasToken: !!apiToken,
            cloudflareError: errorData.errors[0]
          }
        });
      }

      // Return 500 instead of the Cloudflare status to avoid triggering auth interceptor
      return res.status(500).json({
        message: 'Failed to upload image to Cloudflare',
        error: errorData.message || errorText,
        details: errorData.errors || errorData,
        cloudflareStatus: response.status
      });
    }

    const result = await response.json();

    // Extract image URL from Cloudflare response
    if (!result.result || !result.result.variants || result.result.variants.length === 0) {
      return res.status(500).json({ message: 'Invalid response from Cloudflare' });
    }

    // The first variant is typically the full image URL
    const imageUrl = result.result.variants[0];
    const imageId = result.result.id;

    // Get current images from Firestore
    const db = admin.firestore();
    const doc = await db.collection('welcome_screen_images').doc('main').get();

    let images = [];
    if (doc.exists) {
      images = doc.data().images || [];
    }

    // Find max order
    const maxOrder = images.length > 0
      ? Math.max(...images.map(img => img.order || 0))
      : -1;

    // Create new image entry
    const newImage = {
      id: imageId,
      url: imageUrl,
      order: maxOrder + 1,
      uploadedAt: admin.firestore.Timestamp.now()
    };

    images.push(newImage);

    // Update Firestore
    await db.collection('welcome_screen_images').doc('main').set({
      images,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });

    res.json({
      success: true,
      image: newImage
    });
  } catch (error) {
    console.error('Error uploading welcome image:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   DELETE /api/admin/welcome-images/:id
// @desc    Delete a welcome screen image
// @access  Private (moderator+)
router.delete('/welcome-images/:id', requireRole('super_admin', 'moderator'), async (req, res) => {
  try {
    const { id } = req.params;
    const db = admin.firestore();

    const doc = await db.collection('welcome_screen_images').doc('main').get();

    if (!doc.exists) {
      return res.status(404).json({ message: 'Welcome images document not found' });
    }

    const data = doc.data();
    let images = data.images || [];

    // Remove image with matching id
    const initialLength = images.length;
    images = images.filter(img => img.id !== id);

    if (images.length === initialLength) {
      return res.status(404).json({ message: 'Image not found' });
    }

    // Reorder remaining images
    images.forEach((img, index) => {
      img.order = index;
    });

    // Update Firestore
    await db.collection('welcome_screen_images').doc('main').set({
      images,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });

    res.json({
      success: true,
      message: 'Image deleted successfully'
    });
  } catch (error) {
    console.error('Error deleting welcome image:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   PUT /api/admin/welcome-images/reorder
// @desc    Reorder welcome screen images
// @access  Private (moderator+)
router.put('/welcome-images/reorder', requireRole('super_admin', 'moderator'), async (req, res) => {
  try {
    const { imageIds } = req.body;

    if (!imageIds || !Array.isArray(imageIds)) {
      return res.status(400).json({ message: 'imageIds array is required' });
    }

    const db = admin.firestore();
    const doc = await db.collection('welcome_screen_images').doc('main').get();

    if (!doc.exists) {
      return res.status(404).json({ message: 'Welcome images document not found' });
    }

    const data = doc.data();
    let images = data.images || [];

    // Create a map for quick lookup
    const imageMap = new Map(images.map(img => [img.id, img]));

    // Reorder images based on provided order
    const reorderedImages = imageIds.map((id, index) => {
      const image = imageMap.get(id);
      if (!image) {
        throw new Error(`Image with id ${id} not found`);
      }
      return {
        ...image,
        order: index
      };
    });

    // Add any images not in the reorder list (shouldn't happen, but handle gracefully)
    const reorderedIds = new Set(imageIds);
    images.forEach(img => {
      if (!reorderedIds.has(img.id)) {
        reorderedImages.push({
          ...img,
          order: reorderedImages.length
        });
      }
    });

    // Sort by order to ensure consistency
    reorderedImages.sort((a, b) => a.order - b.order);

    // Update Firestore
    await db.collection('welcome_screen_images').doc('main').set({
      images: reorderedImages,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });

    res.json({
      success: true,
      images: reorderedImages
    });
  } catch (error) {
    console.error('Error reordering welcome images:', error);
    res.status(500).json({ message: error.message });
  }
});

export default router;

