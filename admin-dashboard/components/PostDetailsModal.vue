<template>
  <div
    v-if="isOpen"
    class="fixed inset-0 z-50 overflow-y-auto"
    @click.self="$emit('close')"
  >
    <div class="flex items-center justify-center min-h-screen px-4 pt-4 pb-20 text-center sm:block sm:p-0">
      <div class="fixed inset-0 transition-opacity bg-gray-500 bg-opacity-75" @click="$emit('close')"></div>

      <div class="inline-block align-bottom bg-white rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-4xl sm:w-full">
        <div class="bg-white px-4 pt-5 pb-4 sm:p-6 sm:pb-4">
          <div class="flex items-center justify-between mb-4">
            <h3 class="text-lg font-medium text-gray-900">Post Details</h3>
            <button
              @click="$emit('close')"
              class="text-gray-400 hover:text-gray-500"
            >
              <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>

          <div v-if="loading" class="text-center py-12">
            <p class="text-gray-500">Loading post details...</p>
          </div>

          <div v-else-if="post" class="space-y-6">
            <!-- Image Section -->
            <div class="flex justify-center">
              <img
                v-if="post.imageUrl"
                :src="post.imageUrl"
                :alt="post.caption || 'Post image'"
                class="max-h-96 rounded-lg"
              />
            </div>

            <!-- Main Info -->
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <h4 class="text-sm font-medium text-gray-500 mb-1">Post ID</h4>
                <p class="text-sm text-gray-900 font-mono">{{ post.id }}</p>
              </div>
              <div>
                <h4 class="text-sm font-medium text-gray-500 mb-1">Status</h4>
                <span
                  :class="getStatusClass(post.moderationStatus)"
                  class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium"
                >
                  {{ getStatusLabel(post.moderationStatus) }}
                </span>
              </div>
              <div>
                <h4 class="text-sm font-medium text-gray-500 mb-1">Created</h4>
                <p class="text-sm text-gray-900">{{ formatDate(post.createdAt) }}</p>
              </div>
              <div>
                <h4 class="text-sm font-medium text-gray-500 mb-1">Last Updated</h4>
                <p class="text-sm text-gray-900">{{ formatDate(post.updatedAt) }}</p>
              </div>
            </div>

            <!-- Caption -->
            <div>
              <h4 class="text-sm font-medium text-gray-500 mb-1">Caption</h4>
              <p class="text-sm text-gray-900 whitespace-pre-wrap">{{ post.caption || 'No caption' }}</p>
            </div>

            <!-- Tags and Categories -->
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <h4 class="text-sm font-medium text-gray-500 mb-2">Tags</h4>
                <div class="flex flex-wrap gap-2">
                  <span
                    v-for="tag in (post.tags || [])"
                    :key="tag"
                    class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-gray-100 text-gray-800"
                  >
                    {{ tag }}
                  </span>
                  <span v-if="!post.tags || post.tags.length === 0" class="text-xs text-gray-400">No tags</span>
                </div>
              </div>
              <div>
                <h4 class="text-sm font-medium text-gray-500 mb-2">Categories</h4>
                <div class="flex flex-wrap gap-2">
                  <span
                    v-for="category in (post.categories || [])"
                    :key="category"
                    class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-100 text-blue-800"
                  >
                    {{ category }}
                  </span>
                  <span v-if="!post.categories || post.categories.length === 0" class="text-xs text-gray-400">No categories</span>
                </div>
              </div>
            </div>

            <!-- Engagement Metrics -->
            <div>
              <h4 class="text-sm font-medium text-gray-500 mb-2">Engagement</h4>
              <div class="grid grid-cols-2 md:grid-cols-5 gap-4">
                <div class="text-center p-3 bg-gray-50 rounded-lg">
                  <p class="text-2xl font-semibold text-gray-900">{{ post.likeCount || 0 }}</p>
                  <p class="text-xs text-gray-500">Likes</p>
                </div>
                <div class="text-center p-3 bg-gray-50 rounded-lg">
                  <p class="text-2xl font-semibold text-gray-900">{{ post.commentCount || 0 }}</p>
                  <p class="text-xs text-gray-500">Comments</p>
                </div>
                <div class="text-center p-3 bg-gray-50 rounded-lg">
                  <p class="text-2xl font-semibold text-gray-900">{{ post.viewCount || 0 }}</p>
                  <p class="text-xs text-gray-500">Views</p>
                </div>
                <div class="text-center p-3 bg-gray-50 rounded-lg">
                  <p class="text-2xl font-semibold text-gray-900">{{ post.shareCount || 0 }}</p>
                  <p class="text-xs text-gray-500">Shares</p>
                </div>
                <div class="text-center p-3 bg-gray-50 rounded-lg">
                  <p class="text-2xl font-semibold text-gray-900">{{ post.saveCount || 0 }}</p>
                  <p class="text-xs text-gray-500">Saves</p>
                </div>
              </div>
            </div>

            <!-- User Info -->
            <div v-if="post.user" class="border-t pt-4">
              <h4 class="text-sm font-medium text-gray-500 mb-2">User Information</h4>
              <div class="flex items-center space-x-3">
                <img
                  v-if="post.user.photoURL"
                  :src="post.user.photoURL"
                  :alt="post.user.displayName || post.user.email"
                  class="h-10 w-10 rounded-full"
                />
                <div v-else class="h-10 w-10 rounded-full bg-gray-300 flex items-center justify-center">
                  <span class="text-gray-600 font-medium">{{ (post.user.displayName || post.user.email || 'U')[0].toUpperCase() }}</span>
                </div>
                <div>
                  <p class="text-sm font-medium text-gray-900">{{ post.user.displayName || post.user.email || 'Unknown' }}</p>
                  <p class="text-xs text-gray-500">{{ post.user.email }}</p>
                  <span
                    v-if="post.user.isBanned"
                    class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-red-100 text-red-800 mt-1"
                  >
                    Banned
                  </span>
                </div>
              </div>
            </div>

            <!-- Moderation Info -->
            <div v-if="post.moderatedBy || post.moderatedAt" class="border-t pt-4">
              <h4 class="text-sm font-medium text-gray-500 mb-2">Moderation History</h4>
              <div class="space-y-2">
                <div v-if="post.moderatedBy">
                  <p class="text-xs text-gray-500">Moderated by:</p>
                  <p class="text-sm text-gray-900">{{ post.moderatedBy }}</p>
                </div>
                <div v-if="post.moderatedAt">
                  <p class="text-xs text-gray-500">Moderated at:</p>
                  <p class="text-sm text-gray-900">{{ formatDate(post.moderatedAt) }}</p>
                </div>
                <div v-if="post.moderationReason">
                  <p class="text-xs text-gray-500">Reason:</p>
                  <p class="text-sm text-gray-900">{{ post.moderationReason }}</p>
                </div>
              </div>
            </div>

            <!-- Image Dimensions -->
            <div v-if="post.imageWidth || post.imageHeight" class="border-t pt-4">
              <h4 class="text-sm font-medium text-gray-500 mb-2">Image Dimensions</h4>
              <p class="text-sm text-gray-900">{{ post.imageWidth }} × {{ post.imageHeight }} pixels</p>
            </div>
          </div>

          <div v-else class="text-center py-12">
            <p class="text-gray-500">Post not found</p>
          </div>
        </div>

        <div v-if="post" class="bg-gray-50 px-4 py-3 sm:px-6 sm:flex sm:flex-row-reverse">
          <button
            type="button"
            @click="$emit('edit', post.id)"
            class="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-indigo-600 text-base font-medium text-white hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:ml-3 sm:w-auto sm:text-sm"
          >
            Edit Post
          </button>
          <button
            type="button"
            @click="$emit('close')"
            class="mt-3 w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:mt-0 sm:ml-3 sm:w-auto sm:text-sm"
          >
            Close
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, watch } from 'vue';
import api from '../services/api';

