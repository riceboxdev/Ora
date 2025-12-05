import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import * as https from "https";
import * as crypto from "crypto";
// Note: Stream import is kept for potential future use
// If you need to use Stream APIs server-side, uncomment the line below:
// import * as stream from "getstream";

admin.initializeApp();

// Stream server client configuration
// Default API key matches the iOS app Config.swift
const streamApiKey = process.env.STREAM_API_KEY || "8pwvyy4wrvek";
// IMPORTANT: Set STREAM_API_SECRET environment variable in Firebase Functions
// Get it from: https://dashboard.getstream.io/ → Your App → API Keys
const streamApiSecret = process.env.STREAM_API_SECRET || "z83ynbabke3s6r9uxh58w9njt7qmbxakf9fh76vzgrw5y4rm7bmfjzm2jz3y4p6a";
// Note: streamClient is not currently used, but Stream API key/secret are used by ensureStreamUser function

// Generate JWT token for server-side authentication
// Based on Stream REST API docs: https://getstream.io/docs_rest/
function generateServerToken(resource: string = "*", action: string = "*", feedId: string = "*"): string {
  const header = {
    typ: "JWT",
    alg: "HS256"
  };

  const payload = {
    resource,
    action,
    feed_id: feedId
  };

  const encodedHeader = Buffer.from(JSON.stringify(header)).toString("base64url");
  const encodedPayload = Buffer.from(JSON.stringify(payload)).toString("base64url");

  const signature = crypto
    .createHmac("sha256", streamApiSecret)
    .update(`${encodedHeader}.${encodedPayload}`)
    .digest("base64url");

  return `${encodedHeader}.${encodedPayload}.${signature}`;
}

// Helper function to make authenticated requests to Stream REST API
// Based on: https://getstream.io/docs_rest/
// Activity Feeds v2 uses /api/v2/ endpoints
async function streamApiRequest(
  method: string,
  endpoint: string,
  body?: any
): Promise<any> {
  return new Promise((resolve, reject) => {
    // For Activity Feeds v2, use /api/v2/ endpoints
    const basePath = "/api/v2";
    const fullPath = endpoint.startsWith("/")
      ? `${basePath}${endpoint}`
      : `${basePath}/${endpoint}`;

    // Generate JWT token for server-side auth (full access)
    const token = generateServerToken("*", "*", "*");

    const requestBody = body ? JSON.stringify(body) : undefined;

    // Build query string - for GET requests, params can be in body or query string
    // For Stream API, GET requests use query params, POST/PUT use body
    const queryString = new URLSearchParams();
    queryString.append("api_key", streamApiKey);

    // If it's a GET request and body is provided, treat body as query params
    if (method === "GET" && body && typeof body === "object") {
      for (const [key, value] of Object.entries(body)) {
        if (value !== undefined && value !== null) {
          queryString.append(key, String(value));
        }
      }
    }

    const options = {
      hostname: "feeds.stream-io-api.com",
      path: `${fullPath}?${queryString.toString()}`,
      method: method,
      headers: {
        "Content-Type": "application/json",
        "Stream-Auth-Type": "jwt",
        "Authorization": token,
        ...(requestBody && method !== "GET" && { "Content-Length": Buffer.byteLength(requestBody).toString() }),
      },
    };

    functions.logger.log(`Stream API Request: ${method} https://${options.hostname}${options.path}`);
    if (body) {
      functions.logger.log(`Request body: ${JSON.stringify(body).substring(0, 200)}`);
    }

    const req = https.request(options, (res) => {
      let data = "";
      res.on("data", (chunk) => {
        data += chunk;
      });
      res.on("end", () => {
        // Log full response for debugging (but truncate if very long)
        const logData = data.length > 1000 ? data.substring(0, 1000) + "..." : data;
        functions.logger.log(`Stream API Response: ${res.statusCode} - ${logData}`);
        if (res.statusCode && res.statusCode >= 200 && res.statusCode < 300) {
          try {
            resolve(data ? JSON.parse(data) : {});
          } catch {
            resolve(data || {});
          }
        } else {
          try {
            const error = JSON.parse(data);
            // Log full error object for debugging
            functions.logger.error(`Stream API Error Details:`, JSON.stringify(error, null, 2));

            // Stream API error structure can vary:
            // - { StatusCode: 404, code: 16, message: "...", details: [] }
            // - { detail: "...", code: 6 }
            // - { message: "...", code: 16 }
            const errorCode = error.code || error.Code;
            const errorMsg = error.detail || error.message || error.Message || error.error || `HTTP ${res.statusCode}`;
            const errorCodeStr = errorCode ? ` (code: ${errorCode})` : '';

            // Normalize error object
            const normalizedError = {
              code: errorCode,
              message: errorMsg,
              detail: error.detail || error.Detail,
              statusCode: error.StatusCode || res.statusCode,
              details: error.details || error.Details || [],
              more_info: error.more_info || error.moreInfo
            };

            // Create error object with full details for better debugging
            const enhancedError = new Error(`${errorMsg}${errorCodeStr}`);
            (enhancedError as any).statusCode = res.statusCode;
            (enhancedError as any).streamError = normalizedError;
            (enhancedError as any).rawResponse = data;
            reject(enhancedError);
          } catch {
            const parseError = new Error(`HTTP ${res.statusCode}: ${data}`);
            (parseError as any).statusCode = res.statusCode;
            (parseError as any).rawResponse = data;
            reject(parseError);
          }
        }
      });
    });

    req.on("error", (err) => {
      functions.logger.error(`Stream API Request Error: ${err}`);
      reject(err);
    });

    if (requestBody) {
      req.write(requestBody);
    }
    req.end();
  });
}

// Authentication guard: requires user to be authenticated
function assertAuthenticated(context: functions.https.CallableContext) {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "The function must be called while authenticated.",
    );
  }
}

// =========================
// Stream Authentication
// =========================

