import api from './api';

const interestService = {
  // Seed the interest taxonomy with default categories
  async seedTaxonomy() {
    try {
      const response = await api.post('/api/admin/interests/seed');
      return response.data;
    } catch (error) {
      console.error('Error seeding taxonomy:', error);
      throw error;
    }
  },

  // Get all interests
  async getInterests() {
    try {
      const response = await api.get('/api/admin/interests');
      return response.data;
    } catch (error) {
      console.error('Error fetching interests:', error);
      throw error;
    }
  },

  // Create a new interest
  async createInterest(interestData) {
    try {
      const response = await api.post('/api/admin/interests', interestData);
      return response.data;
    } catch (error) {
      console.error('Error creating interest:', error);
      throw error;
    }
  },

  // Update an existing interest
  async updateInterest(id, interestData) {
    try {
      const response = await api.put(`/api/admin/interests/${id}`, interestData);
      return response.data;
    } catch (error) {
      console.error('Error updating interest:', error);
      throw error;
    }
  },

  // Delete an interest
  async deleteInterest(id) {
    try {
      const response = await api.delete(`/api/admin/interests/${id}`);
      return response.data;
    } catch (error) {
      console.error('Error deleting interest:', error);
      throw error;
    }
  },

  // Export taxonomy
  async exportTaxonomy() {
    try {
      const response = await api.get('/api/admin/interests/export');
      return response.data;
    } catch (error) {
      console.error('Error exporting taxonomy:', error);
      throw error;
    }
  }
};

export default interestService;
