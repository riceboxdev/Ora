import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import { sendBatchPushNotifications } from "./pushNotifications";

// Lazy initialization
function getDb() {
  return admin.firestore();
}

/**
 * Get target user IDs based on audience configuration
 */
async function getTargetUserIds(audience: any): Promise<string[]> {
  const { type, filters } = audience || {};
  
  if (type === "all") {
    // Get all users
    const usersSnapshot = await getDb().collection("users").get();
    return usersSnapshot.docs.map((doc) => doc.id);
  } else if (type === "role") {
    // Filter by role
    const role = filters?.role || "user";
    const usersSnapshot = await getDb()
      .collection("users")
      .where("isAdmin", "==", role === "admin")
      .get();
    return usersSnapshot.docs.map((doc) => doc.id);
  } else if (type === "activity") {
    // Filter by activity level (users who have been active in last N days)
    const days = filters?.days || 30;
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - days);
    
    // Get users who have created posts or engaged in the last N days
    const recentPostsSnapshot = await getDb()
      .collection("posts")
      .where("createdAt", ">=", admin.firestore.Timestamp.fromDate(cutoffDate))
      .get();
    
    const userIds = new Set<string>();
    recentPostsSnapshot.docs.forEach((doc) => {
      const userId = doc.data().userId;
      if (userId) {
        userIds.add(userId);
      }
    });
    
    return Array.from(userIds);
  } else if (type === "custom") {
    // Custom filter - for now, return empty (can be extended)
    return filters?.userIds || [];
  }
  
  return [];
}

/**
 * Check if user should receive promotional notification
 */
async function shouldReceivePromo(userId: string, promoType: string): Promise<boolean> {
  try {
    const prefsDoc = await getDb()
      .collection("users")
      .doc(userId)
      .collection("notification_preferences")
      .doc("settings")
      .get();
    
    if (!prefsDoc.exists) {
      return false; // Default to opt-out
    }
    
    const prefs = prefsDoc.data();
    const promoPrefs = prefs?.promotional || {};
    
    // Must have promotional notifications enabled
    if (!promoPrefs.enabled) {
      return false;
    }
    
    // Check specific type preference
    switch (promoType) {
      case "announcement":
        return promoPrefs.announcements !== false;
      case "promo":
        return promoPrefs.promos !== false;
      case "feature_update":
        return promoPrefs.featureUpdates !== false;
      case "event":
        return promoPrefs.events !== false;
      default:
        return true;
    }
  } catch (error: any) {
    functions.logger.error(`Error checking promo preferences: ${error.message}`);
    return false; // Default to opt-out on error
  }
}

/**
 * Create promotional notification and send to target audience
 */
export async function createAndSendPromotionalNotification(
  title: string,
  body: string,
  type: "announcement" | "promo" | "feature_update" | "event",
  targetAudience: {
    type: "all" | "role" | "activity" | "custom";
    filters?: Record<string, any>;
  },
  sentBy: string,
  imageUrl?: string,
  deepLink?: string,
  scheduledFor?: admin.firestore.Timestamp
): Promise<{ notificationId: string; stats: any }> {
  try {
    // Create promotional notification document
    const promoNotification: any = {
      title,
      body,
      type,
      targetAudience,
      sentBy,
      status: scheduledFor ? "scheduled" : "sending",
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
      promoNotification.scheduledFor = scheduledFor;
    } else {
      promoNotification.sentAt = admin.firestore.FieldValue.serverTimestamp();
    }
    
    const notificationRef = await getDb()
      .collection("promotional_notifications")
      .add(promoNotification);
    
    const notificationId = notificationRef.id;
    
    // If scheduled, return early
    if (scheduledFor) {
      return {
        notificationId,
        stats: promoNotification.stats,
      };
    }
    
    // Get target user IDs
    const allUserIds = await getTargetUserIds(targetAudience);
    functions.logger.log(`Found ${allUserIds.length} potential recipients`);
    
    // Filter by user preferences
    const eligibleUserIds: string[] = [];
    for (const userId of allUserIds) {
      const shouldReceive = await shouldReceivePromo(userId, type);
      if (shouldReceive) {
        eligibleUserIds.push(userId);
      }
    }
    
    functions.logger.log(`${eligibleUserIds.length} users opted in for ${type} notifications`);
    
    // Update stats
    await notificationRef.update({
      "stats.totalRecipients": eligibleUserIds.length,
    });
    
    // Send push notifications
    const sendResult = await sendBatchPushNotifications(
      eligibleUserIds,
      title,
      body,
      type,
      "promotional",
      notificationId,
      imageUrl,
      deepLink
    );
    
    // Update stats with delivery results
    await notificationRef.update({
      "stats.delivered": sendResult.sent,
      status: "sent",
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    // Create notification documents for each user (for in-app display)
    const batch = getDb().batch();
    let batchCount = 0;
    const maxBatchSize = 500;
    
    for (const userId of eligibleUserIds) {
      const userNotificationRef = getDb()
        .collection("users")
        .doc(userId)
        .collection("notifications")
        .doc();
      
      const notificationData: any = {
        type,
        category: "promotional",
        message: body,
        promoTitle: title,
        promoBody: body,
        targetId: notificationId,
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastActivityAt: admin.firestore.FieldValue.serverTimestamp(),
        actors: [],
        actorCount: 0,
      };
      
      if (imageUrl) {
        notificationData.promoImageUrl = imageUrl;
      }
      if (deepLink) {
        notificationData.deepLink = deepLink;
      }
      
      batch.set(userNotificationRef, notificationData);
      batchCount++;
      
      if (batchCount >= maxBatchSize) {
        await batch.commit();
        batchCount = 0;
      }
    }
    
    if (batchCount > 0) {
      await batch.commit();
    }
    
    functions.logger.log(`Created ${eligibleUserIds.length} in-app notifications`);
    
    return {
      notificationId,
      stats: {
        totalRecipients: eligibleUserIds.length,
        delivered: sendResult.sent,
        opened: 0,
        clicked: 0,
      },
    };
  } catch (error: any) {
    functions.logger.error(`Error creating promotional notification: ${error.message}`, error);
    throw error;
  }
}

/**
 * Process scheduled promotional notifications
 */
export async function processScheduledPromotions(): Promise<void> {
  try {
    const now = admin.firestore.Timestamp.now();
    
    // Find scheduled notifications that are ready to send
    const scheduledSnapshot = await getDb()
      .collection("promotional_notifications")
      .where("status", "==", "scheduled")
      .where("scheduledFor", "<=", now)
      .get();
    
    functions.logger.log(`Found ${scheduledSnapshot.size} scheduled notifications to process`);
    
    for (const doc of scheduledSnapshot.docs) {
      const data = doc.data();
      
      // Update status to sending
      await doc.ref.update({
        status: "sending",
      });
      
      // Send notification
      try {
        await createAndSendPromotionalNotification(
          data.title,
          data.body,
          data.type,
          data.targetAudience,
          data.sentBy,
          data.imageUrl,
          data.deepLink
        );
      } catch (error: any) {
        functions.logger.error(`Error sending scheduled notification ${doc.id}: ${error.message}`);
        await doc.ref.update({
          status: "failed",
        });
      }
    }
  } catch (error: any) {
    functions.logger.error(`Error processing scheduled promotions: ${error.message}`, error);
  }
}