const props = defineProps({
  isOpen: {
    type: Boolean,
    default: false
  },
  postId: {
    type: String,
    default: null
  }
});

const emit = defineEmits(['close', 'edit']);

const post = ref(null);
const loading = ref(false);

watch([() => props.isOpen, () => props.postId], async ([isOpen, postId]) => {
  if (isOpen && postId) {
    await fetchPostDetails(postId);
  } else {
    post.value = null;
  }
});

const fetchPostDetails = async (postId) => {
  loading.value = true;
  try {
    const response = await api.get(`/api/admin/posts/${postId}`);
    post.value = response.data.post;
  } catch (error) {
    console.error('Error fetching post details:', error);
    post.value = null;
  } finally {
    loading.value = false;
  }
};

const formatDate = (timestamp) => {
  if (!timestamp) return 'Unknown';
  const date = new Date(timestamp);
  return date.toLocaleDateString() + ' ' + date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
};

const getStatusClass = (status) => {
  const classes = {
    pending: 'bg-yellow-100 text-yellow-800',
    approved: 'bg-green-100 text-green-800',
    rejected: 'bg-red-100 text-red-800',
    flagged: 'bg-orange-100 text-orange-800'
  };
  return classes[status] || 'bg-gray-100 text-gray-800';
};

const getStatusLabel = (status) => {
  const labels = {
    pending: 'Pending',
    approved: 'Approved',
    rejected: 'Rejected',
    flagged: 'Flagged'
  };
  return labels[status] || status;
};
</script>

