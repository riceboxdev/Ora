<template>
  <div
    v-if="isOpen"
    class="fixed inset-0 z-50 overflow-y-auto"
    @click.self="$emit('close')"
  >
    <div class="flex items-center justify-center min-h-screen px-4 pt-4 pb-20 text-center sm:block sm:p-0">
      <div class="fixed inset-0 transition-opacity bg-gray-500 bg-opacity-75" @click="$emit('close')"></div>

      <div class="inline-block align-bottom bg-white rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-2xl sm:w-full">
        <div class="bg-white px-4 pt-5 pb-4 sm:p-6 sm:pb-4">
          <div class="flex items-center justify-between mb-4">
            <h3 class="text-lg font-medium text-gray-900">Edit Post</h3>
            <button
              @click="$emit('close')"
              class="text-gray-400 hover:text-gray-500"
            >
              <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>

          <form @submit.prevent="handleSubmit" class="space-y-4">
            <div>
              <label for="caption" class="block text-sm font-medium text-gray-700 mb-1">
                Caption
              </label>
              <textarea
                id="caption"
                v-model="formData.caption"
                rows="4"
                class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
                placeholder="Enter post caption..."
              ></textarea>
            </div>

            <div>
              <label for="tags" class="block text-sm font-medium text-gray-700 mb-1">
                Tags (comma-separated)
              </label>
              <input
                id="tags"
                v-model="tagsInput"
                type="text"
                class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
                placeholder="tag1, tag2, tag3"
              />
              <p class="mt-1 text-xs text-gray-500">Separate tags with commas</p>
            </div>

            <div>
              <label for="categories" class="block text-sm font-medium text-gray-700 mb-1">
                Categories (comma-separated)
              </label>
              <input
                id="categories"
                v-model="categoriesInput"
                type="text"
                class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
                placeholder="category1, category2"
              />
              <p class="mt-1 text-xs text-gray-500">Separate categories with commas</p>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                Interests
              </label>
              <InterestSelector v-model="formData.interestIds" />
            </div>

            <div v-if="canModerate">
              <label for="moderationStatus" class="block text-sm font-medium text-gray-700 mb-1">
                Moderation Status
              </label>
              <select
                id="moderationStatus"
                v-model="formData.moderationStatus"
                class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
              >
                <option value="pending">Pending</option>
                <option value="approved">Approved</option>
                <option value="rejected">Rejected</option>
                <option value="flagged">Flagged</option>
              </select>
            </div>

            <div v-if="post" class="mt-4 p-3 bg-gray-50 rounded-md">
              <p class="text-xs text-gray-500 mb-1">Post ID: {{ post.id }}</p>
              <p class="text-xs text-gray-500">Created: {{ formatDate(post.createdAt) }}</p>
            </div>

            <div v-if="error" class="mt-4 p-3 bg-red-50 border border-red-200 rounded-md">
              <p class="text-sm text-red-600">{{ error }}</p>
            </div>
          </form>
        </div>

        <div class="bg-gray-50 px-4 py-3 sm:px-6 sm:flex sm:flex-row-reverse">
          <button
            type="button"
            @click="handleSubmit"
            :disabled="saving"
            class="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-indigo-600 text-base font-medium text-white hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:ml-3 sm:w-auto sm:text-sm disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {{ saving ? 'Saving...' : 'Save Changes' }}
          </button>
          <button
            type="button"
            @click="$emit('close')"
            :disabled="saving"
            class="mt-3 w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:mt-0 sm:ml-3 sm:w-auto sm:text-sm disabled:opacity-50 disabled:cursor-not-allowed"
          >
            Cancel
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch } from 'vue';
import { useAuthStore } from '../stores/auth';
import InterestSelector from './InterestSelector.vue';


const props = defineProps({
  isOpen: {
    type: Boolean,
    default: false
  },
  post: {
    type: Object,
    default: null
  }
});

const emit = defineEmits(['close', 'save']);

const authStore = useAuthStore();

const formData = ref({
  caption: '',
  tags: [],
  categories: [],
  interestIds: [],
  moderationStatus: 'pending'
});

const tagsInput = ref('');
const categoriesInput = ref('');
const saving = ref(false);
const error = ref(null);

const canModerate = computed(() => {
  const role = authStore.admin?.role;
  return role === 'super_admin' || role === 'moderator';
});

watch(() => props.post, (newPost) => {
  if (newPost) {
    formData.value = {
      caption: newPost.caption || '',
      tags: newPost.tags || [],
      categories: newPost.categories || [],
      interestIds: newPost.interestIds || [],
      moderationStatus: newPost.moderationStatus || 'pending'
    };
    tagsInput.value = (newPost.tags || []).join(', ');
    categoriesInput.value = (newPost.categories || []).join(', ');
    error.value = null;
  }
}, { immediate: true });

watch(() => props.isOpen, (isOpen) => {
  if (isOpen && props.post) {
    formData.value = {
      caption: props.post.caption || '',
      tags: props.post.tags || [],
      categories: props.post.categories || [],
      interestIds: props.post.interestIds || [],
      moderationStatus: props.post.moderationStatus || 'pending'
    };
    tagsInput.value = (props.post.tags || []).join(', ');
    categoriesInput.value = (props.post.categories || []).join(', ');
    error.value = null;
  }
});

const handleSubmit = async () => {
  if (!props.post) return;

  saving.value = true;
  error.value = null;

  try {
    // Parse tags and categories from comma-separated strings
    const tags = tagsInput.value
      .split(',')
      .map(t => t.trim())
      .filter(t => t);
    
    const categories = categoriesInput.value
      .split(',')
      .map(c => c.trim())
      .filter(c => c);

    const updateData = {
      caption: formData.value.caption,
      tags: tags,
      categories: categories,
      interestIds: formData.value.interestIds
    };

    if (canModerate.value) {
      updateData.moderationStatus = formData.value.moderationStatus;
    }

    emit('save', props.post.id, updateData);
  } catch (err) {
    error.value = err.message || 'Failed to save changes';
  } finally {
    saving.value = false;
  }
};

const formatDate = (timestamp) => {
  if (!timestamp) return 'Unknown';
  const date = new Date(timestamp);
  return date.toLocaleDateString() + ' ' + date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
};
</script>

