# Admin Dashboard Requirements: Post Classification Management (Phase 2)

## Overview

This document outlines the admin dashboard requirements for managing the **Post Classification System** (Pin2Interest). This system automatically classifies posts into the Interest Taxonomy using a 2-stage machine learning approach.

---

## Firestore Schema

### Collection: `post_classifications`

Each document stores the classification results for a single post:

```typescript
interface PostInterestClassification {
  postId: string;                      // Post ID (document ID)
  classifications: Classification[];   // Array of interest classifications
  classifiedAt: Timestamp;             // When classification occurred
  version: string;                     // Classification model version (e.g., "1.0")
}

interface Classification {
  interestId: string;                  // Interest ID
  interestName: string;                // Interest display name
  interestLevel: number;               // Depth in taxonomy
  confidence: number;                  // 0.0 to 1.0
  signals: ClassificationSignal[];     // How this was classified
}

enum ClassificationSignal {
  userTagged = "userTagged",           // User explicitly selected
  captionMatch = "captionMatch",       // Found in caption
  userProvidedTag = "userProvidedTag", // Found in user's tags
  boardName = "boardName",             // Matched board name
  similarPosts = "similarPosts",       // Similar posts have this
  userBehavior = "userBehavior",       // Users who engage have this
  visualSimilarity = "visualSimilarity", // Image analysis (future)
  tfIdf = "tfIdf"                      // TF-IDF score (future)
}
```

**Example Document:**

```json
{
  "postId": "abc123",
  "classifications": [
    {
      "interestId": "fashion_models_runway",
      "interestName": "Runway Models",
      "interestLevel": 2,
      "confidence": 0.92,
      "signals": ["captionMatch", "userProvidedTag"]
    },
    {
      "interestId": "fashion_shows",
      "interestName": "Fashion Shows",
      "interestLevel": 1,
      "confidence": 0.78,
      "signals": ["captionMatch"]
    }
  ],
  "classifiedAt": "2024-12-01T14:00:00Z",
  "version": "1.0"
}
```

### Updates to `posts` Collection

Posts now include interest classification fields:

```typescript
interface Post {
  // ... existing fields ...
  
  // NEW: Interest classification
  interestIds?: string[];              // Array of interest IDs by confidence
  interestScores?: {                   // Interest ID → confidence map
    [interestId: string]: number;
  };
  primaryInterestId?: string;          // Highest confidence interest
  
  // Existing (maintained for compatibility)
  tags?: string[];                     // User-provided freeform tags
  categories?: string[];               // Legacy (deprecated)
}
```

---

## Required Admin Features

### 1. Post Classification Viewer

**Browse Classified Posts:**
- Table view of all classified posts
- Columns:
  - Post thumbnail
  - Post caption (truncated)
  - Primary interest (badge)
  - All interests (pills/tags)
  - Confidence scores (color-coded)
  - Classification date
  - Actions (view, edit, reclassify)
  
**Filters:**
- By interest (dropdown with hierarchy)
- By confidence threshold (slider: 0.0-1.0)
- By classification signal
- By date range
- Unclassified posts only

**Search:**
- Search posts by caption or ID
- Find posts by specific interest

---

### 2. Classification Details Page

**For a Single Post:**

**Post Info:**
- Full image
- Caption
- User tags
- Posted by (username)
- Posted date

**Classifications:**
- List all classifications with:
  - Interest name (with breadcrumb path)
  - Confidence score (progress bar)
  - Classification signals (badges)
- Highlight primary interest

**Actions:**
- **Edit Classifications**: Manually add/remove interests
- **Adjust Confidence**: Override confidence scores
- **Reclassify**: Run classification again

---

### 3. Manual Classification Editor

**Add Interest to Post:**
- Search/select interest from hierarchy
- Set confidence (0.0-1.0)
- Mark signal as `userTagged`
- Save

**Remove Interest:**
- Select classification to remove
- Confirm removal
- Update post document

**Set Primary Interest:**
- Choose from existing classifications
- Or add new one and mark as primary

---

### 4. Bulk Classification Operations

**Classify Unclassified Posts:**
- Show count of unclassified posts
- Button: "Classify All Unclassified Posts"
- Progress bar with real-time updates
- Show results: success count, errors

**Reclassify All Posts:**
- Warning: This is expensive
- Option to filter (by date, by interest, etc.)
- Batch process with updates
- Show progress

**Reclassify by Interest:**
- Select an interest
- Reclassify all posts with that interest
- Useful after updating interest keywords

---

### 5. Classification Analytics Dashboard

**Key Metrics:**
- Total classified posts
- Total unclassified posts
- Average classifications per post
- Average confidence score
- Classification coverage by interest

**Visualizations:**
- **Posts by Interest** (bar chart)
  - X-axis: Interest names
  - Y-axis: Post count
  - Sort by count descending
  