/**
 * Ensure Stream user exists - creates user and feed if they don't exist
 * This is a fallback for when the Firebase Extension doesn't create users automatically
 * 
 * NOTE: Stream user token generation, creation, and deletion are handled by the official
 * Firebase Extension: "Authenticate with Stream Activity Feeds"
 * Extension URL: https://us-central1-angles-423a4.cloudfunctions.net/ext-auth-activity-feeds-getStreamUserToken
 * The extension provides:
 * - getStreamUserToken: Generates Stream user tokens
 * - createStreamUser: Creates Stream users when Firebase users are created
 * - deleteStreamUser: Deletes Stream users when Firebase users are deleted
 * 
 * The ensureStreamUser function below is a fallback when the extension doesn't work
 */
export const ensureStreamUser = functions.https.onCall(async (data: any, context) => {
  assertAuthenticated(context);
  const authenticatedUserId = context.auth!.uid;

  const { userId } = data || {};

  // Verify the user is creating their own Stream user
  if (userId && userId !== authenticatedUserId) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Users can only create their own Stream user"
    );
  }

  const targetUserId = userId || authenticatedUserId;

  try {
    functions.logger.log(`Ensuring Stream user exists for ${targetUserId}`);

    // First, verify if the feed exists
    const feedEndpoint = `/feeds/user/${targetUserId}/`;
    try {
      await streamApiRequest("GET", feedEndpoint);
      functions.logger.log(`✅ Feed already exists for user ${targetUserId}`);
      return { success: true, message: "User feed already exists" };
    } catch (getError: any) {
      const getErrorMessage = getError?.message || String(getError);

      // If we get a 404, the feed/user doesn't exist
      // The Firebase Extension creates Stream users, but feeds are created when you first post to them
      // If the feed group "user" doesn't exist in Stream Dashboard, you'll get a 404 or error code 6
      // Stream error code 6 = Feed Config Error (Missing or misconfigured feed)
      // Stream error code 16 = Does Not Exist Error (Resource not found)
      if (getErrorMessage.includes("404") ||
        getErrorMessage.includes("Not Found") ||
        getErrorMessage.includes("code: 6") ||
        getErrorMessage.includes("code:6") ||
        getErrorMessage.includes("code: 16") ||
        getErrorMessage.includes("code:16")) {
        functions.logger.log(`❌ Feed doesn't exist for ${targetUserId}`);
        functions.logger.warn(`The Firebase Extension creates Stream users, but the feed group "user" must exist in Stream Dashboard`);

        // Return a failed-precondition error with helpful message
        throw new functions.https.HttpsError(
          "failed-precondition",
          `Stream user feed does not exist for user ${targetUserId}. ` +
          `The Firebase Extension creates Stream users, but the feed group "user" must be configured in your Stream Dashboard. ` +
          `Please go to https://dashboard.getstream.io/ → Your App → Activity Feeds → Feed Groups and ensure a feed group named "user" exists. ` +
          `If it doesn't exist, create it as a Flat Feed. Once the feed group exists, feeds will be auto-created when users post.`
        );
      } else {
        // Some other error
        throw getError;
      }
    }
  } catch (e: any) {
    // If it's already an HttpsError, re-throw it
    if (e instanceof functions.https.HttpsError) {
      throw e;
    }

    functions.logger.error(`Failed to ensure Stream user exists for ${targetUserId}:`, e);
    const errorMessage = e?.message || String(e);

    // If it's a failed-precondition error, preserve it
    if (errorMessage.includes("failed-precondition") || errorMessage.includes("feed group")) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        errorMessage
      );
    }

    throw new functions.https.HttpsError(
      "internal",
      `Failed to ensure Stream user exists: ${errorMessage}`
    );
  }
});

// Note: Post metrics (likeCount, commentCount, viewCount, shareCount, saveCount) are updated
// client-side via FeedAnalyticsService. Firestore rules allow any authenticated user to
// update only these metric fields on any post. This is simpler and more efficient than
// using Cloud Functions, and FeedService calculates metrics on-the-fly when fetching posts
// to ensure accuracy.

// =========================
// Post Creation and Management
// =========================

/**
 * Create a new post - saves to Firestore only
 */
