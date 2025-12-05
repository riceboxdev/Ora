<template>
  <div class="min-h-screen bg-gray-50">
    <AppHeader />
    
    <main class="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
      <div class="px-4 py-6 sm:px-0">
        <div class="flex justify-between items-center mb-6">
          <h2 class="text-2xl font-bold text-gray-900">Analytics</h2>
          <Select v-model="period" @update:modelValue="fetchAnalytics">
            <SelectTrigger class="px-4 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-indigo-500 focus:border-indigo-500">
              <SelectValue placeholder="Select period" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="7d">Last 7 days</SelectItem>
              <SelectItem value="30d">Last 30 days</SelectItem>
              <SelectItem value="90d">Last 90 days</SelectItem>
              <SelectItem value="all">All time</SelectItem>
            </SelectContent>
          </Select>
        </div>
        
        <div v-if="loading" class="text-center py-12">
          <p class="text-gray-500">Loading analytics...</p>
        </div>
        
        <div v-else class="space-y-6">
          <!-- Summary Cards -->
          <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-4">
            <div class="bg-white overflow-hidden shadow rounded-lg">
              <div class="p-5">
                <div class="flex items-center">
                  <div class="flex-shrink-0">
                    <svg class="h-6 w-6 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
                    </svg>
                  </div>
                  <div class="ml-5 w-0 flex-1">
                    <dl>
                      <dt class="text-sm font-medium text-gray-500 truncate">Total Users</dt>
                      <dd class="text-lg font-medium text-gray-900">{{ analytics?.users?.total || 0 }}</dd>
                      <dt class="text-xs text-gray-400 mt-1">New: {{ analytics?.users?.new || 0 }}</dt>
                    </dl>
                  </div>
                </div>
              </div>
            </div>
            
            <div class="bg-white overflow-hidden shadow rounded-lg">
              <div class="p-5">
                <div class="flex items-center">
                  <div class="flex-shrink-0">
                    <svg class="h-6 w-6 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                    </svg>
                  </div>
                  <div class="ml-5 w-0 flex-1">
                    <dl>
                      <dt class="text-sm font-medium text-gray-500 truncate">Total Posts</dt>
                      <dd class="text-lg font-medium text-gray-900">{{ analytics?.posts?.total || 0 }}</dd>
                    </dl>
                  </div>
                </div>
              </div>
            </div>
            
            <div class="bg-white overflow-hidden shadow rounded-lg">
              <div class="p-5">
                <div class="flex items-center">
                  <div class="flex-shrink-0">
                    <svg class="h-6 w-6 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
                    </svg>
                  </div>
                  <div class="ml-5 w-0 flex-1">
                    <dl>
                      <dt class="text-sm font-medium text-gray-500 truncate">Total Likes</dt>
                      <dd class="text-lg font-medium text-gray-900">{{ analytics?.engagement?.likes || 0 }}</dd>
                    </dl>
                  </div>
                </div>
              </div>
            </div>
            
            <div class="bg-white overflow-hidden shadow rounded-lg">
              <div class="p-5">
                <div class="flex items-center">
                  <div class="flex-shrink-0">
                    <svg class="h-6 w-6 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                    </svg>
                  </div>
                  <div class="ml-5 w-0 flex-1">
                    <dl>
                      <dt class="text-sm font-medium text-gray-500 truncate">Total Comments</dt>
                      <dd class="text-lg font-medium text-gray-900">{{ analytics?.engagement?.comments || 0 }}</dd>
                    </dl>
                  </div>
                </div>
              </div>
            </div>
          </div>
          
          <!-- Engagement Metrics -->
          <div class="bg-white shadow rounded-lg p-6">
            <h3 class="text-lg font-medium text-gray-900 mb-4">Engagement Metrics</h3>
            <div class="grid grid-cols-1 gap-4 sm:grid-cols-3">
              <div>
                <p class="text-sm text-gray-500">Shares</p>
                <p class="text-2xl font-semibold text-gray-900">{{ analytics?.engagement?.shares || 0 }}</p>
              </div>
              <div>
                <p class="text-sm text-gray-500">Saves</p>
                <p class="text-2xl font-semibold text-gray-900">{{ analytics?.engagement?.saves || 0 }}</p>
              </div>
              <div>
                <p class="text-sm text-gray-500">Views</p>
                <p class="text-2xl font-semibold text-gray-900">{{ analytics?.engagement?.views || 0 }}</p>
              </div>
            </div>
          </div>
          
          <!-- Moderation Status -->
          <div class="bg-white shadow rounded-lg p-6">
            <h3 class="text-lg font-medium text-gray-900 mb-4">Moderation Status</h3>
            <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
              <div>
                <p class="text-sm text-gray-500">Pending</p>
                <p class="text-2xl font-semibold text-yellow-600">{{ analytics?.posts?.pending || 0 }}</p>
              </div>
              <div>
                <p class="text-sm text-gray-500">Flagged</p>
                <p class="text-2xl font-semibold text-red-600">{{ analytics?.posts?.flagged || 0 }}</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </main>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import api from '../services/api';
import AppHeader from '../components/AppHeader.vue';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from 'reka-ui';

const analytics = ref(null);
const loading = ref(true);
const period = ref('30d');
const error = ref(null); // Added error ref

async function fetchAnalytics() {
  loading.value = true;
  try {
    const response = await api.get('/api/admin/analytics', {
      params: { period: period.value } // Kept params based on original functionality
    });
    const data = response.data;
    analytics.value = data;
  } catch (err) {
    console.error('Error fetching analytics:', err);
    error.value = 'Failed to load analytics data';
  } finally {
    loading.value = false;
  }
};

onMounted(() => {
  fetchAnalytics();
});
</script>