- **Confidence Distribution** (histogram)
  - X-axis: Confidence ranges (0.0-0.2, 0.2-0.4, etc.)
  - Y-axis: Number of classifications
  
- **Classification Signals** (pie chart)
  - How posts are being classified
  - Breakdown by signal type
  
- **Classification Timeline** (line chart)
  - X-axis: Date
  - Y-axis: Posts classified
  - Track classification activity

**Interest Performance:**
- Table of interests with:
  - Interest name
  - Total posts
  - Average confidence
  - Growth trend
- Sort by any column

---

### 6. Classification Quality Control

**Low Confidence Review:**
- List posts with classifications below threshold (e.g., 0.5)
- Quick approve/reject interface
- Batch actions

**Misclassification Reporter:**
- For each interest, show:
  - Posts that might be misclassified
  - Low confidence classifications
  - Outlier posts (different from others in same interest)
- Admin can review and correct

---

### 7. Model Version Management

**Version History:**
- List all classification model versions
- Show stats for each version:
  - Posts classified with this version
  - Average confidence
  - Date deployed
  
**Upgrade Classifications:**
- When new model version deployed
- Option to reclassify posts with old version
- Track upgrade progress

---

## Firebase Admin SDK Examples

### Get Post Classification

```typescript
async function getPostClassification(postId: string) {
  const doc = await db.collection('post_classifications')
    .doc(postId)
    .get();
  
  if (!doc.exists) {
    return null;
  }
  
  return doc.data() as PostInterestClassification;
}
```

### Manually Add Interest to Post

```typescript
async function addInterestToPost(
  postId: string,
  interestId: string,
  confidence: number = 1.0
) {
  // Get current classification
  const classDoc = await db.collection('post_classifications')
    .doc(postId)
    .get();
  
  // Get interest details
  const interest = await db.collection('interests')
    .doc(interestId)
    .get();
  
  if (!interest.exists) {
    throw new Error('Interest not found');
  }
  
  const interestData = interest.data();
  
  // Create new classification
  const newClassification: Classification = {
    interestId,
    interestName: interestData.displayName,
    interestLevel: interestData.level,
    confidence,
    signals: ['userTagged']
  };
  
  // Add to existing or create new
  if (classDoc.exists) {
    const existing = classDoc.data() as PostInterestClassification;
    
    // Check if already exists
    const existingIndex = existing.classifications.findIndex(
      c => c.interestId === interestId
    );
    
    if (existingIndex >= 0) {
      // Update existing
      existing.classifications[existingIndex] = newClassification;
    } else {
      // Add new
      existing.classifications.push(newClassification);
    }
    
    // Sort by confidence
    existing.classifications.sort((a, b) => b.confidence - a.confidence);
    
    await classDoc.ref.update({
      classifications: existing.classifications,
      classifiedAt: admin.firestore.FieldValue.serverTimestamp()
    });
  } else {
    // Create new classification doc
    await db.collection('post_classifications').doc(postId).set({
      postId,
      classifications: [newClassification],
      classifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      version: '1.0'
    });
  }
  
  // Update post document
  await updatePostInterestFields(postId);
}
```

### Update Post Interest Fields

```typescript
async function updatePostInterestFields(postId: string) {
  const classDoc = await db.collection('post_classifications')
    .doc(postId)
    .get();
  
  if (!classDoc.exists) {
    return;
  }
  
  const classification = classDoc.data() as PostInterestClassification;
  
  // Sort by confidence
  const sorted = classification.classifications.sort(
    (a, b) => b.confidence - a.confidence
  );
  
  // Build interest arrays and map
  const interestIds = sorted.map(c => c.interestId);
  const primaryInterestId = sorted[0]?.interestId || null;
  const interestScores: {[key: string]: number} = {};
  
  for (const c of sorted) {
    interestScores[c.interestId] = c.confidence;
  }
  
  // Update post
  await db.collection('posts').doc(postId).update({
    interestIds,
    primaryInterestId,
    interestScores
  });
}
```

### Remove Interest from Post

```typescript
async function removeInterestFromPost(
  postId: string,
  interestId: string
) {
  const classDoc = await db.collection('post_classifications')
    .doc(postId)
    .get();
  
  if (!classDoc.exists) {
    return;
  }
  
  const classification = classDoc.data() as PostInterestClassification;
  
  // Filter out the interest
  classification.classifications = classification.classifications.filter(
    c => c.interestId !== interestId
  );
  
  // Update
  await classDoc.ref.update({
    classifications: classification.classifications,
    classifiedAt: admin.firestore.FieldValue.serverTimestamp()
  });
  
  // Update post document
  await updatePostInterestFields(postId);
  
  // Decrement interest post count
  await db.collection('interests').doc(interestId).update({
    postCount: admin.firestore.FieldValue.increment(-1)
  });
}
```

### Bulk Classify Unclassified Posts

