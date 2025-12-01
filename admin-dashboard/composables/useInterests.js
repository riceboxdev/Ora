import { ref } from 'vue';
import api from './api';

export default function useInterests() {
  const loading = ref(false);
  const error = ref(null);
  const interests = ref([]);
  const totalItems = ref(0);

  // Fetch all interests with optional pagination and filters
  const fetchInterests = async (params = {}) => {
    loading.value = true;
    error.value = null;
    
    try {
      const response = await api.get('/interests', { params });
      interests.value = response.data.data || response.data;
      totalItems.value = response.data.total || interests.value.length;
      return response.data;
    } catch (err) {
      error.value = err.response?.data?.message || 'Failed to fetch interests';
      console.error('Error fetching interests:', err);
      throw err;
    } finally {
      loading.value = false;
    }
  };

  // Create a new interest
  const createInterest = async (interestData) => {
    loading.value = true;
    error.value = null;
    
    try {
      const response = await api.post('/interests', interestData);
      return response.data;
    } catch (err) {
      error.value = err.response?.data?.message || 'Failed to create interest';
      console.error('Error creating interest:', err);
      throw err;
    } finally {
      loading.value = false;
    }
  };

  // Update an existing interest
  const updateInterest = async (id, updates) => {
    loading.value = true;
    error.value = null;
    
    try {
      const response = await api.patch(`/interests/${id}`, updates);
      return response.data;
    } catch (err) {
      error.value = err.response?.data?.message || 'Failed to update interest';
      console.error(`Error updating interest ${id}:`, err);
      throw err;
    } finally {
      loading.value = false;
    }
  };

  // Delete an interest
  const deleteInterest = async (id) => {
    loading.value = true;
    error.value = null;
    
    try {
      await api.delete(`/interests/${id}`);
      return true;
    } catch (err) {
      error.value = err.response?.data?.message || 'Failed to delete interest';
      console.error(`Error deleting interest ${id}:`, err);
      throw err;
    } finally {
      loading.value = false;
    }
  };

  // Move an interest to a new parent
  const moveInterest = async (id, newParentId) => {
    loading.value = true;
    error.value = null;
    
    try {
      const response = await api.post(`/interests/${id}/move`, { parentId: newParentId });
      return response.data;
    } catch (err) {
      error.value = err.response?.data?.message || 'Failed to move interest';
      console.error(`Error moving interest ${id}:`, err);
      throw err;
    } finally {
      loading.value = false;
    }
  };

  // Export interests to CSV
  const exportInterests = async () => {
    loading.value = true;
    error.value = null;
    
    try {
      const response = await api.get('/interests/export', {
        responseType: 'blob',
      });
      return response.data;
    } catch (err) {
      error.value = err.response?.data?.message || 'Failed to export interests';
      console.error('Error exporting interests:', err);
      throw err;
    } finally {
      loading.value = false;
    }
  };

  // Import interests from CSV file
  const importInterests = async (file, options = {}) => {
    loading.value = true;
    error.value = null;
    
    try {
      const formData = new FormData();
      formData.append('file', file);
      
      if (options.dryRun) {
        formData.append('dryRun', 'true');
      }
      
      const response = await api.post('/interests/import', formData, {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      });
      
      return response.data;
    } catch (err) {
      error.value = err.response?.data?.message || 'Failed to import interests';
      console.error('Error importing interests:', err);
      throw err;
    } finally {
      loading.value = false;
    }
  };

  return {
    loading,
    error,
    interests,
    totalItems,
    fetchInterests,
    createInterest,
    updateInterest,
    deleteInterest,
    moveInterest,
    exportInterests,
    importInterests,
  };
}