export const createPost = functions.https.onCall(async (data: any, context) => {
  assertAuthenticated(context);
  const userId = context.auth!.uid;

  const {
    imageUrl,
    thumbnailUrl,
    imageWidth,
    imageHeight,
    caption,
    tags = [],
    categories = [],
    interestIds = []  // New interest system
  } = data || {};

  if (!imageUrl) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "imageUrl is required"
    );
  }

  try {
    functions.logger.log(`Creating post for user ${userId}`);

    // Generate post ID
    const postId = `post_${userId}_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;

    // Create post data
    const postData: any = {
      activityId: postId, // Keep activityId for backwards compatibility
      userId: userId,
      imageUrl: imageUrl,
      thumbnailUrl: thumbnailUrl || imageUrl, // Use provided thumbnailUrl or fallback to imageUrl
      caption: caption || null,
      tags: tags || [],
      categories: categories || [],
      interestIds: interestIds || [],  // New interest system
      likeCount: 0,
      commentCount: 0,
      viewCount: 0,
      shareCount: 0,
      saveCount: 0,
      isDeleted: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    if (imageWidth) {
      postData.imageWidth = imageWidth;
    }

    if (imageHeight) {
      postData.imageHeight = imageHeight;
    }

    // Save post to Firestore
    await admin.firestore().collection("posts").doc(postId).set(postData);
    functions.logger.log(`✅ Created post in Firestore with ID: ${postId}`);
    functions.logger.log(`   Image URL: ${imageUrl}`);
    functions.logger.log(`   Thumbnail URL: ${postData.thumbnailUrl}`);

    // Update tag collection (non-blocking)
    if (tags && Array.isArray(tags) && tags.length > 0) {
      try {
        await updateTagCollection(tags);
      } catch (error: any) {
        functions.logger.error(`Failed to update tag collection: ${error.message}`);
        // Don't fail the post creation if tag update fails
      }
    }

    // Update interest counts (non-blocking)
    if (interestIds && Array.isArray(interestIds) && interestIds.length > 0) {
      try {
        await updateInterestCounts(interestIds, 1);
        functions.logger.log(`✅ Updated interest counts for ${interestIds.length} interest(s)`);
      } catch (error: any) {
        functions.logger.error(`Failed to update interest counts: ${error.message}`);
        // Don't fail the post creation if interest update fails
      }
    }

    return {
      success: true,
      postId: postId,
      activityId: postId, // Keep for backwards compatibility
      message: "Post created successfully"
    };
  } catch (error: any) {
    functions.logger.error(`Failed to create post: ${error.message}`, error);

    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw new functions.https.HttpsError(
      "internal",
      `Failed to create post: ${error.message}`
    );
  }
});

/**
 * Edit a post - updates Firestore (Stream activities are immutable)
 */
export const editPost = functions.https.onCall(async (data: any, context) => {
  assertAuthenticated(context);
  const userId = context.auth!.uid;

  const {
    activityId,
    caption,
    tags,
    categories,
    interestIds  // New interest system
  } = data || {};

  if (!activityId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "activityId is required"
    );
  }

  try {
    // Verify post ownership
    const postDoc = await admin.firestore().collection("posts").doc(activityId).get();

    if (!postDoc.exists) {
      throw new functions.https.HttpsError(
        "not-found",
        "Post not found"
      );
    }

    const postData = postDoc.data();
    if (postData?.userId !== userId) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Only post owner can edit posts"
      );
    }

    // Update post in Firestore
    const updateData: any = {
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      edited: true
    };

    if (caption !== undefined) {
      updateData.caption = caption;
    }

    if (tags !== undefined) {
      updateData.tags = tags;
    }

    if (categories !== undefined) {
      updateData.categories = categories;
    }

    if (interestIds !== undefined) {
      updateData.interestIds = interestIds;
    }

    await admin.firestore().collection("posts").doc(activityId).update(updateData);

    functions.logger.log(`✅ Updated post ${activityId} in Firestore`);

    // Update tag collection if tags were changed (non-blocking)
    if (tags !== undefined && Array.isArray(tags)) {
      try {
        await updateTagCollection(tags);
      } catch (error: any) {
        functions.logger.error(`Failed to update tag collection: ${error.message}`);
        // Don't fail the post update if tag update fails
      }
    }

    // Update interest counts if interests were changed (non-blocking)
    if (interestIds !== undefined && Array.isArray(interestIds)) {
      try {
        const oldInterestIds = postData?.interestIds || [];

        // Find removed interests (decrement)
        const removedInterests = oldInterestIds.filter((id: string) => !interestIds.includes(id));
        if (removedInterests.length > 0) {
          await updateInterestCounts(removedInterests, -1);
          functions.logger.log(`✅ Decremented counts for ${removedInterests.length} removed interest(s)`);
        }

        // Find added interests (increment)
        const addedInterests = interestIds.filter((id: string) => !oldInterestIds.includes(id));
        if (addedInterests.length > 0) {
          await updateInterestCounts(addedInterests, 1);
          functions.logger.log(`✅ Incremented counts for ${addedInterests.length} added interest(s)`);
        }
      } catch (error: any) {
        functions.logger.error(`Failed to update interest counts: ${error.message}`);
        // Don't fail the post update if interest update fails
      }
    }

    return {
      success: true,
      message: "Post updated successfully"
    };
  } catch (error: any) {
    functions.logger.error(`Failed to edit post: ${error.message}`, error);

    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw new functions.https.HttpsError(
      "internal",
      `Failed to edit post: ${error.message}`
    );
  }
});

/**
 * Delete a post - removes from Firestore
 * Only the post owner can delete their posts
 */
export const deletePost = functions.https.onCall(async (data: any, context) => {
  assertAuthenticated(context);
  const userId = context.auth!.uid;

  const { postId } = data || {};

  if (!postId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "postId is required"
    );
  }

  try {
    // Verify post ownership
    const postDoc = await admin.firestore().collection("posts").doc(postId).get();

    if (!postDoc.exists) {
      throw new functions.https.HttpsError(
        "not-found",
        "Post not found"
      );
    }

    const postData = postDoc.data();
    if (postData?.userId !== userId) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Only post owner can delete posts"
      );
    }

    // Get post's interests before deletion
    const postInterestIds = postData?.interestIds || [];

    // Delete post from Firestore
    await admin.firestore().collection("posts").doc(postId).delete();
    functions.logger.log(`✅ Deleted post ${postId} from Firestore`);

    // Decrement interest counts (non-blocking)
    if (postInterestIds.length > 0) {
      try {
        await updateInterestCounts(postInterestIds, -1);
        functions.logger.log(`✅ Decremented counts for ${postInterestIds.length} interest(s)`);
      } catch (error: any) {
        functions.logger.error(`Failed to update interest counts: ${error.message}`);
        // Don't fail the deletion if interest update fails
      }
    }

    return {
      success: true,
      message: "Post deleted successfully"
    };
  } catch (error: any) {
    functions.logger.error(`Failed to delete post: ${error.message}`, error);

    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw new functions.https.HttpsError(
      "internal",
      `Failed to delete post: ${error.message}`
    );
  }
});

// =========================
// Trend Detection System
// =========================

/**
 * Helper function to perform trend analysis (extracted for reuse)
 */
async function performTrendAnalysis(
  timeWindow: string,
  minPostThreshold: number,
  personalized: boolean,
  userId: string
): Promise<any> {
  // Calculate time range
  const now = Date.now();
  let startTime: number;
  let previousStartTime: number;

  switch (timeWindow) {
    case "24h":
      startTime = now - 24 * 60 * 60 * 1000;
      previousStartTime = startTime - 24 * 60 * 60 * 1000;
      break;
    case "7d":
      startTime = now - 7 * 24 * 60 * 60 * 1000;
      previousStartTime = startTime - 7 * 24 * 60 * 60 * 1000;
      break;
    case "30d":
      startTime = now - 30 * 24 * 60 * 60 * 1000;
      previousStartTime = startTime - 30 * 24 * 60 * 60 * 1000;
      break;
    default:
      startTime = now - 24 * 60 * 60 * 1000;
      previousStartTime = startTime - 24 * 60 * 60 * 1000;
  }

  // Query posts in current time window
  const postsSnapshot = await admin.firestore()
    .collection("posts")
    .where("createdAt", ">=", admin.firestore.Timestamp.fromMillis(startTime))
    .where("createdAt", "<=", admin.firestore.Timestamp.fromMillis(now))
    .get();

  // Query posts in previous time window for comparison
  const previousPostsSnapshot = await admin.firestore()
    .collection("posts")
    .where("createdAt", ">=", admin.firestore.Timestamp.fromMillis(previousStartTime))
    .where("createdAt", "<", admin.firestore.Timestamp.fromMillis(startTime))
    .get();

  // Aggregate topics (tags and categories only - semantic labels excluded)
  const topicMap: Map<string, any> = new Map();
  const previousTopicMap: Map<string, any> = new Map();

  // Process current period posts
  postsSnapshot.forEach((doc) => {
    const post = doc.data();
    const engagementScore = (post.likeCount || 0) * 2 +
      (post.commentCount || 0) * 3 +
      (post.saveCount || 0) * 4 +
      (post.shareCount || 0) * 2 +
      (post.viewCount || 0) * 0.1;

    // Skip semantic labels - not used for trending topics
    // Semantic labels are only used for image analysis and search, not trending

    // Process tags
    if (post.tags && Array.isArray(post.tags)) {
      post.tags.forEach((tag: string) => {
        const normalizedTag = tag.toLowerCase().trim();
        if (!topicMap.has(`tag:${normalizedTag}`)) {
          topicMap.set(`tag:${normalizedTag}`, {
            id: normalizedTag,
            type: "tag",
            name: tag,
            postCount: 0,
            engagementScore: 0,
            uniqueEngagers: new Set<string>(),
            posts: []
          });
        }
        const topic = topicMap.get(`tag:${normalizedTag}`);
        topic.postCount++;
        topic.engagementScore += engagementScore;
        topic.uniqueEngagers.add(post.userId);
        topic.posts.push(doc.id);
      });
    }

    // Process categories
    if (post.categories && Array.isArray(post.categories)) {
      post.categories.forEach((category: string) => {
        const normalizedCategory = category.toLowerCase().trim();
        if (!topicMap.has(`category:${normalizedCategory}`)) {
          topicMap.set(`category:${normalizedCategory}`, {
            id: normalizedCategory,
            type: "category",
            name: category,
            postCount: 0,
            engagementScore: 0,
            uniqueEngagers: new Set<string>(),
            posts: []
          });
        }
        const topic = topicMap.get(`category:${normalizedCategory}`);
        topic.postCount++;
        topic.engagementScore += engagementScore;
        topic.uniqueEngagers.add(post.userId);
        topic.posts.push(doc.id);
      });
    }
  });

  // Process previous period for comparison
  previousPostsSnapshot.forEach((doc) => {
    const post = doc.data();
    const engagementScore = (post.likeCount || 0) * 2 +
      (post.commentCount || 0) * 3 +
      (post.saveCount || 0) * 4 +
      (post.shareCount || 0) * 2 +
      (post.viewCount || 0) * 0.1;

    const processTopic = (key: string, type: string, name: string) => {
      if (!previousTopicMap.has(key)) {
        previousTopicMap.set(key, {
          postCount: 0,
          engagementScore: 0,
          uniqueEngagers: new Set<string>()
        });
      }
      const topic = previousTopicMap.get(key);
      topic.postCount++;
      topic.engagementScore += engagementScore;
      topic.uniqueEngagers.add(post.userId);
    };

    // Skip semantic labels - not used for trending topics
    // Only process tags and categories for trending

    if (post.tags && Array.isArray(post.tags)) {
      post.tags.forEach((tag: string) => {
        processTopic(`tag:${tag.toLowerCase().trim()}`, "tag", tag);
      });
    }
    if (post.categories && Array.isArray(post.categories)) {
      post.categories.forEach((category: string) => {
        processTopic(`category:${category.toLowerCase().trim()}`, "category", category);
      });
    }
  });

  // Calculate trend scores
  const trendingTopics: any[] = [];
  const totalUsers = new Set<string>();
  postsSnapshot.forEach((doc) => {
    totalUsers.add(doc.data().userId);
  });
  const totalUserCount = totalUsers.size || 1;

  topicMap.forEach((topic, key) => {
    if (topic.postCount < minPostThreshold) {
      functions.logger.debug(`Skipping topic "${topic.name}" (${topic.type}): only ${topic.postCount} posts, need ${minPostThreshold}`);
      return; // Skip topics with too few posts
    }

    const previous = previousTopicMap.get(key) || {
      postCount: 0,
      engagementScore: 0,
      uniqueEngagers: new Set<string>()
    };

    // Calculate scores
    const engagementScore = topic.engagementScore / topic.postCount; // Average per post
    const userEngagementScore = topic.uniqueEngagers.size / totalUserCount;
    const previousEngagement = previous.engagementScore || 0.1; // Avoid division by zero
    const velocityScore = (topic.engagementScore - previousEngagement) / previousEngagement;
    const volumeScore = topic.postCount / postsSnapshot.size;

    // Calculate trend score
    const trendScore = (
      Math.min(engagementScore / 100, 1) * 0.35 + // Normalize engagement
      userEngagementScore * 0.25 +
      Math.min(Math.max(velocityScore, -1), 1) * 0.25 + // Clamp velocity
      volumeScore * 0.15
    );

    // Get top posts (by engagement)
    const topPosts = topic.posts.slice(0, 10);

    trendingTopics.push({
      id: topic.id,
      type: topic.type,
      name: topic.name,
      postCount: topic.postCount,
      engagementScore: engagementScore,
      userEngagementScore: userEngagementScore,
      growthRate: previous.postCount > 0
        ? ((topic.postCount - previous.postCount) / previous.postCount) * 100
        : 100,
      trendScore: Math.max(0, Math.min(1, trendScore)), // Clamp to 0-1
      timeWindow: timeWindow,
      topPosts: topPosts,
      metadata: {
        uniqueEngagers: topic.uniqueEngagers.size,
        engagementVelocity: velocityScore
      }
    });
  });

  // Sort by trend score
  trendingTopics.sort((a, b) => b.trendScore - a.trendScore);

  // If personalized, weight by user preferences
  if (personalized) {
    // Get user preferences
    const userDoc = await admin.firestore().collection("users").doc(userId).get();
    const userData = userDoc.data();
    // Skip preferredLabels - semantic labels are not used for trending topics
    const preferredTags = userData?.preferredTags || [];
    const preferredCategories = userData?.preferredCategories || [];

    // Apply preference weights (only for tags and categories)
    trendingTopics.forEach((topic) => {
      let preferenceWeight = 1.0;
      // Skip label type - semantic labels are not included in trending topics
      if (topic.type === "tag" && preferredTags.includes(topic.id)) {
        preferenceWeight = 1.5;
      } else if (topic.type === "category" && preferredCategories.includes(topic.id)) {
        preferenceWeight = 1.5;
      }
      topic.trendScore *= preferenceWeight;
      topic.personalized = true;
    });

    // Re-sort after applying weights
    trendingTopics.sort((a, b) => b.trendScore - a.trendScore);
  }

  return {
    success: true,
    topics: trendingTopics,
    timeWindow: timeWindow,
    personalized: personalized
  };
}


/**
 * Get trending topics (cached or real-time)
 */
export const getTrendingTopics = functions.https.onCall(async (data: any, context) => {
  assertAuthenticated(context);
  const userId = context.auth!.uid;

  const {
    timeWindow = "24h",
    limit = 20,
    personalized = false
  } = data || {};

  try {
    // Try to get cached trends first
    // For personalized trends, cache per-user; for global, cache shared
    const scope = personalized ? "personalized" : "global";
    const cacheKey = personalized
      ? `${scope}_${userId}_${timeWindow}`
      : `${scope}_${timeWindow}`;

    const cachedDoc = await admin.firestore()
      .collection("trending_topics")
      .doc(cacheKey)
      .get();

    if (cachedDoc.exists) {
      const cached = cachedDoc.data();
      const age = Date.now() - cached!.lastUpdated.toMillis();
      // Use cache if less than 1 hour old
      if (age < 60 * 60 * 1000) {
        // Filter out any topics that might have been based on semantic labels
        // Only include topics with type "tag" or "category"
        const allTopics = cached!.topics || [];
        const filteredTopics = allTopics.filter((topic: any) => {
          return topic.type === "tag" || topic.type === "category";
        });

        // Log diagnostic information
        functions.logger.log(`Cache hit (${scope}): ${allTopics.length} total topics, ${filteredTopics.length} after filtering (removed ${allTopics.length - filteredTopics.length} semantic label topics)`);

        if (filteredTopics.length === 0 && allTopics.length > 0) {
          functions.logger.warn(`All cached topics were filtered out (they were semantic labels). Cache age: ${Math.round(age / 1000 / 60)} minutes. Consider clearing cache.`);
        }

        return {
          success: true,
          topics: filteredTopics.slice(0, limit),
          cached: true
        };
      }
    }

    // Otherwise, run analysis using helper function
    const result = await performTrendAnalysis(timeWindow, 3, personalized, userId);

    // Log diagnostic information
    functions.logger.log(`Trend analysis results (${scope}): ${result.topics.length} topics found`);
    if (result.topics.length === 0) {
      functions.logger.warn(`No trending topics found - this could mean:
        1. Not enough posts with tags/categories in the last ${timeWindow}
        2. Topics don't meet minimum threshold (3 posts)
        3. Posts only have semantic labels (not tags/categories)`);
    }

    // Cache the results (per-user for personalized, shared for global)
    try {
      await admin.firestore()
        .collection("trending_topics")
        .doc(cacheKey)
        .set({
          topics: result.topics,
          timeWindow: timeWindow,
          scope: scope,
          userId: personalized ? userId : undefined, // Store userId for personalized trends
          lastUpdated: admin.firestore.FieldValue.serverTimestamp()
        });
      functions.logger.log(`Cached ${result.topics.length} ${scope} trends for ${personalized ? `user ${userId}` : 'all users'}`);
    } catch (cacheError: any) {
      functions.logger.warn(`Failed to cache trends: ${cacheError.message}`);
      // Continue even if caching fails
    }

    return {
      success: true,
      topics: result.topics.slice(0, limit),
      cached: false
    };
  } catch (error: any) {
    functions.logger.error(`Failed to get trending topics: ${error.message}`, error);
    throw new functions.https.HttpsError(
      "internal",
      `Failed to get trending topics: ${error.message}`
    );
  }
});

/**
 * Clear trending topics cache (admin function)
 * Removes all cached trending topics to force fresh calculation
 * This will remove old topics that were based on semantic labels
 */
export const clearTrendingTopicsCache = functions.https.onCall(async (data: any, context) => {
  assertAuthenticated(context);

  try {
    // Get all cached trending topics documents
    const cacheSnapshot = await admin.firestore()
      .collection("trending_topics")
      .get();

    if (cacheSnapshot.empty) {
      return {
        success: true,
        message: "No cached topics found",
        deletedCount: 0
      };
    }

    // Delete all cached documents
    const batch = admin.firestore().batch();
    cacheSnapshot.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });
    await batch.commit();

    functions.logger.log(`✅ Cleared ${cacheSnapshot.size} cached trending topics documents`);

    return {
      success: true,
      message: `Cleared ${cacheSnapshot.size} cached trending topics`,
      deletedCount: cacheSnapshot.size
    };
  } catch (error: any) {
    functions.logger.error(`Failed to clear trending topics cache: ${error.message}`, error);
    throw new functions.https.HttpsError(
      "internal",
      `Failed to clear cache: ${error.message}`
    );
  }
});

/**
 * Get posts by topic
 */
export const getPostsByTopic = functions.https.onCall(async (data: any, context) => {
  assertAuthenticated(context);

  const {
    topicId,
    topicType, // "label" | "tag" | "category"
    limit = 20,
    timeWindow = "7d"
  } = data || {};

  if (!topicId || !topicType) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "topicId and topicType are required"
    );
  }

  try {
    // Calculate time range
    const now = Date.now();
    let startTime: number;
    switch (timeWindow) {
      case "24h":
        startTime = now - 24 * 60 * 60 * 1000;
        break;
      case "7d":
        startTime = now - 7 * 24 * 60 * 60 * 1000;
        break;
      case "30d":
        startTime = now - 30 * 24 * 60 * 60 * 1000;
        break;
      default:
        startTime = now - 7 * 24 * 60 * 60 * 1000;
    }

    const normalizedTopicId = topicId.toLowerCase().trim();
    const fieldName = topicType === "tag" ? "tags" : "categories";

    // Query posts with this topic
    const postsSnapshot = await admin.firestore()
      .collection("posts")
      .where(fieldName, "array-contains", normalizedTopicId)
      .where("createdAt", ">=", admin.firestore.Timestamp.fromMillis(startTime))
      .orderBy("createdAt", "desc")
      .limit(limit)
      .get();

    const posts = postsSnapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data()
    }));

    return {
      success: true,
      posts: posts,
      count: posts.length
    };
  } catch (error: any) {
    functions.logger.error(`Failed to get posts by topic: ${error.message}`, error);
    throw new functions.https.HttpsError(
      "internal",
      `Failed to get posts by topic: ${error.message}`
    );
  }
});

/**
 * Scheduled function to aggregate and cache trending topics
 */
export const aggregateTopics = functions.pubsub.schedule("every 1 hours").onRun(async (context) => {
  try {
    functions.logger.log("Starting topic aggregation");

    const timeWindows = ["24h", "7d", "30d"];
    const scopes = ["global", "personalized"];

    // Note: For personalized, we'd need to run for each user or use a representative sample
    // For now, we'll just cache global trends
    for (const timeWindow of timeWindows) {
      for (const scope of scopes) {
        if (scope === "personalized") {
          // Skip personalized for now - would need user-specific processing
          continue;
        }

        try {
          // Run analysis using helper function (not via HTTP call)
          const result = await performTrendAnalysis(
            timeWindow,
            3,
            scope === "personalized",
            "system"
          );

          // Cache results
          await admin.firestore()
            .collection("trending_topics")
            .doc(`${scope}_${timeWindow}`)
            .set({
              topics: result.topics,
              timeWindow: timeWindow,
              scope: scope,
              lastUpdated: admin.firestore.FieldValue.serverTimestamp()
            });

          functions.logger.log(`✅ Cached ${scope} trends for ${timeWindow}`);
        } catch (error: any) {
          functions.logger.error(`Failed to aggregate ${scope} trends for ${timeWindow}: ${error.message}`);
        }
      }
    }

    functions.logger.log("✅ Topic aggregation complete");
  } catch (error: any) {
    functions.logger.error(`Topic aggregation failed: ${error.message}`, error);
  }
});

// =========================
// Tag Management System
// =========================

/**
 * Get tag suggestions with intelligent fallback hierarchy
 */
export const getTagSuggestions = functions.https.onCall(async (data: any, context) => {
  assertAuthenticated(context);
  const userId = context.auth!.uid;

  const {
    query = "",
    limit = 20
  } = data || {};

  try {
    const normalizedQuery = query.toLowerCase().trim();
    const suggestions: any[] = [];
    const suggestionMap = new Map<string, any>();

    // 1. User's previous tags (if user has history)
    if (userId) {
      const userPostsSnapshot = await admin.firestore()
        .collection("posts")
        .where("userId", "==", userId)
        .limit(100)
        .get();

      const userTagCounts = new Map<string, number>();
      userPostsSnapshot.forEach((doc) => {
        const post = doc.data();
        if (post.tags && Array.isArray(post.tags)) {
          post.tags.forEach((tag: string) => {
            const normalizedTag = tag.toLowerCase().trim();
            if (normalizedQuery === "" || normalizedTag.includes(normalizedQuery)) {
              userTagCounts.set(normalizedTag, (userTagCounts.get(normalizedTag) || 0) + 1);
            }
          });
        }
      });

      // Add user's tags
      Array.from(userTagCounts.entries())
        .sort((a, b) => b[1] - a[1])
        .slice(0, 10)
        .forEach(([tag, count]) => {
          if (!suggestionMap.has(tag)) {
            suggestionMap.set(tag, {
              tag: tag,
              source: "user",
              score: count,
              displayName: tag
            });
          } else {
            // Boost existing suggestion if it's also in user's history
            suggestionMap.get(tag).score += count * 0.5;
          }
        });
    }

    // 3. Popular tags (global fallback) - always include global suggestions
    // First try the tags collection (aggregated tag stats)
    try {
      const tagsSnapshot = await admin.firestore()
        .collection("tags")
        .orderBy("usageCount", "desc")
        .limit(100)
        .get();

      if (!tagsSnapshot.empty) {
        tagsSnapshot.forEach((doc) => {
          const tagData = doc.data();
          const normalizedTag = tagData.id.toLowerCase().trim();
          if (normalizedQuery === "" || normalizedTag.includes(normalizedQuery)) {
            if (!suggestionMap.has(normalizedTag)) {
              suggestionMap.set(normalizedTag, {
                tag: normalizedTag,
                source: "popular",
                score: tagData.usageCount || 0,
                displayName: tagData.name || normalizedTag
              });
            }
          }
        });
      }
    } catch (error: any) {
      // Tags collection might not exist yet, fall through to querying posts directly
      functions.logger.warn(`Tags collection not available, falling back to posts query: ${error.message}`);
    }

    // Fallback: Get popular tags by querying all posts if tags collection is empty
    if (suggestionMap.size < 10 || suggestionMap.size === 0) {
      try {
        const allPostsSnapshot = await admin.firestore()
          .collection("posts")
          .where("tags", "!=", null) // Only posts with tags
          .limit(500) // Sample a larger set for better global distribution
          .get();

        const globalTagCounts = new Map<string, number>();
        allPostsSnapshot.forEach((doc) => {
          const post = doc.data();
          if (post.tags && Array.isArray(post.tags)) {
            post.tags.forEach((tag: string) => {
              const normalizedTag = tag.toLowerCase().trim();
              if (normalizedQuery === "" || normalizedTag.includes(normalizedQuery)) {
                globalTagCounts.set(normalizedTag, (globalTagCounts.get(normalizedTag) || 0) + 1);
              }
            });
          }
        });

        // Add global popular tags
        Array.from(globalTagCounts.entries())
          .sort((a, b) => b[1] - a[1])
          .slice(0, 20) // Get top 20 most popular globally
          .forEach(([tag, count]) => {
            if (!suggestionMap.has(tag)) {
              suggestionMap.set(tag, {
                tag: tag,
                source: "popular",
                score: count,
                displayName: tag
              });
            } else {
              // Boost score if already exists
              const existing = suggestionMap.get(tag);
              if (existing && existing.source === "popular") {
                existing.score = Math.max(existing.score, count);
              }
            }
          });
      } catch (error: any) {
        functions.logger.warn(`Failed to get global popular tags from posts: ${error.message}`);
      }
    }

    // Convert to array and sort by score
    suggestions.push(...Array.from(suggestionMap.values()));
    suggestions.sort((a, b) => {
      // Prioritize by source: context > user > popular
      const sourceOrder: { [key: string]: number } = { context: 3, user: 2, popular: 1 };
      const sourceDiff = (sourceOrder[b.source] || 0) - (sourceOrder[a.source] || 0);
      if (sourceDiff !== 0) return sourceDiff;
      return b.score - a.score;
    });

    return {
      success: true,
      suggestions: suggestions.slice(0, limit)
    };
  } catch (error: any) {
    functions.logger.error(`Failed to get tag suggestions: ${error.message}`, error);
    throw new functions.https.HttpsError(
      "internal",
      `Failed to get tag suggestions: ${error.message}`
    );
  }
});

/**
 * Validate post tags (1-5 tags required)
 */
export const validatePostTags = functions.https.onCall(async (data: any, context) => {
  const { tags } = data || {};

  if (!tags || !Array.isArray(tags)) {
    return {
      valid: false,
      error: "Tags must be an array"
    };
  }

  if (tags.length === 0) {
    return {
      valid: false,
      error: "At least 1 tag is required"
    };
  }

  if (tags.length > 5) {
    return {
      valid: false,
      error: "Maximum 5 tags allowed"
    };
  }

  // Validate tag format
  for (const tag of tags) {
    if (typeof tag !== "string" || tag.trim().length === 0) {
      return {
        valid: false,
        error: "All tags must be non-empty strings"
      };
    }
    if (tag.length > 50) {
      return {
        valid: false,
        error: "Tags must be 50 characters or less"
      };
    }
  }

  return {
    valid: true
  };
});

/**
 * Update tag collection when post is created/edited
 * This should be called from createPost and editPost
 */
async function updateTagCollection(tags: string[]) {
  if (!tags || !Array.isArray(tags)) {
    return;
  }

  const batch = admin.firestore().batch();

  for (const tag of tags) {
    const normalizedTag = tag.toLowerCase().trim();
    if (normalizedTag.length === 0) continue;

    const tagRef = admin.firestore().collection("tags").doc(normalizedTag);
    const tagDoc = await tagRef.get();

    if (tagDoc.exists) {
      // Update existing tag
      batch.update(tagRef, {
        usageCount: admin.firestore.FieldValue.increment(1),
        lastUsed: admin.firestore.FieldValue.serverTimestamp(),
        postCount: admin.firestore.FieldValue.increment(1)
      });
    } else {
      // Create new tag
      batch.set(tagRef, {
        id: normalizedTag,
        name: tag, // Preserve original casing
        usageCount: 1,
        postCount: 1,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        lastUsed: admin.firestore.FieldValue.serverTimestamp(),
        variants: []
      });
    }
  }

  await batch.commit();
}

/**
 * Update interest collection when post is created/edited/deleted
 * Increments or decrements postCount for each interest
 * @param interestIds - Array of interest IDs to update
 * @param increment - 1 to increment, -1 to decrement
 */
async function updateInterestCounts(interestIds: string[], increment: number = 1) {
  if (!interestIds || !Array.isArray(interestIds) || interestIds.length === 0) {
    return;
  }

  const batch = admin.firestore().batch();

  for (const interestId of interestIds) {
    const normalizedInterestId = interestId.toLowerCase().trim();
    if (normalizedInterestId.length === 0) continue;

    const interestRef = admin.firestore().collection("interests").doc(normalizedInterestId);

    const updateData: any = {
      postCount: admin.firestore.FieldValue.increment(increment),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    // Only update lastPostAt when incrementing (new post added)
    if (increment > 0) {
      updateData.lastPostAt = admin.firestore.FieldValue.serverTimestamp();
    }

    batch.update(interestRef, updateData);
  }

  await batch.commit();
  functions.logger.log(`Updated ${interestIds.length} interest(s) postCount by ${increment}`);
}

// =========================

// Cloudflare Images Upload
// =========================

/**
 * Get Cloudflare Images upload URL and API token
 * This provides secure access to Cloudflare Images API without exposing the API token to the client
 * 
 * Documentation: https://developers.cloudflare.com/images/upload-images/
 */
export const uploadToCloudflare = functions.https.onCall(async (data: any, context) => {
  assertAuthenticated(context);

  const { userId } = data || {};
  const authenticatedUserId = context.auth!.uid;

  // Verify the user is requesting their own upload token
  if (userId && userId !== authenticatedUserId) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Users can only request upload tokens for themselves"
    );
  }

  try {
    // Get Cloudflare credentials from environment variables
    // For v1 functions, use functions.config()
    // For v2 functions, use process.env (secrets are automatically injected)
    const accountId = process.env.CLOUDFLARE_ACCOUNT_ID
      || functions.config().cloudflare?.account_id
      || "9f5f4bb22646ea1c62d1019e99026a66";

    const apiToken = process.env.CLOUDFLARE_API_TOKEN
      || functions.config().cloudflare?.api_token
      || "11HhvRaGba4Xc9hye24x5MOqEy90SMrh";

    if (!accountId || !apiToken) {
      functions.logger.error("Cloudflare credentials not configured");
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Cloudflare credentials not configured. Please set CLOUDFLARE_ACCOUNT_ID and CLOUDFLARE_API_TOKEN environment variables."
      );
    }

    // Log token info (without exposing the full token)
    functions.logger.log(`Cloudflare token configured - length: ${apiToken.length}, prefix: ${apiToken.substring(0, 10)}...`);

    // Validate token format (Cloudflare API tokens are typically 40 characters)
    // But they can vary, so we just check it's not empty
    if (apiToken.length < 10) {
      functions.logger.warn("Cloudflare API token seems too short - may be invalid");
    }

    // Build the upload URL
    // Format: https://api.cloudflare.com/client/v4/accounts/{account_id}/images/v1
    const uploadUrl = `https://api.cloudflare.com/client/v4/accounts/${accountId}/images/v1`;

    functions.logger.log(`Generated Cloudflare upload info for user ${authenticatedUserId}`);

    return {
      uploadUrl: uploadUrl,
      apiToken: apiToken
    };
  } catch (error: any) {
    functions.logger.error(`Failed to get Cloudflare upload info: ${error.message}`, error);

    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw new functions.https.HttpsError(
      "internal",
      `Failed to get upload info: ${error.message}`
    );
  }
});

