<template>
  <div class="min-h-screen bg-gray-50">
    <AppHeader />
    
    <!-- Main content area for interest taxonomy management -->
    <main class="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
      <div class="px-4 py-6 sm:px-0">
        <!-- Header with title and action buttons -->
        <div class="flex items-center justify-between mb-6">
          <h2 class="text-2xl font-bold text-gray-900">Interest Taxonomy</h2>
          <div class="flex gap-2">
            <!-- Seed Base Interests Button -->
            <!-- Only runs once to initialize 10 base categories -->
            <!-- Disabled while loading or seeding to prevent duplicate requests -->
            <button
              @click="seedInterests"
              :disabled="loading || seedingInterests"
              class="px-4 py-2 text-sm bg-green-600 text-white rounded-md hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {{ seedingInterests ? 'Seeding...' : 'Seed Base Interests' }}
            </button>
            <!-- Create New Interest Button -->
            <!-- Opens modal for creating root-level interests -->
            <button
              @click="openCreateModal(null)"
              :disabled="loading"
              class="px-4 py-2 text-sm bg-indigo-600 text-white rounded-md hover:bg-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
              </svg>
              Create Interest
            </button>
          </div>
        </div>

        <!-- Error Alert Banner -->
        <!-- Displays API or validation errors to the user -->
        <div v-if="error" class="mb-4 p-4 bg-red-50 border border-red-200 rounded-lg">
          <p class="text-red-800">{{ error }}</p>
        </div>

        <!-- Success Message Banner -->
        <!-- Displays confirmation messages and auto-dismisses after 3 seconds -->
        <div v-if="successMessage" class="mb-4 p-4 bg-green-50 border border-green-200 rounded-lg">
          <p class="text-green-800">{{ successMessage }}</p>
        </div>

        <!-- Loading State -->
        <!-- Shows while fetching interests from API -->
        <div v-if="loading" class="text-center py-12">
          <p class="text-gray-500">Loading interests...</p>
        </div>

        <!-- Main Content Area -->
        <div v-else>
          <!-- Interest Tree View Container -->
          <div class="bg-white shadow rounded-lg overflow-hidden">
            <!-- Empty State -->
            <!-- Prompts user to seed base interests when collection is empty -->
            <div v-if="interests.length === 0" class="p-6 text-center text-gray-500">
              <p>No interests found. Click "Seed Base Interests" to start.</p>
            </div>
            <!-- Tree View with Recursive Components -->
            <!-- InterestItem is recursive and displays children via @add-child emitter -->
            <!-- Each interest can be edited, deleted, or have children added -->
            <div v-else class="bg-white rounded-lg border border-gray-200 overflow-hidden divide-y divide-gray-100">
              <InterestItem
                v-for="interest in interests"
                :key="interest.id"
                :interest="interest"
                @edit="handleEdit"
                @delete="handleDelete"
                @add-child="handleCreateChild"
              />
            </div>
          </div>
        </div>
      </div>
    </main>

    <!-- Create Interest Modal -->
    <!-- Modal overlay for creating new interests -->
    <!-- Can be used for both root interests and sub-interests (parent pre-selected via @add-child) -->
    <!-- Create Interest Modal -->
    <InterestCreateModal
      :is-open="showCreateModal"
      :parent-id="createParentId"
      @close="showCreateModal = false"
      @created="handleInterestCreated"
    />

    <!-- Edit Interest Modal -->
    <div v-if="showEditModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
      <div class="bg-white rounded-lg shadow-lg max-w-md w-full p-6">
        <h3 class="text-lg font-semibold text-gray-900 mb-4">Edit Interest</h3>
        
        <form @submit.prevent="submitEditInterest" class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Display Name</label>
            <input
              v-model="editingInterest.displayName"
              type="text"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500"
              required
            />
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Description</label>
            <textarea
              v-model="editingInterest.description"
              rows="3"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500"
            ></textarea>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Keywords (comma-separated)</label>
            <input
              v-model="editingKeywordsInput"
              type="text"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
          </div>

          <div class="flex items-center gap-2">
            <input
              v-model="editingInterest.isActive"
              type="checkbox"
              id="isActive"
              class="w-4 h-4 text-indigo-600 border-gray-300 rounded"
            />
            <label for="isActive" class="text-sm text-gray-700">Active</label>
          </div>

          <div class="flex gap-3 pt-4">
            <button
              type="button"
              @click="showEditModal = false"
              class="flex-1 px-4 py-2 text-gray-700 border border-gray-300 rounded-md hover:bg-gray-50"
            >
              Cancel
            </button>
            <button
              type="submit"
              :disabled="updatingInterest"
              class="flex-1 px-4 py-2 bg-indigo-600 text-white rounded-md hover:bg-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {{ updatingInterest ? 'Updating...' : 'Update' }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>

<script setup>
/**
 * Interests Management Page Component
 *
 * Provides admin interface for managing the interest taxonomy:
 *   - View tree structure of interests
 *   - Create new interests (root or sub-interests)
 *   - Edit interest metadata
 *   - Delete/deactivate interests
 *   - Seed base interests
 *
 * See docs/architecture/INTERESTS_SYSTEM.md for system documentation
 */

