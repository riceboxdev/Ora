import api from './api';

/**
 * Interest Service Composable
 *
 * Provides Vue 3 composable API for managing the interests taxonomy.
 * Abstracts HTTP communication and provides typed interfaces for interest operations.
 *
 * Usage:
 *   const { getInterests, createInterest, deleteInterest } = useInterestService();
 *   const interests = await getInterests();
 *
 * All methods handle API errors and Firestore timestamp conversion.
 * See docs/architecture/INTERESTS_SYSTEM.md for system overview.
 */
export function useInterestService() {
  /**
   * Retrieve interests with optional filtering
   *
   * Default behavior returns root interests (parentId == null)
   * Useful for:
   *   - Display tree view starting points
   *   - Load sub-interests for specific parent
   *   - Filter interests by hierarchy level
   *
   * @param {string|null} parentId - Filter by parent interest ID
   * @param {number|null} level - Filter by hierarchy level
   * @returns {Promise<Array>} Array of interest objects
   *
   * Examples:
   *   getInterests() → Root interests (default)
   *   getInterests('fashion') → Children of Fashion
   *   getInterests(null, 1) → All level-1 interests
   */
  async function getInterests(parentId = null, level = null) {
    const params = new URLSearchParams();
    if (parentId) params.append('parentId', parentId);
    if (level) params.append('level', level);
    
    const response = await api.get(`/api/admin/interests${params.toString() ? '?' + params.toString() : ''}`);
    return response.data.interests || [];
  }

  /**
   * Retrieve complete interest taxonomy as hierarchical tree
   *
   * Returns entire taxonomy with nested children arrays.
   * Useful for:
   *   - Initial tree view population
   *   - Recursive component rendering
   *   - Understanding hierarchy structure
   *
   * @param {number|null} maxDepth - Limit tree depth (null = unlimited)
   * @returns {Promise<Array>} Root interests with nested children arrays
   *
   * Structure:
   *   [
   *     {
   *       id: "fashion",
   *       children: [
   *         { id: "fashion-basics", children: [] }
   *       ]
   *     }
   *   ]
   */
  async function getInterestTree(maxDepth = null) {
    const params = new URLSearchParams();
    if (maxDepth) params.append('maxDepth', maxDepth);
    
    const response = await api.get(`/api/admin/interests/tree${params.toString() ? '?' + params.toString() : ''}`);
    return response.data.tree || [];
  }

  /**
   * Create new interest in taxonomy
   *
   * Creates either root interest (no parentId) or sub-interest (with parentId).
   * Level and path are auto-calculated by backend based on parent.
   *
   * @param {Object} data - Interest data
   * @param {string} data.name - Required. Unique internal name (will be converted to hyphenated ID)
   * @param {string} data.displayName - Required. User-facing display name
   * @param {string} data.parentId - Optional. Parent interest ID for sub-interests
   * @param {string} data.description - Optional. Detailed description
   * @param {string[]} data.keywords - Optional. Searchable keywords
   * @param {string[]} data.synonyms - Optional. Alternative names
   * @returns {Promise<Object>} Created interest with id, level, and path
   *
   * Throws: Error if parent not found or validation fails
   */
  async function createInterest(data) {
    const { name, displayName, parentId, description, keywords, synonyms } = data;
    
    const response = await api.post('/api/admin/interests', {
      name,
      displayName,
      parentId: parentId || null,              // null for root interests
      description: description || null,        // Optional field
      keywords: keywords || [],                // Default to empty array
      synonyms: synonyms || []                 // Default to empty array
    });
    
    return response.data.interest;
  }

  /**
   * Update existing interest
   *
   * Supports partial updates - only provided fields are updated.
   * Cannot change: id, name, parentId, level, path (structural integrity)
   * Can change: displayName, description, keywords, synonyms, isActive
   *
   * @param {string} id - Interest ID to update
   * @param {Object} data - Fields to update (all optional)
   * @param {string} data.displayName - User-facing name
   * @param {string} data.description - Description text
   * @param {string[]} data.keywords - Searchable keywords
   * @param {string[]} data.synonyms - Alternative names
   * @param {boolean} data.isActive - Active/inactive status
   * @returns {Promise<Object>} Success response
   *
   * Examples:
   *   // Update display name only
   *   updateInterest('fashion', { displayName: 'Fashion & Style' })
   *
   *   // Update multiple fields
   *   updateInterest('fashion', {
   *     displayName: 'Fashion & Style',
   *     keywords: ['fashion', 'clothing', 'style'],
   *     isActive: true
   *   })
   *
   *   // Deactivate interest
   *   updateInterest('fashion', { isActive: false })
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
   * Deactivate (soft delete) interest
   *
   * Sets isActive = false without removing data.
   * Preserves all historical data for auditing.
   * Interest can be reactivated via updateInterest().
   *
   * @param {string} id - Interest ID to deactivate
   * @returns {Promise<Object>} Success response
   *
   * Note: Consider checking for child interests before deletion
   * as they remain in the hierarchy after parent deactivation
   */
  async function deleteInterest(id) {
    const response = await api.delete(`/api/admin/interests/${id}`);
    return response.data;
  }

  /**
   * Initialize taxonomy with base interests
   *
   * Seeds 10 base interest categories:
   *   Fashion, Beauty, Food & Dining, Fitness, Home & Decor,
   *   Travel, Photography, Entertainment, Technology, Pets
   *
   * Only runs once - returns error if interests already exist.
   * All seeded interests are root level (level = 0).
   *
   * @returns {Promise<Object>} Success message with count
   *
   * Throws: Error if interests already exist or API fails
   *
   * Typical usage:
   *   // Called once during setup via admin dashboard button
   *   const result = await seedInterests();
   *   console.log(`Seeded ${result.count} interests`);
   */
  async function seedInterests() {
    const response = await api.post('/api/admin/interests/seed');
    return response.data;
  }

  // Return public API
  return {
    getInterests,        // Fetch interests with optional filters
    getInterestTree,     // Fetch full taxonomy tree
    createInterest,      // Create new interest
    updateInterest,      // Update existing interest
    deleteInterest,      // Deactivate interest
    seedInterests        // Initialize with base interests
  };
}
