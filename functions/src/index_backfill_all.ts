/**
 * Backfill image dimensions for all posts in discover feed
 * Admin-only function to backfill dimensions for all posts
 */
export const backfillAllImageDimensions = functions.https.onCall(async (data: any, context) => {
  assertAuthenticated(context);
  const authenticatedUserId = context.auth!.uid;
  
  // Check if user is admin
  try {
    const userDoc = await admin.firestore().collection("users").doc(authenticatedUserId).get();
    const userData = userDoc.data();
    if (!userData?.isAdmin) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Only admins can backfill all image dimensions"
      );
    }
  } catch (error: any) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError(
      "permission-denied",
      "Only admins can backfill all image dimensions"
    );
  }
  
  const { 
    feedGroup = "discover",
    feedId = "global",
    limit = 100
  } = data || {};
  
  try {
    functions.logger.log(`Starting backfill of all image dimensions`);
    functions.logger.log(`   Feed group: ${feedGroup}`);
    functions.logger.log(`   Feed ID: ${feedId}`);
    functions.logger.log(`   Limit: ${limit}`);
    
    const results: any = {
      processed: 0,
      updated: 0,
      skipped: 0,
      errors: []
    };
    
    // Get activities from discover feed
    const feed = streamClient.feed(feedGroup, feedId);
    const activitiesResponse = await feed.get({ limit });
    const activities = activitiesResponse?.results || [];
    
    functions.logger.log(`Found ${activities.length} activities to process`);
    
    // Process activities
    for (const activity of activities) {
      try {
        results.processed++;
        
        const activityAny = activity as any;
        const activityId = activityAny.id || activityAny.activity_id || activityAny.foreign_id;
        
        if (!activityId) {
          results.skipped++;
          continue;
        }
        
        // Check if dimensions already exist
        const custom = activityAny.custom || {};
        if (custom.imageWidth && custom.imageHeight) {
          results.skipped++;
          continue;
        }
        
        // Get image URL
        const imageUrl = custom.imageUrl || custom.image_url || "";
        if (!imageUrl) {
          results.skipped++;
          continue;
        }
        
        // Get dimensions from Cloudinary
        const dimensions = await getImageDimensionsFromCloudinary(imageUrl);
        if (!dimensions) {
          results.skipped++;
          continue;
        }
        
        // Update Firestore document
        try {
          const postDoc = await admin.firestore().collection("posts").doc(activityId).get();
          
          if (postDoc.exists) {
            await admin.firestore().collection("posts").doc(activityId).update({
              imageWidth: dimensions.width,
              imageHeight: dimensions.height,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              dimensionsBackfilled: true
            });
            results.updated++;
            functions.logger.log(`✅ Updated Firestore post ${activityId} with dimensions ${dimensions.width}x${dimensions.height}`);
          } else {
            // Create post in Firestore if it doesn't exist
            const actor = activityAny.actor;
            const actorId = typeof actor === "string" 
              ? (actor.includes(":") ? actor.split(":")[1] : actor)
              : (actor?.id || "unknown");
            
            const timeString = activityAny.time || activityAny.created_at || activityAny.createdAt;
            const createdAt = timeString 
              ? (typeof timeString === "string" ? new Date(timeString) : timeString)
              : new Date();
            
            await admin.firestore().collection("posts").doc(activityId).set({
              activityId: activityId,
              userId: actorId,
              imageUrl: imageUrl,
              thumbnailUrl: custom.thumbnailUrl || custom.thumbnail_url || imageUrl,
              imageWidth: dimensions.width,
              imageHeight: dimensions.height,
              caption: custom.caption || custom.text || null,
              tags: custom.tags || [],
              categories: custom.categories || [],
              createdAt: createdAt,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              foreignId: activityAny.foreign_id || activityId,
              dimensionsBackfilled: true
            });
            results.updated++;
            functions.logger.log(`✅ Created Firestore post ${activityId} with dimensions ${dimensions.width}x${dimensions.height}`);
          }
        } catch (firestoreError: any) {
          results.errors.push({
            activityId: activityId,
            error: `Firestore update failed: ${firestoreError.message}`
          });
          functions.logger.error(`Error updating Firestore for activity ${activityId}: ${firestoreError.message}`);
        }
        
      } catch (activityError: any) {
        const activityAny = activity as any;
        results.errors.push({
          activityId: activityAny.id || activityAny.activity_id || "unknown",
          error: activityError.message
        });
        functions.logger.error(`Error processing activity: ${activityError.message}`);
      }
    }
    
    const message = `Backfill complete. Processed ${results.processed} posts, updated ${results.updated}, skipped ${results.skipped}, errors ${results.errors.length}`;
    functions.logger.log(`✅ ${message}`);
    
    return {
      success: results.errors.length === 0,
      ...results,
      message: message
    };
    
  } catch (error: any) {
    functions.logger.error(`Backfill failed: ${error.message}`, error);
    throw new functions.https.HttpsError(
      "internal",
      `Backfill failed: ${error.message}`
    );
  }
});















