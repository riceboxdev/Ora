import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

// Initialize admin if not already initialized
if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();

// =========================
// Interfaces
// =========================

interface Post {
  id: string;
  userId: string;
  caption?: string;
  tags?: string[];
  imageUrl: string;
  createdAt: admin.firestore.Timestamp;
}

interface Interest {
  id: string;
  name: string;        // Normalized ID/name
  displayName: string; // Display name
  level: number;
  keywords: string[];
  synonyms: string[];
  parentId?: string;
}

interface Classification {
  interestId: string;
  interestName: string;
  interestLevel: number;
  confidence: number;
  signals: string[];
}

interface PostInterestClassification {
  postId: string;
  classifications: Classification[];
  classifiedAt: admin.firestore.FieldValue;
  version: string;
}

interface InterestCandidate {
  interestId: string;
  interestName: string;
  interestLevel: number;
  matchScore: number;
  signals: string[];
}

// =========================
// Configuration
// =========================

const CONFIG = {
  candidateLimit: 50,
  minConfidence: 0.5,
  topResultsLimit: 5,
  modelVersion: "1.0"
};

// =========================
// Cloud Functions
// =========================

/**
 * Trigger: Automatically classify post when created
 */
export const onPostCreate = functions.firestore
  .document("posts/{postId}")
  .onCreate(async (snapshot, context) => {
    const postData = snapshot.data();
    const postId = context.params.postId;

    functions.logger.log(`🔍 onPostCreate: Starting classification for post ${postId}`);

    const post: Post = {
      id: postId,
      userId: postData.userId,
      caption: postData.caption,
      tags: postData.tags,
      imageUrl: postData.imageUrl,
      createdAt: postData.createdAt
    };

    try {
      await performClassification(post);
      functions.logger.log(`✅ onPostCreate: Classification completed for post ${postId}`);
    } catch (error) {
      functions.logger.error(`❌ onPostCreate: Classification failed for post ${postId}`, error);
    }
  });

/**
 * Callable: Manually classify a post (for backfill or re-classification)
 */
