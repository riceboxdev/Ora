<template>
  <div class="bg-white border border-gray-200 rounded-lg p-6">
    <div class="flex space-x-4">
      <div class="flex-shrink-0">
        <img
          v-if="post.thumbnailUrl || post.imageUrl"
          :src="post.thumbnailUrl || post.imageUrl"
          :alt="post.caption || 'Post image'"
          class="h-32 w-32 object-cover rounded-lg"
        />
        <div v-else class="h-32 w-32 bg-gray-200 rounded-lg flex items-center justify-center">
          <span class="text-gray-400 text-sm">No image</span>
        </div>
      </div>
      <div class="flex-1 min-w-0">
        <div class="flex items-start justify-between">
          <div class="flex-1">
            <p class="text-sm text-gray-900 font-medium mb-2">
              {{ post.caption || 'No caption' }}
            </p>
            <div class="flex flex-wrap gap-2 mb-2">
              <span
                v-for="tag in (post.tags || []).slice(0, 5)"
                :key="tag"
                class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-gray-100 text-gray-800"
              >
                {{ tag }}
              </span>
            </div>
            <p class="text-xs text-gray-500">
              Created: {{ formatDate(post.createdAt) }}
            </p>
            <p class="text-xs text-gray-500">
              Status: 
              <span :class="getStatusClass(post.moderationStatus)">
                {{ post.moderationStatus || 'pending' }}
              </span>
            </p>
          </div>
        </div>
        <div class="mt-4 flex space-x-2">
          <button
            @click="$emit('approve', post.id)"
            class="px-4 py-2 text-sm font-medium text-white bg-green-600 hover:bg-green-700 rounded-md"
          >
            Approve
          </button>
          <button
            @click="$emit('reject', post.id)"
            class="px-4 py-2 text-sm font-medium text-white bg-red-600 hover:bg-red-700 rounded-md"
          >
            Reject
          </button>
          <button
            @click="$emit('flag', post.id)"
            class="px-4 py-2 text-sm font-medium text-white bg-yellow-600 hover:bg-yellow-700 rounded-md"
          >
            Flag
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
defineProps({
  post: {
    type: Object,
    required: true
  }
});

defineEmits(['approve', 'reject', 'flag']);

const formatDate = (timestamp) => {
  if (!timestamp) return 'Unknown';
  const date = new Date(timestamp);
  return date.toLocaleDateString();
};

const getStatusClass = (status) => {
  const classes = {
    pending: 'text-yellow-600',
    approved: 'text-green-600',
    rejected: 'text-red-600',
    flagged: 'text-orange-600'
  };
  return classes[status] || 'text-gray-600';
};
</script>