import { ref, onMounted } from 'vue';
import AppHeader from '../components/AppHeader.vue';
import InterestItem from '../components/InterestItem.vue';
import InterestCreateModal from '../components/InterestCreateModal.vue';
import { useInterestService } from '../composables/interestService';

// Destructure API methods from composable
const { getInterestTree, updateInterest, deleteInterest, seedInterests: seedFromAPI } = useInterestService();

// Root interests state - loaded on mount
const interests = ref([]);
// Loading state for initial data fetch
const loading = ref(true);
// Error message display
const error = ref(null);
// Success message with auto-dismiss
const successMessage = ref(null);

// Create modal state and form data
const showCreateModal = ref(false);
const createParentId = ref(null);

// Edit modal state and form data
const showEditModal = ref(false);
const updatingInterest = ref(false);
const editingInterest = ref(null);
const editingKeywordsInput = ref('');

// Seed operation state
const seedingInterests = ref(false);

// Load root interests on component mount
onMounted(async () => {
  await loadInterests();
});

/**
 * Load root interests from API
 * Fetches all top-level (parentId == null) interests
 * Recursive components handle loading children
 */
async function loadInterests() {
  loading.value = true;
  try {
    error.value = null;
    const response = await getInterestTree();
    interests.value = response;
  } catch (err) {
    error.value = 'Failed to load interests';
    console.error('Error loading interests:', err);
  } finally {
    loading.value = false;
  }
}

function openCreateModal(parentId) {
  createParentId.value = parentId;
  showCreateModal.value = true;
}

function handleInterestCreated(interest) {
  successMessage.value = `Interest "${interest.displayName}" created successfully!`;
  showCreateModal.value = false;
  loadInterests();
  setTimeout(() => {
    successMessage.value = null;
  }, 3000);
}

/**
 * Prepare interest for editing
 * Opens edit modal with current interest data
 * Converts keywords array to comma-separated string for form display
 */
function handleEdit(interest) {
  editingInterest.value = { ...interest };  // Shallow copy to avoid direct mutations
  editingKeywordsInput.value = (interest.keywords || []).join(', ');  // Format for display
  showEditModal.value = true;
}

/**
 * Edit Interest Form Submission
 * Updates interest metadata (displayName, description, keywords, isActive)
 * Cannot change structural fields (id, parentId, level, path)
 */
async function submitEditInterest() {
  try {
    updatingInterest.value = true;
    error.value = null;

    // Parse comma-separated keywords into array
    const keywords = editingKeywordsInput.value
      .split(',')
      .map(k => k.trim())
      .filter(k => k);

    // Send partial update to API
    await updateInterest(editingInterest.value.id, {
      displayName: editingInterest.value.displayName,
      description: editingInterest.value.description,
      keywords,
      isActive: editingInterest.value.isActive  // Can activate/deactivate here
    });

    // Show success and close modal
    successMessage.value = 'Interest updated successfully!';
    showEditModal.value = false;
    // Reload interests to reflect updates
    await loadInterests();
    // Auto-dismiss success message
    setTimeout(() => { successMessage.value = null; }, 3000);
  } catch (err) {
    error.value = err.response?.data?.message || err.message || 'Failed to update interest';
    console.error('Error updating interest:', err);
  } finally {
    updatingInterest.value = false;
  }
}

/**
 * Delete (Deactivate) Interest
 * Soft delete via API (sets isActive = false)
 * Requires user confirmation to prevent accidental deletion
 */
async function handleDelete(id) {
  // Show confirmation dialog
  if (!confirm('Are you sure you want to delete this interest? This action cannot be undone.')) {
    return;
  }

  try {
    error.value = null;
    // API performs soft delete (deactivation)
    await deleteInterest(id);
    successMessage.value = 'Interest deleted successfully!';
    // Reload interests to reflect deletion (deactivated items hidden)
    await loadInterests();
    // Auto-dismiss success message
    setTimeout(() => { successMessage.value = null; }, 3000);
  } catch (err) {
    error.value = err.response?.data?.message || err.message || 'Failed to delete interest';
    console.error('Error deleting interest:', err);
  }
}

/**
 * Show Create Child Modal
 * Pre-selects parent interest for creating sub-interests
 * Called via @add-child event from InterestItem component
 */
function handleCreateChild(parentInterest) {
  openCreateModal(parentInterest.id);
}

/**
 * Seed Base Interests
 * Initializes taxonomy with 10 base categories
 * Only runs once (API returns error if already seeded)
 * Requires confirmation due to irreversibility
 */
async function seedInterests() {
  // Show confirmation dialog
  if (!confirm('This will seed the base interests. Continue?')) {
    return;
  }

  try {
    seedingInterests.value = true;
    error.value = null;
    // Call seeding API endpoint
    await seedFromAPI();
    successMessage.value = 'Base interests seeded successfully!';
    // Reload interests to display newly seeded categories
    await loadInterests();
    // Auto-dismiss success message
    setTimeout(() => { successMessage.value = null; }, 3000);
  } catch (err) {
    error.value = err.response?.data?.message || err.message || 'Failed to seed interests';
    console.error('Error seeding interests:', err);
  } finally {
    seedingInterests.value = false;
  }
}
</script>
