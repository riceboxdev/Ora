<template>
  <div class="bg-white border border-gray-200 rounded-lg p-4 hover:shadow-md transition-shadow">
    <div class="flex space-x-4">
      <div class="flex-shrink-0">
        <div class="relative">
          <img
            v-if="post.thumbnailUrl || post.imageUrl"
            :src="post.thumbnailUrl || post.imageUrl"
            :alt="post.caption || 'Post image'"
            class="h-24 w-24 object-cover rounded-lg"
            @click="$emit('view-details', post.id)"
          />
          <div v-else class="h-24 w-24 bg-gray-200 rounded-lg flex items-center justify-center">
            <span class="text-gray-400 text-sm">No image</span>
          </div>
          <input
            v-if="selectable"
            type="checkbox"
            :checked="selected"
            @change="$emit('select', post.id, $event.target.checked)"
            class="absolute top-2 left-2 h-5 w-5 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded"
          />
        </div>
      </div>
      <div class="flex-1 min-w-0">
        <div class="flex items-start justify-between">
          <div class="flex-1 min-w-0">
            <div class="flex items-center space-x-2 mb-2">
              <span
                :class="getStatusClass(post.moderationStatus)"
                class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium"
              >
                {{ getStatusLabel(post.moderationStatus) }}
              </span>
              <span v-if="post.edited" class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-gray-100 text-gray-600">
                Edited
              </span>
            </div>
            <p class="text-sm text-gray-900 font-medium mb-1 line-clamp-2">
              {{ post.caption || 'No caption' }}
            </p>

            <div class="flex flex-wrap gap-1 mb-2">
              <span
                v-for="interestId in (post.interestIds || []).slice(0, 3)"
                :key="interestId"
                class="inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-medium bg-indigo-50 text-indigo-700 border border-indigo-100"
              >
                {{ interestMap[interestId] || interestId }}
              </span>
              <span v-if="(post.interestIds || []).length > 3" class="text-[10px] text-gray-400 self-center">
                +{{ post.interestIds.length - 3 }}
              </span>
            </div>

            <div class="flex items-center space-x-4 text-xs text-gray-500 mb-2">
              <span class="flex items-center">
                <svg class="h-4 w-4 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
                </svg>
                {{ post.likeCount || 0 }}
              </span>
              <span class="flex items-center">
                <svg class="h-4 w-4 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                </svg>
                {{ post.commentCount || 0 }}
              </span>
              <span class="flex items-center">
                <svg class="h-4 w-4 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                </svg>
                {{ post.viewCount || 0 }}
              </span>
            </div>
            <p class="text-xs text-gray-400">
              Created: {{ formatDate(post.createdAt) }}
              <span v-if="post.username"> • by {{ post.username }}</span>
            </p>
          </div>
        </div>
        <div class="mt-4 flex flex-wrap gap-2">
          <button
            @click="$emit('view-details', post.id)"
            class="px-3 py-1.5 text-sm font-medium text-indigo-600 hover:text-indigo-700 hover:bg-indigo-50 rounded-md"
          >
            View Details
          </button>
          <button
            @click="$emit('edit', post.id)"
            class="px-3 py-1.5 text-sm font-medium text-gray-700 hover:text-gray-900 hover:bg-gray-50 rounded-md"
          >
            Edit
          </button>
          <button
            v-if="canModerate"
            @click="$emit('approve', post.id)"
            :disabled="post.moderationStatus === 'approved'"
            class="px-3 py-1.5 text-sm font-medium text-white bg-green-600 hover:bg-green-700 rounded-md disabled:opacity-50 disabled:cursor-not-allowed"
          >
            Approve
          </button>
          <button
            v-if="canModerate"
            @click="$emit('reject', post.id)"
            :disabled="post.moderationStatus === 'rejected'"
            class="px-3 py-1.5 text-sm font-medium text-white bg-red-600 hover:bg-red-700 rounded-md disabled:opacity-50 disabled:cursor-not-allowed"
          >
            Reject
          </button>
          <button
            v-if="canModerate"
            @click="$emit('flag', post.id)"
            :disabled="post.moderationStatus === 'flagged'"
            class="px-3 py-1.5 text-sm font-medium text-white bg-yellow-600 hover:bg-yellow-700 rounded-md disabled:opacity-50 disabled:cursor-not-allowed"
          >
            Flag
          </button>
          <button
            @click="$emit('delete', post.id)"
            class="px-3 py-1.5 text-sm font-medium text-red-600 hover:text-red-700 hover:bg-red-50 rounded-md"
          >
            Delete
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue';
import { useAuthStore } from '../stores/auth';

const props = defineProps({
  post: {
    type: Object,
    required: true
  },
  selectable: {
    type: Boolean,
    default: false
  },
  selected: {
    type: Boolean,
    default: false
  },
  interestMap: {
    type: Object,
    default: () => ({})
  }
});

defineEmits(['select', 'view-details', 'edit', 'delete', 'approve', 'reject', 'flag']);

const authStore = useAuthStore();

const canModerate = computed(() => {
  const role = authStore.admin?.role;
  return role === 'super_admin' || role === 'moderator';
});

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

<style scoped>
.line-clamp-2 {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}
</style>

