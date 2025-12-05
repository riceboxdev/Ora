import { db } from '../composables/firebase';
import { collection, getDocs, doc, updateDoc, query, where } from 'firebase/firestore';

/**
 * Recalculate post counts for all interests
 * Returns an object with results for each interest
 */
export async function recalculateInterestPostCounts() {
    const results = {
        processed: 0,
        updated: 0,
        errors: [],
        details: []
    };

    try {
        // Get all interests
        const interestsSnapshot = await getDocs(collection(db, 'interests'));
        const interests = [];

        interestsSnapshot.forEach(doc => {
            interests.push({ id: doc.id, ...doc.data() });
        });

        console.log(`📊 Found ${interests.length} interests to process`);

        // Get all posts
        const postsSnapshot = await getDocs(collection(db, 'posts'));
        const posts = [];

        postsSnapshot.forEach(doc => {
            const data = doc.data();
            if (!data.isDeleted) {
                posts.push({ id: doc.id, ...data });
            }
        });

        console.log(`📝 Found ${posts.length} active posts`);

        // Calculate counts for each interest
        for (const interest of interests) {
            try {
                const oldCount = interest.postCount || 0;

                // Count posts that have this interest ID
                const actualCount = posts.filter(post => {
                    const interestIds = post.interestIds || [];
                    return interestIds.includes(interest.id);
                }).length;

                // Find most recent post for this interest
                const interestPosts = posts.filter(post => {
                    const interestIds = post.interestIds || [];
                    return interestIds.includes(interest.id);
                });

                let lastPostAt = null;
                if (interestPosts.length > 0) {
                    // Find most recent createdAt
                    const sortedPosts = interestPosts.sort((a, b) => {
                        const aTime = a.createdAt?.toMillis?.() || 0;
                        const bTime = b.createdAt?.toMillis?.() || 0;
                        return bTime - aTime;
                    });
                    lastPostAt = sortedPosts[0].createdAt;
                }

                // Update interest if count changed
                if (oldCount !== actualCount) {
                    const interestRef = doc(db, 'interests', interest.id);
                    const updateData = {
                        postCount: actualCount,
                        updatedAt: new Date()
                    };

                    if (lastPostAt) {
                        updateData.lastPostAt = lastPostAt;
                    }

                    await updateDoc(interestRef, updateData);
                    results.updated++;

                    results.details.push({
                        id: interest.id,
                        name: interest.displayName || interest.name,
                        oldCount,
                        newCount: actualCount,
                        updated: true
                    });
                } else {
                    results.details.push({
                        id: interest.id,
                        name: interest.displayName || interest.name,
                        oldCount,
                        newCount: actualCount,
                        updated: false
                    });
                }

                results.processed++;
            } catch (error) {
                console.error(`❌ Error processing interest ${interest.id}:`, error);
                results.errors.push({
                    interestId: interest.id,
                    error: error.message
                });
            }
        }

        console.log(`✅ Sync complete: ${results.updated}/${results.processed} interests updated`);
        return results;
    } catch (error) {
        console.error('❌ Fatal error during sync:', error);
        throw error;
    }
}
