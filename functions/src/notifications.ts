import * as admin from "firebase-admin";
import * as functions from "firebase-functions";

// Lazy initialization - get db when needed (after admin.initializeApp() is called)
function getDb() {
  return admin.firestore();
}

// Notification types
export type NotificationType = "like" | "comment" | "follow" | "mention";

// Actor information
export interface ActorInfo {
  id: string;
  username: string;
  profilePhotoUrl?: string | null;
}

// Notification data structure
export interface NotificationData {
  type: NotificationType;
  recipientUserId: string;
  actorId: string;
  targetId: string;
  activityId?: string;
  postImageUrl?: string;
  postThumbnailUrl?: string;
  postCaption?: string;
  metadata?: Record<string, any>;
}

// Aggregation time window: 1 hour in milliseconds
const AGGREGATION_WINDOW_MS = 60 * 60 * 1000;
// Maximum number of actor profiles to store
const MAX_ACTOR_PROFILES = 3;

/**
 * Get user profile data for actor
 */
async function getActorProfile(userId: string): Promise<ActorInfo | null> {
  try {
    const userDoc = await getDb().collection("users").doc(userId).get();
    if (!userDoc.exists) {
      functions.logger.warn(`User profile not found for actor: ${userId}`);
      return null;
    }
    
    const userData = userDoc.data();
    return {
      id: userId,
      username: userData?.username || "Unknown User",
      profilePhotoUrl: userData?.profilePhotoUrl || null,
    };
  } catch (error: any) {
    functions.logger.error(`Error fetching actor profile: ${error.message}`);
    return null;
  }
}

/**
 * Format notification message based on actors and count
 */
function formatNotificationMessage(
  type: NotificationType,
  actors: ActorInfo[],
  actorCount: number
): string {
  if (actorCount === 0) {
    return "Someone interacted with your post";
  }

  // Single actor
  if (actorCount === 1 && actors.length > 0) {
    const actor = actors[0];
    switch (type) {
      case "like":
        return `${actor.username} liked your post`;
      case "comment":
        return `${actor.username} commented on your post`;
      case "follow":
        return `${actor.username} started following you`;
      case "mention":
        return `${actor.username} mentioned you`;
      default:
        return `${actor.username} interacted with your post`;
    }
  }

  // Two actors
  if (actorCount === 2 && actors.length >= 2) {
    const [first, second] = actors;
    switch (type) {
      case "like":
        return `${first.username} and ${second.username} liked your post`;
      case "comment":
        return `${first.username} and ${second.username} commented on your post`;
      case "follow":
        return `${first.username} and ${second.username} started following you`;
      case "mention":
        return `${first.username} and ${second.username} mentioned you`;
      default:
        return `${first.username} and ${second.username} interacted with your post`;
    }
  }

  // Three or more actors
  if (actors.length >= 2) {
    const [first, second] = actors;
    const othersCount = actorCount - 2;
    switch (type) {
      case "like":
        return `${first.username}, ${second.username}, and ${othersCount} ${othersCount === 1 ? "other" : "others"} liked your post`;
      case "comment":
        return `${first.username}, ${second.username}, and ${othersCount} ${othersCount === 1 ? "other" : "others"} commented on your post`;
      case "follow":
        return `${first.username}, ${second.username}, and ${othersCount} ${othersCount === 1 ? "other" : "others"} started following you`;
      case "mention":
        return `${first.username}, ${second.username}, and ${othersCount} ${othersCount === 1 ? "other" : "others"} mentioned you`;
      default:
        return `${first.username}, ${second.username}, and ${othersCount} ${othersCount === 1 ? "other" : "others"} interacted with your post`;
    }
  }

  // Fallback
  const firstActor = actors[0];
  if (firstActor) {
    const othersCount = actorCount - 1;
    return `${firstActor.username} and ${othersCount} ${othersCount === 1 ? "other" : "others"} interacted with your post`;
  }

  return `${actorCount} people interacted with your post`;
}

/**
 * Check if a notification should be aggregated with an existing one
 */
function shouldAggregate(
  existingNotification: admin.firestore.DocumentSnapshot,
  newNotification: NotificationData,
  now: Date
): boolean {
  const existingData = existingNotification.data();
  if (!existingData) {
    return false;
  }

  // Must be same type
  if (existingData.type !== newNotification.type) {
    return false;
  }

  // Must be same target
  if (existingData.targetId !== newNotification.targetId) {
    return false;
  }

  // Must be within aggregation time window
  const lastActivityAt = existingData.lastActivityAt?.toDate();
  if (!lastActivityAt) {
    return false;
  }

  const timeDiff = now.getTime() - lastActivityAt.getTime();
  if (timeDiff > AGGREGATION_WINDOW_MS) {
    return false;
  }

  // Don't aggregate if actor already exists (avoid duplicates)
  const existingActors = existingData.actors || [];
  const actorExists = existingActors.some(
    (actor: ActorInfo) => actor.id === newNotification.actorId
  );

  if (actorExists) {
    return false;
  }

  return true;
}

/**
 * Create or aggregate a notification in Firestore
 */
