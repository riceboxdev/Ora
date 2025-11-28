<template>
  <div
    v-if="isOpen"
    class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50"
    @click.self="close"
  >
    <div class="relative top-20 mx-auto p-5 border w-11/12 max-w-6xl shadow-lg rounded-md bg-white">
      <div class="flex justify-between items-center mb-4">
        <h3 class="text-lg font-medium text-gray-900">User Details</h3>
        <button
          @click="close"
          class="text-gray-400 hover:text-gray-500"
        >
          <span class="sr-only">Close</span>
          ✕
        </button>
      </div>

      <div v-if="loading" class="text-center py-12">
        <p class="text-gray-500">Loading user details...</p>
      </div>

      <div v-else-if="user" class="space-y-6">
        <!-- Profile Overview -->
        <div class="bg-gray-50 rounded-lg p-6">
          <div class="flex items-start space-x-6">
            <img
              v-if="user.photoURL"
              :src="user.photoURL"
              :alt="user.displayName || user.email"
              class="h-24 w-24 rounded-full"
            />
            <div v-else class="h-24 w-24 rounded-full bg-gray-300 flex items-center justify-center">
              <span class="text-gray-600 font-medium text-2xl">
                {{ (user.displayName || user.email || 'U')[0].toUpperCase() }}
              </span>
            </div>
            <div class="flex-1">
              <h4 class="text-2xl font-bold text-gray-900">{{ user.displayName || user.email || 'Unknown' }}</h4>
              <p class="text-gray-600">{{ user.email }}</p>
              <p v-if="user.username" class="text-gray-500">@{{ user.username }}</p>
              <div class="mt-4 flex flex-wrap gap-2">
                <span
                  v-if="user.isBanned"
                  class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-red-100 text-red-800"
                >
                  Banned
                </span>
                <span
                  v-if="user.isAdmin"
                  class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-blue-100 text-blue-800"
                >
                  Admin
                </span>
              </div>
            </div>
            <div class="flex space-x-2">
              <button
                v-if="!user.isBanned"
                @click="handleBan"
                class="px-4 py-2 text-sm font-medium text-red-600 bg-red-50 border border-red-200 rounded-md hover:bg-red-100"
              >
                Ban
              </button>
              <button
                v-else
                @click="handleUnban"
                class="px-4 py-2 text-sm font-medium text-green-600 bg-green-50 border border-green-200 rounded-md hover:bg-green-100"
              >
                Unban
              </button>
              <button
                @click="showWarningModal = true"
                class="px-4 py-2 text-sm font-medium text-yellow-600 bg-yellow-50 border border-yellow-200 rounded-md hover:bg-yellow-100"
              >
                Warn
              </button>
              <button
                @click="showTempBanModal = true"
                class="px-4 py-2 text-sm font-medium text-orange-600 bg-orange-50 border border-orange-200 rounded-md hover:bg-orange-100"
              >
                Temp Ban
              </button>
            </div>
          </div>

          <!-- Stats Grid -->
          <div class="mt-6 grid grid-cols-2 md:grid-cols-4 gap-4">
            <div class="bg-white rounded-lg p-4 border border-gray-200">
              <div class="text-sm text-gray-500">Posts</div>
              <div class="text-2xl font-bold text-gray-900">{{ user.stats?.postCount || 0 }}</div>
            </div>
            <div class="bg-white rounded-lg p-4 border border-gray-200">
              <div class="text-sm text-gray-500">Followers</div>
              <div class="text-2xl font-bold text-gray-900">{{ user.stats?.followerCount || 0 }}</div>
            </div>
            <div class="bg-white rounded-lg p-4 border border-gray-200">
              <div class="text-sm text-gray-500">Following</div>
              <div class="text-2xl font-bold text-gray-900">{{ user.stats?.followingCount || 0 }}</div>
            </div>
            <div class="bg-white rounded-lg p-4 border border-gray-200">
              <div class="text-sm text-gray-500">Engagements</div>
              <div class="text-2xl font-bold text-gray-900">{{ user.stats?.totalEngagements || 0 }}</div>
            </div>
          </div>

          <!-- Additional Info -->
          <div class="mt-6 grid grid-cols-2 gap-4 text-sm">
            <div>
              <span class="text-gray-500">Joined:</span>
              <span class="ml-2 text-gray-900">{{ formatDate(user.createdAt) }}</span>
            </div>
            <div>
              <span class="text-gray-500">Last Active:</span>
              <span class="ml-2 text-gray-900">{{ user.stats?.lastActivityAt ? formatDate(user.stats.lastActivityAt) : 'Never' }}</span>
            </div>
            <div v-if="user.bio">
              <span class="text-gray-500">Bio:</span>
              <span class="ml-2 text-gray-900">{{ user.bio }}</span>
            </div>
            <div v-if="user.location">
              <span class="text-gray-500">Location:</span>
              <span class="ml-2 text-gray-900">{{ user.location }}</span>
            </div>
          </div>
        </div>

        <!-- Tabs -->
        <div class="border-b border-gray-200">
          <nav class="-mb-px flex space-x-8">
            <button
              v-for="tab in tabs"
              :key="tab.id"
              @click="activeTab = tab.id"
              :class="activeTab === tab.id ? 'border-indigo-500 text-indigo-600' : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'"
              class="whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm"
            >
              {{ tab.label }}
            </button>
          </nav>
        </div>

        <!-- Tab Content -->
        <div>
          <!-- Activity Log Tab -->
          <UserActivityLog
            v-if="activeTab === 'activity'"
            :user-id="userId"
          />

          <!-- Posts Tab -->
          <div v-else-if="activeTab === 'posts'" class="space-y-4">
            <div v-if="postsLoading" class="text-center py-8">
              <p class="text-gray-500">Loading posts...</p>
            </div>
            <div v-else-if="posts.length === 0" class="text-center py-8">
              <p class="text-gray-500">No posts found.</p>
            </div>
            <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              <div
                v-for="post in posts"
                :key="post.id"
                class="border border-gray-200 rounded-lg p-4"
              >
                <img
                  v-if="post.thumbnailUrl"
                  :src="post.thumbnailUrl"
                  :alt="post.caption"
                  class="w-full h-48 object-cover rounded-md mb-2"
                />
                <p class="text-sm text-gray-600 truncate">{{ post.caption || 'No caption' }}</p>
                <div class="mt-2 flex items-center justify-between text-xs text-gray-500">
                  <span>{{ formatDate(post.createdAt) }}</span>
                  <span
                    :class="{
                      'bg-green-100 text-green-800': post.moderationStatus === 'approved',
                      'bg-yellow-100 text-yellow-800': post.moderationStatus === 'pending',
                      'bg-red-100 text-red-800': post.moderationStatus === 'rejected'
                    }"
                    class="px-2 py-1 rounded"
                  >
                    {{ post.moderationStatus }}
                  </span>
                </div>
              </div>
            </div>
          </div>

          <!-- Moderation History Tab -->
          <div v-else-if="activeTab === 'moderation'" class="space-y-4">
            <div v-if="user.moderationHistory && user.moderationHistory.length > 0">
              <div
                v-for="entry in user.moderationHistory"
                :key="entry.id"
                class="border-l-4 border-gray-200 pl-4 py-2"
              >
                <div class="flex items-center justify-between">
                  <div>
                    <div class="font-medium text-gray-900">{{ entry.action }}</div>
                    <div class="text-sm text-gray-500">{{ formatDate(entry.timestamp) }}</div>
                    <div v-if="entry.metadata?.reason" class="text-sm text-gray-600 mt-1">
                      Reason: {{ entry.metadata.reason }}
                    </div>
                  </div>
                </div>
              </div>
            </div>
            <div v-else class="text-center py-8">
              <p class="text-gray-500">No moderation history.</p>
            </div>
          </div>

          <!-- Warnings Tab -->
          <div v-else-if="activeTab === 'warnings'" class="space-y-4">
            <div v-if="user.warnings && user.warnings.length > 0">
              <div
                v-for="warning in user.warnings"
                :key="warning.id"
                class="border border-yellow-200 bg-yellow-50 rounded-lg p-4"
              >
                <div class="flex items-center justify-between">
                  <div>
                    <div class="font-medium text-yellow-900">{{ warning.warningType }}</div>
                    <div class="text-sm text-yellow-700 mt-1">{{ warning.reason }}</div>
                    <div class="text-xs text-yellow-600 mt-1">{{ formatDate(warning.timestamp) }}</div>
                    <div v-if="warning.notes" class="text-sm text-yellow-700 mt-2">{{ warning.notes }}</div>
                  </div>
                </div>
              </div>
            </div>
            <div v-else class="text-center py-8">
              <p class="text-gray-500">No warnings issued.</p>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Warning Modal -->
    <WarningModal
      v-if="showWarningModal"
      :user-id="userId"
      @close="showWarningModal = false"
      @warned="handleWarned"
    />

    <!-- Temp Ban Modal -->
    <TempBanModal
      v-if="showTempBanModal"
      :user-id="userId"
      @close="showTempBanModal = false"
      @banned="handleTempBanned"
    />
  </div>
