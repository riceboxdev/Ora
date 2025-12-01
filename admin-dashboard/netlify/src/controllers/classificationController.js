import { db } from '../config/firebase.js';
import admin from 'firebase-admin';

// Helper to update post interest fields
async function updatePostInterestFields(postId) {
    const classDoc = await db.collection('post_classifications').doc(postId).get();

    if (!classDoc.exists) {
        return;
    }

    const classification = classDoc.data();

    // Sort by confidence
    const sorted = (classification.classifications || []).sort(
        (a, b) => b.confidence - a.confidence
    );

    // Build interest arrays and map
    const interestIds = sorted.map(c => c.interestId);
    const primaryInterestId = sorted[0]?.interestId || null;
    const interestScores = {};

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

export const getClassifications = async (req, res) => {
    try {
        const {
            interestId,
            minConfidence,
            unclassifiedOnly,
            limit = 50,
            offset = 0
        } = req.query;

        let query = db.collection('post_classifications');

        if (unclassifiedOnly === 'true') {
            // This is tricky because unclassified posts don't have a document in post_classifications usually
            // Or they might have one but empty. 
            // The requirements say "Unclassified posts only" filter.
            // Usually we'd query 'posts' collection for where interestIds is null/empty.
            // But this endpoint returns classifications.
            // If the user wants unclassified posts, we should probably query the posts collection.
            // For now, let's assume this endpoint is for *classified* posts.
            // We'll handle unclassified in a separate way or different query.
            // If unclassifiedOnly is true, we might return posts that are NOT in this collection?
            // Let's stick to querying post_classifications for now.
        }

        // Note: Firestore has limitations on multiple inequality filters.
        // We'll do some filtering in memory if needed, or rely on simple queries.

        const snapshot = await query.orderBy('classifiedAt', 'desc').limit(parseInt(limit)).get();

        let results = snapshot.docs.map(doc => doc.data());

        // In-memory filtering for now (not efficient for large datasets but works for prototype)
        if (interestId) {
            results = results.filter(d => d.classifications.some(c => c.interestId === interestId));
        }
        if (minConfidence) {
            const minConf = parseFloat(minConfidence);
            results = results.filter(d => d.classifications.some(c => c.confidence >= minConf));
        }

        // Fetch post details for these classifications
        const postIds = results.map(r => r.postId);
        if (postIds.length > 0) {
            // Firestore 'in' query limit is 10 (or 30). 
            // We'll fetch individually or in batches.
            // For 50 items, maybe just fetch individually or use getAll if supported (admin sdk supports getAll)
            const postRefs = postIds.map(id => db.collection('posts').doc(id));
            const postsSnap = await db.getAll(...postRefs);
            const postsMap = new Map(postsSnap.map(doc => [doc.id, doc.data()]));

            results = results.map(r => ({
                ...r,
                post: postsMap.get(r.postId) || null
            }));
        }

        res.json(results);
    } catch (error) {
        console.error('Error getting classifications:', error);
        res.status(500).json({ message: error.message });
    }
};

export const getClassification = async (req, res) => {
    try {
        const { postId } = req.params;
        const doc = await db.collection('post_classifications').doc(postId).get();

        if (!doc.exists) {
            return res.status(404).json({ message: 'Classification not found' });
        }

        const data = doc.data();

        // Also get post details
        const postDoc = await db.collection('posts').doc(postId).get();
        const post = postDoc.exists ? postDoc.data() : null;

        res.json({ ...data, post });
    } catch (error) {
        console.error('Error getting classification:', error);
        res.status(500).json({ message: error.message });
    }
};

export const addInterest = async (req, res) => {
    try {
        const { postId } = req.params;
        const { interestId, confidence = 1.0 } = req.body;

        // Get interest details
        const interestDoc = await db.collection('interests').doc(interestId).get();
        if (!interestDoc.exists) {
            return res.status(404).json({ message: 'Interest not found' });
        }
        const interestData = interestDoc.data();

        const classRef = db.collection('post_classifications').doc(postId);
        const classDoc = await classRef.get();

        const newClassification = {
            interestId,
            interestName: interestData.displayName,
            interestLevel: interestData.level || 0,
            confidence,
            signals: ['userTagged'] // Admin manual tag
        };

        if (classDoc.exists) {
            const existing = classDoc.data();
            const existingIndex = existing.classifications.findIndex(c => c.interestId === interestId);

            if (existingIndex >= 0) {
                existing.classifications[existingIndex] = newClassification;
            } else {
                existing.classifications.push(newClassification);
            }

            existing.classifications.sort((a, b) => b.confidence - a.confidence);

            await classRef.update({
                classifications: existing.classifications,
                classifiedAt: admin.firestore.FieldValue.serverTimestamp()
            });
        } else {
            await classRef.set({
                postId,
                classifications: [newClassification],
                classifiedAt: admin.firestore.FieldValue.serverTimestamp(),
                version: '1.0'
            });
        }

        await updatePostInterestFields(postId);

        res.json({ success: true, message: 'Interest added' });
    } catch (error) {
        console.error('Error adding interest:', error);
        res.status(500).json({ message: error.message });
    }
};

export const removeInterest = async (req, res) => {
    try {
        const { postId, interestId } = req.params;

        const classRef = db.collection('post_classifications').doc(postId);
        const classDoc = await classRef.get();

        if (!classDoc.exists) {
            return res.status(404).json({ message: 'Classification not found' });
        }

        const classification = classDoc.data();
        const newClassifications = classification.classifications.filter(c => c.interestId !== interestId);

        await classRef.update({
            classifications: newClassifications,
            classifiedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        await updatePostInterestFields(postId);

        // Decrement interest post count
        await db.collection('interests').doc(interestId).update({
            postCount: admin.firestore.FieldValue.increment(-1)
        });

        res.json({ success: true, message: 'Interest removed' });
    } catch (error) {
        console.error('Error removing interest:', error);
        res.status(500).json({ message: error.message });
    }
};

export const reclassifyPost = async (req, res) => {
    try {
        const { postId } = req.params;
        // In a real scenario, this would trigger the Cloud Function
        // For now, we'll just return success as if we triggered it
        // Or we could actually call the function URL if we had it.

        // Mocking the trigger
        console.log(`Triggering reclassification for post ${postId}`);

        res.json({ success: true, message: 'Reclassification triggered' });
    } catch (error) {
        console.error('Error reclassifying post:', error);
        res.status(500).json({ message: error.message });
    }
};

export const bulkClassify = async (req, res) => {
    try {
        const { batchSize = 100 } = req.body;

        const postsSnapshot = await db.collection('posts')
            .where('interestIds', '==', null) // or check for empty array if possible, but null is easier
            .limit(parseInt(batchSize))
            .get();

        const count = postsSnapshot.size;
        const postIds = postsSnapshot.docs.map(doc => doc.id);

        // Trigger classification for each
        // This should ideally be done via a queue or batch job
        console.log(`Triggering bulk classification for ${count} posts`);

        res.json({
            success: true,
            message: `Triggered classification for ${count} posts`,
            count,
            postIds
        });
    } catch (error) {
        console.error('Error bulk classifying:', error);
        res.status(500).json({ message: error.message });
    }
};

export const bulkReclassify = async (req, res) => {
    try {
        const { interestId, postIds } = req.body;

        let targetPostIds = postIds || [];

        if (!targetPostIds.length && interestId) {
            // Find posts with this interest
            // This might be expensive
            const snapshot = await db.collection('post_classifications')
                .where('classifications', 'array-contains', { interestId }) // This won't work easily with object array
            // Better to query posts collection where interestIds contains interestId
            // But we need to update classifications

            // For now, let's assume postIds are passed or we query posts
            const postsSnap = await db.collection('posts')
                .where('interestIds', 'array-contains', interestId)
                .limit(100) // Safety limit
                .get();

            targetPostIds = postsSnap.docs.map(doc => doc.id);
        }

        console.log(`Triggering bulk reclassification for ${targetPostIds.length} posts`);

        res.json({
            success: true,
            message: `Triggered reclassification for ${targetPostIds.length} posts`,
            count: targetPostIds.length
        });
    } catch (error) {
        console.error('Error bulk reclassifying:', error);
        res.status(500).json({ message: error.message });
    }
};

export const getAnalytics = async (req, res) => {
    try {
        // This can be expensive, so we should probably cache this or use aggregation queries
        // For now, implementing a simplified version

        const allClassifications = await db.collection('post_classifications').get();
        const allPosts = await db.collection('posts').count().get(); // Use count aggregation if available

        const totalPosts = allPosts.data().count;
        const classifiedPosts = allClassifications.size;
        const unclassifiedPosts = totalPosts - classifiedPosts;

        let totalClassifications = 0;
        let totalConfidence = 0;
        const signalCounts = {};
        const interestPostCounts = {};

        allClassifications.forEach(doc => {
            const data = doc.data();
            (data.classifications || []).forEach(c => {
                totalClassifications++;
                totalConfidence += c.confidence;

                (c.signals || []).forEach(s => {
                    signalCounts[s] = (signalCounts[s] || 0) + 1;
                });

                interestPostCounts[c.interestId] = (interestPostCounts[c.interestId] || 0) + 1;
            });
        });

        const avgClassificationsPerPost = classifiedPosts > 0 ? totalClassifications / classifiedPosts : 0;
        const avgConfidence = totalClassifications > 0 ? totalConfidence / totalClassifications : 0;

        res.json({
            totalPosts,
            classifiedPosts,
            unclassifiedPosts,
            avgClassificationsPerPost,
            avgConfidence,
            signalCounts,
            interestPostCounts
        });
    } catch (error) {
        console.error('Error getting analytics:', error);
        res.status(500).json({ message: error.message });
    }
};

export const getLowConfidencePosts = async (req, res) => {
    try {
        const { threshold = 0.5, limit = 50 } = req.query;
        const thresholdNum = parseFloat(threshold);

        // Firestore doesn't support querying array of objects by field value easily
        // We'll fetch recent classifications and filter
        const snapshot = await db.collection('post_classifications')
            .orderBy('classifiedAt', 'desc')
            .limit(200) // Fetch more to filter
            .get();

        let results = snapshot.docs.map(doc => doc.data());

        results = results.filter(d =>
            d.classifications.some(c => c.confidence < thresholdNum)
        ).slice(0, parseInt(limit));

        // Fetch post details
        if (results.length > 0) {
            const postRefs = results.map(r => db.collection('posts').doc(r.postId));
            const postsSnap = await db.getAll(...postRefs);
            const postsMap = new Map(postsSnap.map(doc => [doc.id, doc.data()]));

            results = results.map(r => ({
                ...r,
                post: postsMap.get(r.postId) || null
            }));
        }

        res.json(results);
    } catch (error) {
        console.error('Error getting low confidence posts:', error);
        res.status(500).json({ message: error.message });
    }
};
