<template>
  <div class="bg-white border border-gray-200 rounded-lg p-6 hover:shadow-md transition-shadow">
    <div class="flex items-center justify-between">
      <div class="flex items-center space-x-4 flex-1">
        <img
          v-if="user.photoURL"
          :src="user.photoURL"
          :alt="user.displayName || user.email"
          class="h-12 w-12 rounded-full"
        />
        <div v-else class="h-12 w-12 rounded-full bg-gray-300 flex items-center justify-center">
          <span class="text-gray-600 font-medium">{{ (user.displayName || user.email || 'U')[0].toUpperCase() }}</span>
        </div>
        <div class="flex-1">
          <h3 class="text-lg font-medium text-gray-900">
            {{ user.displayName || user.email || 'Unknown User' }}
          </h3>
          <p class="text-sm text-gray-500">{{ user.email }}</p>
          <p v-if="user.username" class="text-xs text-gray-400">@{{ user.username }}</p>
          <div class="flex items-center space-x-4 mt-2 text-xs text-gray-500">
            <span>Joined: {{ formatDate(user.createdAt) }}</span>
            <span v-if="user.stats?.lastActivityAt">Last active: {{ formatDate(user.stats.lastActivityAt) }}</span>
            <span v-else class="text-gray-400">Never active</span>
          </div>
        </div>
      </div>
      <div class="flex items-center space-x-2">
        <span
          v-if="user.isBanned"
          class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800"
        >
          Banned
        </span>
        <span
          v-if="user.isAdmin"
          class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800"
        >
          Admin
        </span>
      </div>
    </div>
    
    <!-- Stats Row -->
    <div class="mt-4 grid grid-cols-4 gap-4 pt-4 border-t border-gray-200">
      <div class="text-center">
        <div class="text-lg font-semibold text-gray-900">{{ user.stats?.postCount || 0 }}</div>
        <div class="text-xs text-gray-500">Posts</div>
      </div>
      <div class="text-center">
        <div class="text-lg font-semibold text-gray-900">{{ user.stats?.followerCount || 0 }}</div>
        <div class="text-xs text-gray-500">Followers</div>
      </div>
      <div class="text-center">
        <div class="text-lg font-semibold text-gray-900">{{ user.stats?.followingCount || 0 }}</div>
        <div class="text-xs text-gray-500">Following</div>
      </div>
      <div class="text-center">
        <div class="text-lg font-semibold text-gray-900">{{ user.stats?.totalEngagements || 0 }}</div>
        <div class="text-xs text-gray-500">Engagements</div>
      </div>
    </div>

    <!-- Actions -->
    <div class="mt-4 flex items-center justify-end space-x-2">
      <button
        @click="$emit('view', user.id)"
        class="px-4 py-2 text-sm font-medium text-indigo-600 hover:text-indigo-700"
      >
        View Details
      </button>
      <button
        @click="$emit('ban', user.id)"
        :disabled="user.isBanned"
        class="px-4 py-2 text-sm font-medium text-red-600 hover:text-red-700 disabled:opacity-50 disabled:cursor-not-allowed"
      >
        {{ user.isBanned ? 'Banned' : 'Ban' }}
      </button>
      <button
        @click="$emit('unban', user.id)"
        :disabled="!user.isBanned"
        class="px-4 py-2 text-sm font-medium text-green-600 hover:text-green-700 disabled:opacity-50 disabled:cursor-not-allowed"
      >
        Unban
      </button>
      <button
        @click="$emit('delete', user.id)"
        class="px-4 py-2 text-sm font-medium text-red-700 bg-red-50 hover:bg-red-100 rounded-md"
      >
        Delete
      </button>
    </div>
  </div>
</template>

<script setup>
defineProps({
  user: {
    type: Object,
    required: true
  }
});

defineEmits(['ban', 'unban', 'delete', 'view']);

const formatDate = (timestamp) => {
  if (!timestamp) return 'Unknown';
  const date = new Date(timestamp);
  return date.toLocaleDateString();
};
</script>