export const classifyPost = functions.https.onCall(async (data, context) => {
  // Ensure user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "The function must be called while authenticated."
    );
  }

  const { postId } = data;
  if (!postId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "The function must be called with a postId."
    );
  }

  functions.logger.log(`🔍 classifyPost: Starting manual classification for post ${postId}`);

  try {
    const postDoc = await db.collection("posts").doc(postId).get();
    if (!postDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Post not found");
    }

    const postData = postDoc.data()!;
    const post: Post = {
      id: postId,
      userId: postData.userId,
      caption: postData.caption,
      tags: postData.tags,
      imageUrl: postData.imageUrl,
      createdAt: postData.createdAt
    };

    const result = await performClassification(post);
    return { success: true, classifications: result.classifications };
  } catch (error: any) {
    functions.logger.error(`❌ classifyPost: Failed for post ${postId}`, error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

// =========================
// Core Logic
// =========================

async function performClassification(post: Post): Promise<PostInterestClassification> {
  // STAGE 1: Candidate Generation
  const candidates = await generateCandidates(post);
  functions.logger.log(`📊 Generated ${candidates.length} candidates for post ${post.id}`);

  // STAGE 2: Ranking
  const classifications = rankCandidates(candidates, post);
  functions.logger.log(`✅ Ranked to ${classifications.length} classifications for post ${post.id}`);

  const result: PostInterestClassification = {
    postId: post.id,
    classifications: classifications,
    classifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    version: CONFIG.modelVersion
  };

  // Save to Firestore
  await saveClassification(result);

  return result;
}

async function generateCandidates(post: Post): Promise<InterestCandidate[]> {
  const candidates: InterestCandidate[] = [];
  const seenInterestIds = new Set<string>();

  // Extract keywords
  const keywords = extractKeywords(post);

  // Fetch all interests
  // Note: In a production environment with thousands of interests, 
  // we would want to cache this or use a more efficient search (e.g., Algolia/Elasticsearch)
  // For now, we'll fetch all active interests as the taxonomy is likely manageable (< 1000 items)
  const interestsSnapshot = await db.collection("interests").get();
  const allInterests = interestsSnapshot.docs.map(doc => {
    const data = doc.data();
    return {
      id: doc.id,
      name: data.name || doc.id,
      displayName: data.displayName,
      level: data.level || 0,
      keywords: data.keywords || [],
      synonyms: data.synonyms || [],
      parentId: data.parentId
    } as Interest;
  });

  // 1. Match against user-provided tags (highest priority)
  if (post.tags && post.tags.length > 0) {
    for (const tag of post.tags) {
      const normalizedTag = tag.toLowerCase().trim();

      for (const interest of allInterests) {
        if (seenInterestIds.has(interest.id)) continue;

        // Exact match on name
        if (interest.name.toLowerCase() === normalizedTag) {
          candidates.push({
            interestId: interest.id,
            interestName: interest.displayName,
            interestLevel: interest.level,
            matchScore: 1.0,
            signals: ["userProvidedTag"]
          });
          seenInterestIds.add(interest.id);
        }
        // Match in keywords
        else if (interest.keywords.some(k => k.toLowerCase() === normalizedTag)) {
          candidates.push({
            interestId: interest.id,
            interestName: interest.displayName,
            interestLevel: interest.level,
            matchScore: 0.9,
            signals: ["userProvidedTag"]
          });
          seenInterestIds.add(interest.id);
        }
        // Match in synonyms
        else if (interest.synonyms.some(s => s.toLowerCase() === normalizedTag)) {
          candidates.push({
            interestId: interest.id,
            interestName: interest.displayName,
            interestLevel: interest.level,
            matchScore: 0.85,
            signals: ["userProvidedTag"]
          });
          seenInterestIds.add(interest.id);
        }
      }
    }
  }

  // 2. Match against caption keywords
  for (const keyword of keywords) {
    const normalizedKeyword = keyword.toLowerCase();

    for (const interest of allInterests) {
      if (seenInterestIds.has(interest.id)) continue;

      if (
        interest.name.toLowerCase().includes(normalizedKeyword) ||
        interest.keywords.some(k => k.toLowerCase().includes(normalizedKeyword)) ||
        interest.synonyms.some(s => s.toLowerCase().includes(normalizedKeyword))
      ) {
        candidates.push({
          interestId: interest.id,
          interestName: interest.displayName,
          interestLevel: interest.level,
          matchScore: 0.7,
          signals: ["captionMatch"]
        });
        seenInterestIds.add(interest.id);
      }
    }
  }

  return candidates.slice(0, CONFIG.candidateLimit);
}

function rankCandidates(candidates: InterestCandidate[], post: Post): Classification[] {
  const scoredCandidates = candidates.map(candidate => {
    const confidence = calculateConfidence(candidate, post);
    return { candidate, confidence };
  });

  // Sort by confidence descending
  scoredCandidates.sort((a, b) => b.confidence - a.confidence);

  // Filter and limit
  return scoredCandidates
    .filter(item => item.confidence >= CONFIG.minConfidence)
    .slice(0, CONFIG.topResultsLimit)
    .map(item => ({
      interestId: item.candidate.interestId,
      interestName: item.candidate.interestName,
      interestLevel: item.candidate.interestLevel,
      confidence: item.confidence,
      signals: item.candidate.signals
    }));
}

function calculateConfidence(candidate: InterestCandidate, post: Post): number {
  let confidence = candidate.matchScore;

  const signalWeights: { [key: string]: number } = {
    userTagged: 0.20,
    userProvidedTag: 0.20,
    captionMatch: 0.35,
    boardName: 0.25,
    similarPosts: 0.10,
    userBehavior: 0.10,
    visualSimilarity: 0.10,
    tfIdf: 0.10
  };

  let totalWeight = 0.0;
  for (const signal of candidate.signals) {
    if (signalWeights[signal]) {
      totalWeight += signalWeights[signal];
    }
  }

  // Combine match score with signal weights
  confidence = (confidence * 0.50) + (totalWeight * 0.50);

  // Boost for specific interest levels (prefer more specific)
  const levelBoost = candidate.interestLevel * 0.05;
  confidence = Math.min(confidence + levelBoost, 1.0);

  return confidence;
}

function extractKeywords(post: Post): string[] {
  const keywords: string[] = [];

  if (post.caption) {
    const words = post.caption
      .toLowerCase()
      .split(/[\s\n]+/)
      .map(w => w.replace(/[^\w]/g, "")) // Remove punctuation
      .filter(w => w.length > 2); // Filter short words
    
    keywords.push(...words);
  }

  if (post.tags) {
    keywords.push(...post.tags);
  }

  return [...new Set(keywords)]; // Unique
}

async function saveClassification(classification: PostInterestClassification) {
  const batch = db.batch();

  // 1. Save to post_classifications
  const classificationRef = db.collection("post_classifications").doc(classification.postId);
  batch.set(classificationRef, classification);

  // 2. Update post document
  const postRef = db.collection("posts").doc(classification.postId);
  
  // Prepare update data
  const interestIds = classification.classifications.map(c => c.interestId);
  const primaryInterestId = classification.classifications.length > 0 
    ? classification.classifications[0].interestId 
    : null;
  
  const interestScores: { [key: string]: number } = {};
  classification.classifications.forEach(c => {
    interestScores[c.interestId] = c.confidence;
  });

  batch.update(postRef, {
    interestIds,
    primaryInterestId,
    interestScores,
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });

  // 3. Increment interest post counts
  for (const c of classification.classifications) {
    const interestRef = db.collection("interests").doc(c.interestId);
    batch.update(interestRef, {
      postCount: admin.firestore.FieldValue.increment(1)
    });
  }

  await batch.commit();
}
