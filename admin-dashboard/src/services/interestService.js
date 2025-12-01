import api from './api';

const INTERESTS_ENDPOINT = '/interests';

/**
 * Fetch all interests with optional pagination and filters
 * @param {Object} params - Query parameters (page, limit, search, etc.)
 * @returns {Promise<Array>} - List of interests
 */
export const getInterests = async (params = {}) => {
  try {
    const response = await api.get(INTERESTS_ENDPOINT, { params });
    return response.data;
  } catch (error) {
    console.error('Error fetching interests:', error);
    throw error;
  }
};

/**
 * Fetch a single interest by ID
 * @param {string} id - Interest ID
 * @returns {Promise<Object>} - Interest details
 */
export const getInterestById = async (id) => {
  try {
    const response = await api.get(`${INTERESTS_ENDPOINT}/${id}`);
    return response.data;
  } catch (error) {
    console.error(`Error fetching interest ${id}:`, error);
    throw error;
  }
};

/**
 * Create a new interest
 * @param {Object} interestData - New interest data
 * @returns {Promise<Object>} - Created interest
 */
export const createInterest = async (interestData) => {
  try {
    const response = await api.post(INTERESTS_ENDPOINT, interestData);
    return response.data;
  } catch (error) {
    console.error('Error creating interest:', error);
    throw error;
  }
};

/**
 * Update an existing interest
 * @param {string} id - Interest ID
 * @param {Object} updates - Fields to update
 * @returns {Promise<Object>} - Updated interest
 */
export const updateInterest = async (id, updates) => {
  try {
    const response = await api.patch(`${INTERESTS_ENDPOINT}/${id}`, updates);
    return response.data;
  } catch (error) {
    console.error(`Error updating interest ${id}:`, error);
    throw error;
  }
};

/**
 * Delete an interest
 * @param {string} id - Interest ID
 * @returns {Promise<void>}
 */
export const deleteInterest = async (id) => {
  try {
    await api.delete(`${INTERESTS_ENDPOINT}/${id}`);
  } catch (error) {
    console.error(`Error deleting interest ${id}:`, error);
    throw error;
  }
};

/**
 * Move an interest to a new parent
 * @param {string} id - Interest ID to move
 * @param {string|null} newParentId - New parent ID (null for root)
 * @returns {Promise<Object>} - Updated interest
 */
export const moveInterest = async (id, newParentId) => {
  try {
    const response = await api.post(`${INTERESTS_ENDPOINT}/${id}/move`, { parentId: newParentId });
    return response.data;
  } catch (error) {
    console.error(`Error moving interest ${id}:`, error);
    throw error;
  }
};

/**
 * Export interests to CSV
 * @returns {Promise<Blob>} - CSV file as Blob
 */
export const exportInterests = async () => {
  try {
    const response = await api.get(`${INTERESTS_ENDPOINT}/export`, {
      responseType: 'blob',
    });
    return response.data;
  } catch (error) {
    console.error('Error exporting interests:', error);
    throw error;
  }
};

/**
 * Import interests from CSV file
 * @param {File} file - CSV file to import
 * @param {Object} options - Import options
 * @returns {Promise<Object>} - Import result
 */
export const importInterests = async (file, options = {}) => {
  try {
    const formData = new FormData();
    formData.append('file', file);
    
    if (options.dryRun) {
      formData.append('dryRun', 'true');
    }
    
    const response = await api.post(`${INTERESTS_ENDPOINT}/import`, formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    });
    
    return response.data;
  } catch (error) {
    console.error('Error importing interests:', error);
    throw error;
  }
};
