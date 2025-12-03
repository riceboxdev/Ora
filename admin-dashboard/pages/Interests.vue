<template>
  <div class="min-h-screen bg-gray-50">
    <AppHeader />
    
    <main class="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
      <div class="px-4 py-6 sm:px-0">
        <div class="flex items-center justify-between mb-6">
          <h2 class="text-2xl font-bold text-gray-900">Interest Taxonomy</h2>
          <div class="flex gap-2">
            <button
              @click="seedInterests"
              :disabled="loading || seedingInterests"
              class="px-4 py-2 text-sm bg-green-600 text-white rounded-md hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {{ seedingInterests ? 'Seeding...' : 'Seed Base Interests' }}
            </button>
            <button
              @click="showCreateModal = true"
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

        <div v-if="error" class="mb-4 p-4 bg-red-50 border border-red-200 rounded-lg">
          <p class="text-red-800">{{ error }}</p>
        </div>

        <div v-if="successMessage" class="mb-4 p-4 bg-green-50 border border-green-200 rounded-lg">
          <p class="text-green-800">{{ successMessage }}</p>
        </div>

        <div v-if="loading" class="text-center py-12">
          <p class="text-gray-500">Loading interests...</p>
        </div>

        <div v-else>
          <!-- Interest Tree View -->
          <div class="bg-white shadow rounded-lg overflow-hidden">
            <div v-if="interests.length === 0" class="p-6 text-center text-gray-500">
              <p>No interests found. Click "Seed Base Interests" to start.</p>
            </div>
            <div v-else class="divide-y">
              <InterestItem
                v-for="interest in interests"
                :key="interest.id"
                :interest="interest"
                :allInterests="interests"
                @edit="editInterest"
                @delete="deleteInterestItem"
                @add-child="showCreateChildModal(interest)"
              />
            </div>
          </div>
        </div>
      </div>
    </main>

    <!-- Create Interest Modal -->
    <div v-if="showCreateModal" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
      <div class="bg-white rounded-lg shadow-lg max-w-md w-full p-6">
        <h3 class="text-lg font-semibold text-gray-900 mb-4">Create New Interest</h3>
        
        <form @submit.prevent="submitCreateInterest" class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Name (ID)</label>
            <input
              v-model="form.name"
              type="text"
              placeholder="fashion-basics"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500"
              required
            />
            <p class="text-xs text-gray-500 mt-1">Lowercase with hyphens</p>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Display Name</label>
            <input
              v-model="form.displayName"
              type="text"
              placeholder="Fashion Basics"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500"
              required
            />
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Description (optional)</label>
            <textarea
              v-model="form.description"
              rows="3"
              placeholder="Brief description of this interest..."
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500"
            ></textarea>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Keywords (comma-separated)</label>
            <input
              v-model="form.keywordsInput"
              type="text"
              placeholder="fashion, style, clothing"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
          </div>

          <div class="flex gap-3 pt-4">
            <button
              type="button"
              @click="showCreateModal = false"
              class="flex-1 px-4 py-2 text-gray-700 border border-gray-300 rounded-md hover:bg-gray-50"
            >
              Cancel
            </button>
            <button
              type="submit"
              :disabled="creatingInterest"
              class="flex-1 px-4 py-2 bg-indigo-600 text-white rounded-md hover:bg-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {{ creatingInterest ? 'Creating...' : 'Create' }}
            </button>
          </div>
        </form>
      </div>
    </div>

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
import { ref, onMounted } from 'vue';
import AppHeader from '../components/AppHeader.vue';
import InterestItem from '../components/InterestItem.vue';
import { useInterestService } from '../composables/interestService';

const { getInterests, createInterest, updateInterest, deleteInterest, seedInterests: seedFromAPI } = useInterestService();

const interests = ref([]);
const loading = ref(false);
const error = ref(null);
const successMessage = ref(null);

// Create modal state
const showCreateModal = ref(false);
const creatingInterest = ref(false);
const form = ref({
  name: '',
  displayName: '',
  description: '',
  keywordsInput: '',
  parentId: null
});

// Edit modal state
const showEditModal = ref(false);
const updatingInterest = ref(false);
const editingInterest = ref(null);
const editingKeywordsInput = ref('');

// Seed state
const seedingInterests = ref(false);

onMounted(async () => {
  await loadInterests();
});

async function loadInterests() {
  try {
    loading.value = true;
    error.value = null;
    interests.value = await getInterests();
  } catch (err) {
    error.value = err.message || 'Failed to load interests';
    console.error('Error loading interests:', err);
  } finally {
    loading.value = false;
  }
}

async function submitCreateInterest() {
  try {
    creatingInterest.value = true;
    error.value = null;

    const keywords = form.value.keywordsInput
      .split(',')
      .map(k => k.trim())
      .filter(k => k);

    await createInterest({
      name: form.value.name,
      displayName: form.value.displayName,
      description: form.value.description || null,
      keywords,
      parentId: form.value.parentId
    });

    successMessage.value = 'Interest created successfully!';
    showCreateModal.value = false;
    
    // Reset form
    form.value = {
      name: '',
      displayName: '',
      description: '',
      keywordsInput: '',
      parentId: null
    };

    await loadInterests();
    setTimeout(() => { successMessage.value = null; }, 3000);
  } catch (err) {
    error.value = err.response?.data?.message || err.message || 'Failed to create interest';
    console.error('Error creating interest:', err);
  } finally {
    creatingInterest.value = false;
  }
}

function editInterest(interest) {
  editingInterest.value = { ...interest };
  editingKeywordsInput.value = (interest.keywords || []).join(', ');
  showEditModal.value = true;
}

async function submitEditInterest() {
  try {
    updatingInterest.value = true;
    error.value = null;

    const keywords = editingKeywordsInput.value
      .split(',')
      .map(k => k.trim())
      .filter(k => k);

    await updateInterest(editingInterest.value.id, {
      displayName: editingInterest.value.displayName,
      description: editingInterest.value.description,
      keywords,
      isActive: editingInterest.value.isActive
    });

    successMessage.value = 'Interest updated successfully!';
    showEditModal.value = false;
    await loadInterests();
    setTimeout(() => { successMessage.value = null; }, 3000);
  } catch (err) {
    error.value = err.response?.data?.message || err.message || 'Failed to update interest';
    console.error('Error updating interest:', err);
  } finally {
    updatingInterest.value = false;
  }
}

async function deleteInterestItem(id) {
  if (!confirm('Are you sure you want to delete this interest? This action cannot be undone.')) {
    return;
  }

  try {
    error.value = null;
    await deleteInterest(id);
    successMessage.value = 'Interest deleted successfully!';
    await loadInterests();
    setTimeout(() => { successMessage.value = null; }, 3000);
  } catch (err) {
    error.value = err.response?.data?.message || err.message || 'Failed to delete interest';
    console.error('Error deleting interest:', err);
  }
}

function showCreateChildModal(parentInterest) {
  form.value.parentId = parentInterest.id;
  showCreateModal.value = true;
}

async function seedInterests() {
  if (!confirm('This will seed the base interests. Continue?')) {
    return;
  }

  try {
    seedingInterests.value = true;
    error.value = null;
    await seedFromAPI();
    successMessage.value = 'Base interests seeded successfully!';
    await loadInterests();
    setTimeout(() => { successMessage.value = null; }, 3000);
  } catch (err) {
    error.value = err.response?.data?.message || err.message || 'Failed to seed interests';
    console.error('Error seeding interests:', err);
  } finally {
    seedingInterests.value = false;
  }
}
</script>
