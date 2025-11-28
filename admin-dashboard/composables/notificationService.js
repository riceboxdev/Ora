import api from './api';

export const notificationService = {
  // Create promotional notification
  async createPromotionalNotification(data) {
    const response = await api.post('/api/admin/notifications', data);
    return response.data;
  },

  // Get all promotional notifications
  async getPromotionalNotifications() {
    const response = await api.get('/api/admin/notifications');
    return response.data;
  },

  // Get notification details
  async getNotificationDetails(notificationId) {
    const response = await api.get(`/api/admin/notifications/${notificationId}`);
    return response.data;
  },

  // Send a draft notification
  async sendNotification(notificationId) {
    const response = await api.post(`/api/admin/notifications/${notificationId}/send`);
    return response.data;
  }
};