```typescript
async function classifyUnclassifiedPosts(
  batchSize: number = 100,
  onProgress?: (completed: number, total: number) => void
) {
  // Find unclassified posts
  const postsSnapshot = await db.collection('posts')
    .where('interestIds', '==', null)
    .limit(batchSize)
    .get();
  
  const total = postsSnapshot.size;
  let completed = 0;
  
  for (const postDoc of postsSnapshot.docs) {
    try {
      // Call classification Cloud Function
      await callClassificationFunction(postDoc.id);
      completed++;
      
      if (onProgress) {
        onProgress(completed, total);
      }
    } catch (error) {
      console.error(`Failed to classify post ${postDoc.id}:`, error);
    }
  }
  
  return { completed, total, errors: total - completed };
}

async function callClassificationFunction(postId: string) {
  // This would call your Firebase Cloud Function
  // Example using Firebase Functions SDK:
  const functions = getFunctions();
  const classifyPost = httpsCallable(functions, 'classifyPost');
  await classifyPost({ postId });
}
```

### Get Classification Analytics

```typescript
async function getClassificationAnalytics() {
  // Get all classifications
  const allClassifications = await db.collection('post_classifications').get();
  
  // Get all posts
  const allPosts = await db.collection('posts').get();
  
  const totalPosts = allPosts.size;
  const classifiedPosts = allClassifications.size;
  const unclassifiedPosts = totalPosts - classifiedPosts;
  
  // Calculate metrics
  let totalClassifications = 0;
  let totalConfidence = 0;
  const signalCounts: {[key: string]: number} = {};
  const interestPostCounts: {[key: string]: number} = {};
  
  for (const doc of allClassifications.docs) {
    const data = doc.data() as PostInterestClassification;
    
    for (const classification of data.classifications) {
      totalClassifications++;
      totalConfidence += classification.confidence;
      
      // Count signals
      for (const signal of classification.signals) {
        signalCounts[signal] = (signalCounts[signal] || 0) + 1;
      }
      
      // Count posts per interest
      interestPostCounts[classification.interestId] = 
        (interestPostCounts[classification.interestId] || 0) + 1;
    }
  }
  
  const avgClassificationsPerPost = classifiedPosts > 0 
    ? totalClassifications / classifiedPosts 
    : 0;
  
  const avgConfidence = totalClassifications > 0
    ? totalConfidence / totalClassifications
    : 0;
  
  return {
    totalPosts,
    classifiedPosts,
    unclassifiedPosts,
    avgClassificationsPerPost,
    avgConfidence,
    signalCounts,
    interestPostCounts
  };
}
```

---

## API Endpoints to Build

### `GET /api/admin/classifications`
- Query params: `?interestId=X&minConfidence=0.7&unclassifiedOnly=true`
- Returns: Array of post classifications

### `GET /api/admin/classifications/:postId`
- Returns: Single post classification

### `POST /api/admin/classifications/:postId/interests`
- Body: `{ interestId: string, confidence: number }`
- Returns: Updated classification

### `DELETE /api/admin/classifications/:postId/interests/:interestId`
- Returns: Updated classification

### `POST /api/admin/classifications/:postId/reclassify`
- Returns: New classification result

### `POST /api/admin/classifications/bulk/classify`
- Body: `{ batchSize: number }`
- Returns: Progress updates (SSE or polling)

### `POST /api/admin/classifications/bulk/reclassify`
- Body: `{ interestId?: string, postIds?: string[] }`
- Returns: Progress updates

### `GET /api/admin/classifications/analytics`
- Returns: Analytics dashboard data

### `GET /api/admin/classifications/quality/low-confidence`
- Query: `?threshold=0.5`
- Returns: Posts with low confidence classifications

---

## Integration Notes

### iOS App Classification Flow

1. User creates post with caption and tags
2. Post is uploaded to Firestore
3. **Cloud Function triggered**: `onPostCreate`
4. Function calls classification algorithm
5. Classification result saved to `post_classifications/{postId}`
6. Post document updated with `interestIds`, `primaryInterestId`, `interestScores`
7. Interest post counts incremented

### Admin Dashboard Classification Flow

1. Admin views unclassified posts
2. Clicks "Classify All"
3. Dashboard calls Cloud Function for each post
4. Progress bar shows real-time updates
5. Results displayed with success/error counts

---

## Testing Checklist

- [ ] View all classified posts
- [ ] Filter by interest
- [ ] Filter by confidence threshold
- [ ] View classification details for single post
- [ ] Manually add interest to post
- [ ] Manually remove interest from post
- [ ] Set primary interest
- [ ] Reclassify single post
- [ ] Bulk classify unclassified posts
- [ ] View analytics dashboard
- [ ] Review low confidence classifications
- [ ] Check interest post counts update correctly

---

## Next Phase: Taste Graph

The next admin dashboard update will include:
- User taste graph viewer
- Interest follow management
- User interest affinity analytics
- Recommended interests for users

This will be provided after Phase 3 implementation.
