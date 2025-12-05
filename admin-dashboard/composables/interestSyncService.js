import api from './api';

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
        // Call the sync endpoint on the backend
        const response = await api.post('/api/admin/interests/sync-post-counts');

        // The backend should return the sync results
        if (response.data) {
            return response.data;
        }

        return results;
    } catch (error) {
        console.error('❌ Fatal error during sync:', error);
        throw error;
    }
}