</template>

<script setup>
import { ref, computed, watch } from 'vue';
import api from '../services/api';
import UserActivityLog from './UserActivityLog.vue';
import WarningModal from './WarningModal.vue';
import TempBanModal from './TempBanModal.vue';

const props = defineProps({
  userId: {
    type: String,
    required: true
  }
});

const emit = defineEmits(['close', 'updated']);

const isOpen = ref(true);
const loading = ref(true);
const user = ref(null);
const activeTab = ref('activity');
const posts = ref([]);
const postsLoading = ref(false);
const showWarningModal = ref(false);
const showTempBanModal = ref(false);

const tabs = [
  { id: 'activity', label: 'Activity' },
  { id: 'posts', label: 'Posts' },
  { id: 'moderation', label: 'Moderation History' },
  { id: 'warnings', label: 'Warnings' }
];

const fetchUser = async () => {
  try {
    loading.value = true;
    const response = await api.get(`/api/admin/users/${props.userId}`);
    user.value = response.data.user;
  } catch (error) {
    console.error('Error fetching user:', error);
    alert('Failed to load user details');
  } finally {
    loading.value = false;
  }
};

const fetchPosts = async () => {
  try {
    postsLoading.value = true;
    const response = await api.get(`/api/admin/users/${props.userId}/posts`, {
      params: { limit: 50 }
    });
    posts.value = response.data.posts || [];
  } catch (error) {
    console.error('Error fetching posts:', error);
  } finally {
    postsLoading.value = false;
  }
};

watch(activeTab, (newTab) => {
  if (newTab === 'posts' && posts.value.length === 0) {
    fetchPosts();
  }
});

const handleBan = async () => {
  if (!confirm('Are you sure you want to ban this user?')) {
    return;
  }
  try {
    await api.post('/api/admin/users/ban', { userId: props.userId });
    await fetchUser();
    emit('updated');
  } catch (error) {
    console.error('Error banning user:', error);
    alert('Failed to ban user');
  }
};

const handleUnban = async () => {
  if (!confirm('Are you sure you want to unban this user?')) {
    return;
  }
  try {
    await api.post('/api/admin/users/unban', { userId: props.userId });
    await fetchUser();
    emit('updated');
  } catch (error) {
    console.error('Error unbanning user:', error);
    alert('Failed to unban user');
  }
};

const handleWarned = () => {
  showWarningModal.value = false;
  fetchUser();
  emit('updated');
};

const handleTempBanned = () => {
  showTempBanModal.value = false;
  fetchUser();
  emit('updated');
};

const close = () => {
  isOpen.value = false;
  emit('close');
};

const formatDate = (timestamp) => {
  if (!timestamp) return 'Unknown';
  const date = new Date(timestamp);
  return date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
};

fetchUser();
</script>





