<template>
  <div class="overflow-x-auto">
    <table class="min-w-full divide-y divide-gray-200">
      <thead class="bg-gray-50">
        <tr>
          <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
            <input
              type="checkbox"
              :checked="allSelected"
              @change="toggleSelectAll"
              class="rounded border-gray-300 text-indigo-600 focus:ring-indigo-500"
            />
          </th>
          <th
            v-for="column in columns"
            :key="column.key"
            class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100"
            @click="handleSort(column.key)"
          >
            <div class="flex items-center space-x-1">
              <span>{{ column.label }}</span>
              <span v-if="sortBy === column.key" class="text-indigo-600">
                {{ sortOrder === 'asc' ? '↑' : '↓' }}
              </span>
            </div>
          </th>
          <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
            Actions
          </th>
        </tr>
      </thead>
      <tbody class="bg-white divide-y divide-gray-200">
        <tr
          v-for="user in users"
          :key="user.id"
          :class="selectedUsers.includes(user.id) ? 'bg-indigo-50' : ''"
          class="hover:bg-gray-50"
        >
          <td class="px-6 py-4 whitespace-nowrap">
            <input
              type="checkbox"
              :checked="selectedUsers.includes(user.id)"
              @change="toggleSelect(user.id)"
              class="rounded border-gray-300 text-indigo-600 focus:ring-indigo-500"
            />
          </td>
          <td class="px-6 py-4 whitespace-nowrap">
            <div class="flex items-center">
              <img
                v-if="user.photoURL"
                :src="user.photoURL"
                :alt="user.displayName || user.email"
                class="h-10 w-10 rounded-full mr-3"
              />
              <div v-else class="h-10 w-10 rounded-full bg-gray-300 flex items-center justify-center mr-3">
                <span class="text-gray-600 font-medium">
                  {{ (user.displayName || user.email || 'U')[0].toUpperCase() }}
                </span>
              </div>
              <div>
                <div class="text-sm font-medium text-gray-900">
                  {{ user.displayName || user.email || 'Unknown' }}
                </div>
                <div class="text-sm text-gray-500">{{ user.email }}</div>
              </div>
            </div>
          </td>
          <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
            {{ user.username || '-' }}
          </td>
          <td class="px-6 py-4 whitespace-nowrap">
            <div class="flex flex-wrap gap-1">
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
          </td>
          <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
            {{ user.stats?.postCount || 0 }}
          </td>
          <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
            {{ user.stats?.followerCount || 0 }}
          </td>
          <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
            {{ formatDate(user.createdAt) }}
          </td>
          <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
            {{ user.stats?.lastActivityAt ? formatDate(user.stats.lastActivityAt) : 'Never' }}
          </td>
          <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
            <div class="flex items-center space-x-2">
              <button
                @click="$emit('view', user.id)"
                class="text-indigo-600 hover:text-indigo-900"
              >
                View
              </button>
              <button
                v-if="!user.isBanned"
                @click="$emit('ban', user.id)"
                class="text-red-600 hover:text-red-900"
              >
                Ban
              </button>
              <button
                v-else
                @click="$emit('unban', user.id)"
                class="text-green-600 hover:text-green-900"
              >
                Unban
              </button>
            </div>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<script setup>
import { computed } from 'vue';

const props = defineProps({
  users: {
    type: Array,
    required: true
  },
  selectedUsers: {
    type: Array,
    default: () => []
  },
  sortBy: {
    type: String,
    default: 'createdAt'
  },
  sortOrder: {
    type: String,
    default: 'desc'
  }
});

const emit = defineEmits(['select', 'select-all', 'sort', 'view', 'ban', 'unban', 'delete']);

const columns = [
  { key: 'displayName', label: 'User' },
  { key: 'username', label: 'Username' },
  { key: 'status', label: 'Status' },
  { key: 'postCount', label: 'Posts' },
  { key: 'followerCount', label: 'Followers' },
  { key: 'createdAt', label: 'Joined' },
  { key: 'lastActivityAt', label: 'Last Active' }
];

const allSelected = computed(() => {
  return props.users.length > 0 && props.users.every(user => props.selectedUsers.includes(user.id));
});

const toggleSelect = (userId) => {
  emit('select', userId);
};

const toggleSelectAll = () => {
  emit('select-all');
};

const handleSort = (columnKey) => {
  emit('sort', columnKey);
};

const formatDate = (timestamp) => {
  if (!timestamp) return 'Unknown';
  const date = new Date(timestamp);
  return date.toLocaleDateString();
};
</script>








