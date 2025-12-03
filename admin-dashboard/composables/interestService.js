import api from './api';

export function useInterestService() {
  /**
   * Get all root interests or filtered interests
   */
  async function getInterests(parentId = null, level = null) {
    const params = new URLSearchParams();
    if (parentId) params.append('parentId', parentId);
    if (level) params.append('level', level);
    
    const response = await api.get(`/api/admin/interests${params.toString() ? '?' + params.toString() : ''}`);
    return response.data.interests || [];
  }

  /**
   * Get complete interest taxonomy tree
   */
  async function getInterestTree(maxDepth = null) {
    const params = new URLSearchParams();
    if (maxDepth) params.append('maxDepth', maxDepth);
    
    const response = await api.get(`/api/admin/interests/tree${params.toString() ? '?' + params.toString() : ''}`);
    return response.data.tree || [];
  }

  /**
   * Create new interest
   */
  async function createInterest(data) {
    const { name, displayName, parentId, description, keywords, synonyms } = data;
    
    const response = await api.post('/api/admin/interests', {
      name,
      displayName,
      parentId: parentId || null,
      description: description || null,
      keywords: keywords || [],
      synonyms: synonyms || []
    });
    
    return response.data.interest;
  }

  /**
   * Update interest
   */
  async function updateInterest(id, data) {
    const { displayName, description, keywords, synonyms, isActive } = data;
    
    const response = await api.put(`/api/admin/interests/${id}`, {
      displayName,
      description,
      keywords,
      synonyms,
      isActive
    });
    
    return response.data;
  }

  /**
   * Delete (deactivate) interest
   */
  async function deleteInterest(id) {
    const response = await api.delete(`/api/admin/interests/${id}`);
    return response.data;
  }

  /**
   * Seed initial interest taxonomy
   */
  async function seedInterests() {
    const response = await api.post('/api/admin/interests/seed');
    return response.data;
  }

  return {
    getInterests,
    getInterestTree,
    createInterest,
    updateInterest,
    deleteInterest,
    seedInterests
  };
}