export async function createOrAggregateNotification(
  notificationData: NotificationData
): Promise<string> {
  const {
    type,
    recipientUserId,
    actorId,
    targetId,
    activityId,
    postImageUrl,
    postThumbnailUrl,
    postCaption,
    metadata,
  } = notificationData;

  // Don't notify if user is acting on their own content
  if (recipientUserId === actorId) {
    functions.logger.log(
      `Skipping notification: user ${actorId} is acting on their own content`
    );
    return "";
  }

  const now = admin.firestore.Timestamp.now();
  const nowDate = now.toDate();

  // Get actor profile
  const actorProfile = await getActorProfile(actorId);
  if (!actorProfile) {
    functions.logger.warn(`Could not get actor profile for ${actorId}, skipping notification`);
    return "";
  }

  // Check for existing notifications that can be aggregated
  const notificationsRef = getDb()
    .collection("users")
    .doc(recipientUserId)
    .collection("notifications");

  // Query for existing unread notifications matching type and targetId
  // Note: We can't use orderBy with multiple where clauses without an index
  // So we'll fetch all matching notifications and sort in memory
  const existingNotificationsQuery = notificationsRef
    .where("type", "==", type)
    .where("targetId", "==", targetId)
    .where("isRead", "==", false);
  
  const existingNotificationsSnapshot = await existingNotificationsQuery.get();
  
  // Sort by lastActivityAt in memory and get the most recent one
  let mostRecentNotification: admin.firestore.QueryDocumentSnapshot | null = null;
  let mostRecentTime: admin.firestore.Timestamp | null = null;
  
  for (const doc of existingNotificationsSnapshot.docs) {
    const data = doc.data();
    const lastActivityAt = data.lastActivityAt as admin.firestore.Timestamp | null;
    
    if (!mostRecentNotification) {
      mostRecentNotification = doc;
      mostRecentTime = lastActivityAt;
    } else if (lastActivityAt && mostRecentTime) {
      if (lastActivityAt.toMillis() > mostRecentTime.toMillis()) {
        mostRecentNotification = doc;
        mostRecentTime = lastActivityAt;
      }
    } else if (lastActivityAt && !mostRecentTime) {
      mostRecentNotification = doc;
      mostRecentTime = lastActivityAt;
    }
  }

  let notificationId: string;
  let isNewNotification = true;

  // Check if we should aggregate with existing notification
  const existingNotification = mostRecentNotification;
  if (existingNotification) {
    if (shouldAggregate(existingNotification, notificationData, nowDate)) {
      // Aggregate with existing notification
      notificationId = existingNotification.id;
      isNewNotification = false;

      const existingData = existingNotification.data();
      const existingActors: ActorInfo[] = existingData.actors || [];
      const existingActorCount = existingData.actorCount || 1;

      // Add new actor to actors array (max 3)
      let updatedActors = [...existingActors];
      if (updatedActors.length < MAX_ACTOR_PROFILES) {
        updatedActors.push(actorProfile);
      } else {
        // Replace oldest actor if we're at max (keep most recent)
        updatedActors = [...updatedActors.slice(-MAX_ACTOR_PROFILES + 1), actorProfile];
      }

      const updatedActorCount = existingActorCount + 1;
      const updatedMessage = formatNotificationMessage(type, updatedActors, updatedActorCount);

      // Update existing notification
      await existingNotification.ref.update({
        actors: updatedActors,
        actorCount: updatedActorCount,
        message: updatedMessage,
        lastActivityAt: now,
        updatedAt: now,
      });

      functions.logger.log(
        `Aggregated notification ${notificationId}: ${updatedActorCount} actors (${type} on ${targetId})`
      );
    } else {
      // Create new notification
      notificationId = await createNewNotification(
        notificationsRef,
        type,
        targetId,
        activityId,
        postImageUrl,
        postThumbnailUrl,
        postCaption,
        metadata,
        actorProfile,
        now
      );
    }
  } else {
    // Create new notification
    notificationId = await createNewNotification(
      notificationsRef,
      type,
      targetId,
      activityId,
      postImageUrl,
      postThumbnailUrl,
      postCaption,
      metadata,
      actorProfile,
      now
    );
  }

  return isNewNotification ? notificationId : "";
}

/**
 * Create a new notification document
 */
async function createNewNotification(
  notificationsRef: admin.firestore.CollectionReference,
  type: NotificationType,
  targetId: string,
  activityId: string | undefined,
  postImageUrl: string | undefined,
  postThumbnailUrl: string | undefined,
  postCaption: string | undefined,
  metadata: Record<string, any> | undefined,
  actorProfile: ActorInfo,
  now: admin.firestore.Timestamp
): Promise<string> {
  const message = formatNotificationMessage(type, [actorProfile], 1);

  // Ensure actor profilePhotoUrl is null instead of undefined
  const cleanActorProfile: ActorInfo = {
    id: actorProfile.id,
    username: actorProfile.username,
    profilePhotoUrl: actorProfile.profilePhotoUrl ?? null,
  };

  const notificationDoc: any = {
    type,
    message,
    actors: [cleanActorProfile],
    actorCount: 1,
    targetId,
    isRead: false,
    createdAt: now,
    updatedAt: now,
    lastActivityAt: now,
  };

  // Add optional fields (only if they have values)
  if (activityId) {
    notificationDoc.activityId = activityId;
  }
  if (postImageUrl) {
    notificationDoc.postImageUrl = postImageUrl;
  }
  if (postThumbnailUrl) {
    notificationDoc.postThumbnailUrl = postThumbnailUrl;
  }
  if (postCaption) {
    notificationDoc.postCaption = postCaption;
  }
  if (metadata) {
    notificationDoc.metadata = metadata;
  }

  const docRef = await notificationsRef.add(notificationDoc);
  functions.logger.log(
    `Created new notification ${docRef.id}: ${message} (${type} on ${targetId})`
  );

  return docRef.id;
}

