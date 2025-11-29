import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import { NotificationType, NotificationCategory } from "./notifications";

// Lazy initialization - get db when needed
function getDb() {
  return admin.firestore();
}

/**
 * Get FCM tokens for a user
 */
async function getUserFCMTokens(userId: string): Promise<string[]> {
  try {
    const tokensRef = getDb()
      .collection("users")
      .doc(userId)
      .collection("fcm_tokens");
    
    const tokensSnapshot = await tokensRef.get();
    const tokens: string[] = [];
    
    tokensSnapshot.forEach((doc) => {
      const tokenData = doc.data();
      if (tokenData.token && tokenData.enabled !== false) {
        tokens.push(tokenData.token);
      }
    });
    
    return tokens;
  } catch (error: any) {
    functions.logger.error(`Error fetching FCM tokens for user ${userId}: ${error.message}`);
    return [];
  }
}

/**
 * Check if user has push notifications enabled
 */
async function isPushEnabled(userId: string): Promise<boolean> {
  try {
    const prefsDoc = await getDb()
      .collection("users")
      .doc(userId)
      .collection("notification_preferences")
      .doc("settings")
      .get();
    
    if (!prefsDoc.exists) {
      return true; // Default to enabled
    }
    
    const prefs = prefsDoc.data();
    return prefs?.pushEnabled !== false;
  } catch (error: any) {
    functions.logger.error(`Error checking push preferences: ${error.message}`);
    return true; // Default to enabled on error
  }
}

/**
 * Build deep link URL for notification
 */
function buildDeepLink(
  type: NotificationType,
  category: NotificationCategory,
  targetId: string,
  activityId?: string,
  deepLink?: string
): string {
  // Use provided deepLink if available
  if (deepLink) {
    return deepLink;
  }
  
  // Build default deep links based on type
  if (category === "engagement") {
    if (activityId || targetId) {
      return `ora://post/${activityId || targetId}`;
    }
  } else if (category === "system") {
    if (type === "post_approved" || type === "post_rejected" || type === "post_flagged") {
      return `ora://post/${targetId}`;
    } else {
      return `ora://profile`;
    }
  } else if (category === "promotional") {
    return `ora://notification/${targetId}`;
  }
  
  return `ora://home`;
}

/**
 * Send push notification to a user
 */
export async function sendPushNotification(
  userId: string,
  notificationId: string,
  type: NotificationType,
  category: NotificationCategory,
  title: string,
  body: string,
  targetId: string,
  activityId?: string,
  imageUrl?: string,
  deepLink?: string
): Promise<{ success: boolean; sent: number; failed: number }> {
  // Check if push is enabled
  const pushEnabled = await isPushEnabled(userId);
  if (!pushEnabled) {
    functions.logger.log(`Push notifications disabled for user ${userId}`);
    return { success: true, sent: 0, failed: 0 };
  }
  
  // Get FCM tokens
  const tokens = await getUserFCMTokens(userId);
  if (tokens.length === 0) {
    functions.logger.log(`No FCM tokens found for user ${userId}`);
    return { success: true, sent: 0, failed: 0 };
  }
  
  // Build deep link
  const notificationDeepLink = buildDeepLink(type, category, targetId, activityId, deepLink);
  
  // Build notification payload
  const message: admin.messaging.MulticastMessage = {
    notification: {
      title,
      body,
    },
    data: {
      type,
      category,
      targetId,
      notificationId,
      deepLink: notificationDeepLink,
      ...(activityId && { activityId }),
      ...(imageUrl && { imageUrl }),
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
          badge: 1,
          "mutable-content": 1,
        },
      },
      ...(imageUrl && {
        fcmOptions: {
          imageUrl,
        },
      }),
    },
    tokens,
  };
  
  let sent = 0;
  let failed = 0;
  
  try {
    const response = await admin.messaging().sendEachForMulticast(message);
    
    sent = response.successCount;
    failed = response.failureCount;
    
    // Log failed tokens and remove invalid ones
    if (response.failureCount > 0) {
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          const token = tokens[idx];
          functions.logger.warn(`Failed to send to token ${token}: ${resp.error?.message}`);
          
          // Remove invalid tokens
          if (resp.error?.code === "messaging/invalid-registration-token" ||
              resp.error?.code === "messaging/registration-token-not-registered") {
            removeFCMToken(userId, token).catch((err) => {
              functions.logger.error(`Error removing invalid token: ${err.message}`);
            });
          }
        }
      });
    }
    
    // Track delivery
    await trackNotificationDelivery(notificationId, userId, category, sent > 0 ? "delivered" : "failed", tokens.length);
    
    functions.logger.log(
      `Push notification sent to user ${userId}: ${sent} succeeded, ${failed} failed`
    );
  } catch (error: any) {
    functions.logger.error(`Error sending push notification: ${error.message}`, error);
    failed = tokens.length;
    await trackNotificationDelivery(notificationId, userId, category, "failed", tokens.length, error.message);
  }
  
  return { success: sent > 0, sent, failed };
}

/**
 * Remove invalid FCM token
 */
async function removeFCMToken(userId: string, token: string): Promise<void> {
  try {
    const tokensRef = getDb()
      .collection("users")
      .doc(userId)
      .collection("fcm_tokens");
    
    const snapshot = await tokensRef.where("token", "==", token).get();
    const batch = getDb().batch();
    
    snapshot.forEach((doc) => {
      batch.delete(doc.ref);
    });
    
    await batch.commit();
    functions.logger.log(`Removed invalid FCM token for user ${userId}`);
  } catch (error: any) {
    functions.logger.error(`Error removing FCM token: ${error.message}`);
  }
}

/**
 * Track notification delivery
 */
async function trackNotificationDelivery(
  notificationId: string,
  userId: string,
  category: NotificationCategory,
  status: "sent" | "delivered" | "failed",
  tokenCount: number,
  error?: string
): Promise<void> {
  try {
    const deliveryDoc: any = {
      notificationId,
      userId,
      category,
      status,
      tokenCount,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    };
    
    if (error) {
      deliveryDoc.error = error;
    }
    
    await getDb()
      .collection("notification_deliveries")
      .add(deliveryDoc);
  } catch (error: any) {
    functions.logger.error(`Error tracking delivery: ${error.message}`);
  }
}

/**
 * Send batch push notifications (for promotional notifications)
 */
export async function sendBatchPushNotifications(
  userIds: string[],
  title: string,
  body: string,
  type: NotificationType,
  category: NotificationCategory,
  targetId: string,
  imageUrl?: string,
  deepLink?: string
): Promise<{ total: number; sent: number; failed: number }> {
  let total = 0;
  let sent = 0;
  let failed = 0;
  
  // Process in batches to avoid rate limits
  const batchSize = 100;
  for (let i = 0; i < userIds.length; i += batchSize) {
    const batch = userIds.slice(i, i + batchSize);
    
    const promises = batch.map(async (userId) => {
      total++;
      // Create a temporary notification ID for tracking
      const tempNotificationId = `promo_${Date.now()}_${Math.random().toString(36).substring(7)}`;
      
      const result = await sendPushNotification(
        userId,
        tempNotificationId,
        type,
        category,
        title,
        body,
        targetId,
        undefined,
        imageUrl,
        deepLink
      );
      
      if (result.success) {
        sent += result.sent;
        failed += result.failed;
      } else {
        failed++;
      }
    });
    
    await Promise.all(promises);
    
    // Small delay between batches to avoid rate limits
    if (i + batchSize < userIds.length) {
      await new Promise((resolve) => setTimeout(resolve, 100));
    }
  }
  
  return { total, sent, failed };
}













