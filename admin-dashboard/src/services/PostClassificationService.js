import api from './api';

export default {
    getClassifications(params) {
        return api.get('/admin/classifications', { params });
    },
    getClassification(postId) {
        return api.get(`/admin/classifications/${postId}`);
    },
    addInterest(postId, data) {
        return api.post(`/admin/classifications/${postId}/interests`, data);
    },
    removeInterest(postId, interestId) {
        return api.delete(`/admin/classifications/${postId}/interests/${interestId}`);
    },
    reclassifyPost(postId) {
        return api.post(`/admin/classifications/${postId}/reclassify`);
    },
    bulkClassify(data) {
        return api.post('/admin/classifications/bulk/classify', data);
    },
    bulkReclassify(data) {
        return api.post('/admin/classifications/bulk/reclassify', data);
    },
    getAnalytics() {
        return api.get('/admin/classifications/analytics');
    },
    getLowConfidencePosts(params) {
        return api.get('/admin/classifications/quality/low-confidence', { params });
    }
};