// =========================
// Image Migration Support
// =========================

/**
 * Update post image URLs in Firestore
 * This is called by the iOS app migration service to update posts after migrating images
 * from Cloudinary to Cloudflare
 */
export const updatePostImageUrls = functions.https.onCall(async (data: any, context) => {
  assertAuthenticated(context);

  const { postId, imageUrl, thumbnailUrl, originalCloudinaryUrl, originalCloudinaryThumbnailUrl } = data || {};

  functions.logger.log(`updatePostImageUrls called with postId: ${postId}`);
  functions.logger.log(`  imageUrl: ${imageUrl}`);
  functions.logger.log(`  thumbnailUrl: ${thumbnailUrl}`);
  functions.logger.log(`  originalCloudinaryUrl: ${originalCloudinaryUrl}`);
  functions.logger.log(`  authenticatedUserId: ${context.auth!.uid}`);

  if (!postId || !imageUrl) {
    functions.logger.error(`Missing required parameters: postId=${postId}, imageUrl=${imageUrl}`);
    throw new functions.https.HttpsError(
      "invalid-argument",
      "postId and imageUrl are required"
    );
  }

  try {
    const postRef = admin.firestore().collection("posts").doc(postId);
    functions.logger.log(`Fetching post document: ${postId}`);

    const postDoc = await postRef.get();

    if (!postDoc.exists) {
      functions.logger.error(`Post ${postId} not found in Firestore`);
      // Try to find similar post IDs for debugging
      try {
        const similarPosts = await admin.firestore()
          .collection("posts")
          .where("userId", "==", context.auth!.uid)
          .limit(5)
          .get();
        functions.logger.log(`Found ${similarPosts.size} posts by this user. Sample IDs:`);
        similarPosts.docs.slice(0, 3).forEach((doc) => {
          functions.logger.log(`  - ${doc.id}`);
        });
      } catch (debugError: any) {
        functions.logger.warn(`Could not fetch similar posts for debugging: ${debugError.message}`);
      }

      throw new functions.https.HttpsError(
        "not-found",
        `Post ${postId} not found`
      );
    }

    const postData = postDoc.data()!;
    const postUserId = postData.userId;
    const authenticatedUserId = context.auth!.uid;

    functions.logger.log(`Post found. Owner: ${postUserId}, Authenticated: ${authenticatedUserId}`);

    // Verify the user owns the post or is an admin
    if (postUserId !== authenticatedUserId) {
      functions.logger.error(`Permission denied: User ${authenticatedUserId} does not own post ${postId} (owner: ${postUserId})`);
      // Check if user is admin (you may want to add admin check here)
      throw new functions.https.HttpsError(
        "permission-denied",
        "You can only update your own posts"
      );
    }

    // Update the post
    const updateData: any = {
      imageUrl: imageUrl,
      thumbnailUrl: thumbnailUrl || imageUrl,
      migratedToCloudflare: true,
      migratedToCloudflareAt: admin.firestore.FieldValue.serverTimestamp(),
      originalCloudinaryUrl: originalCloudinaryUrl,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    if (originalCloudinaryThumbnailUrl !== undefined) {
      updateData.originalCloudinaryThumbnailUrl = originalCloudinaryThumbnailUrl;
    }

    functions.logger.log(`Updating post ${postId} with new URLs`);
    await postRef.update(updateData);

    functions.logger.log(`✅ Updated post ${postId} with Cloudflare URLs`);
    functions.logger.log(`  New imageUrl: ${imageUrl}`);
    functions.logger.log(`  New thumbnailUrl: ${updateData.thumbnailUrl}`);

    return {
      success: true,
      postId: postId,
      imageUrl: imageUrl,
      thumbnailUrl: thumbnailUrl || imageUrl
    };
  } catch (error: any) {
    functions.logger.error(`Failed to update post image URLs for ${postId}: ${error.message}`, error);

    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw new functions.https.HttpsError(
      "internal",
      `Failed to update post image URLs: ${error.message}`
    );
  }
});

