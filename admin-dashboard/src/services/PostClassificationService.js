import api from './api';

export default {
    getClassifications(params) {
        return api.get('/api/admin/classifications', { params });
    },
    getClassification(postId) {
        return api.get(`/api/admin/classifications/${postId}`);
    },
    addInterest(postId, data) {
        return api.post(`/api/admin/classifications/${postId}/interests`, data);
    },
    removeInterest(postId, interestId) {
        return api.delete(`/api/admin/classifications/${postId}/interests/${interestId}`);
    },
    reclassifyPost(postId) {
        return api.post(`/api/admin/classifications/${postId}/reclassify`);
    },
    bulkClassify(data) {
        return api.post('/api/admin/classifications/bulk/classify', data);
    },
    bulkReclassify(data) {
        return api.post('/api/admin/classifications/bulk/reclassify', data);
    },
    getAnalytics() {
        return api.get('/api/admin/classifications/analytics');
    },
    getLowConfidencePosts(params) {
        return api.get('/api/admin/classifications/quality/low-confidence', { params });
    }
};
