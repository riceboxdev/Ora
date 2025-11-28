import api from './api';

export const announcementService = {
  // Create announcement
  async createAnnouncement(data) {
    const response = await api.post('/api/admin/announcements', data);
    return response.data;
  },

  // Get all announcements
  async getAnnouncements(status = null) {
    const params = status ? { status } : {};
    const response = await api.get('/api/admin/announcements', { params });
    return response.data;
  },

  // Get announcement details
  async getAnnouncementDetails(announcementId) {
    const response = await api.get(`/api/admin/announcements/${announcementId}`);
    return response.data;
  },

  // Update announcement
  async updateAnnouncement(announcementId, data) {
    const response = await api.put(`/api/admin/announcements/${announcementId}`, data);
    return response.data;
  },

  // Delete/archive announcement
  async deleteAnnouncement(announcementId) {
    const response = await api.delete(`/api/admin/announcements/${announcementId}`);
    return response.data;
  },

  // Get announcement statistics
  async getAnnouncementStats(announcementId) {
    const response = await api.get(`/api/admin/announcements/${announcementId}/stats`);
    return response.data;
  }
};



