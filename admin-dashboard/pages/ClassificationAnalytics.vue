<template>
  <div class="min-h-screen bg-gray-50">
    <AppHeader />
    
    <main class="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
      <div class="px-4 py-6 sm:px-0">
        <div class="mb-6">
          <router-link to="/classification" class="text-indigo-600 hover:text-indigo-900 flex items-center">
            <svg class="h-5 w-5 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
            </svg>
            Back to List
          </router-link>
        </div>

        <h2 class="text-2xl font-bold text-gray-900 mb-6">Classification Analytics</h2>

        <div v-if="loading" class="text-center py-12">
          <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600"></div>
          <p class="mt-2 text-gray-500">Loading analytics...</p>
        </div>

        <div v-else class="space-y-6">
          <!-- Key Metrics -->
          <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4">
            <div class="bg-white overflow-hidden shadow rounded-lg px-4 py-5 sm:p-6">
              <dt class="text-sm font-medium text-gray-500 truncate">Total Posts</dt>
              <dd class="mt-1 text-3xl font-semibold text-gray-900">{{ stats.totalPosts }}</dd>
            </div>
            <div class="bg-white overflow-hidden shadow rounded-lg px-4 py-5 sm:p-6">
              <dt class="text-sm font-medium text-gray-500 truncate">Classified Posts</dt>
              <dd class="mt-1 text-3xl font-semibold text-gray-900">{{ stats.classifiedPosts }}</dd>
            </div>
            <div class="bg-white overflow-hidden shadow rounded-lg px-4 py-5 sm:p-6">
              <dt class="text-sm font-medium text-gray-500 truncate">Avg Confidence</dt>
              <dd class="mt-1 text-3xl font-semibold text-gray-900">{{ (stats.avgConfidence * 100).toFixed(1) }}%</dd>
            </div>
            <div class="bg-white overflow-hidden shadow rounded-lg px-4 py-5 sm:p-6">
              <dt class="text-sm font-medium text-gray-500 truncate">Avg Classifications/Post</dt>
              <dd class="mt-1 text-3xl font-semibold text-gray-900">{{ stats.avgClassificationsPerPost.toFixed(1) }}</dd>
            </div>
          </div>

          <!-- Charts Placeholder (Implementing full charts requires Chart.js setup which might be complex to do blindly) -->
          <!-- We'll display tables for now -->
          
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <!-- Signal Distribution -->
            <div class="bg-white shadow rounded-lg p-6">
              <h3 class="text-lg font-medium text-gray-900 mb-4">Signal Distribution</h3>
              <ul class="divide-y divide-gray-200">
                <li v-for="(count, signal) in stats.signalCounts" :key="signal" class="py-3 flex justify-between">
                  <span class="text-gray-700 capitalize">{{ signal }}</span>
                  <span class="font-medium text-gray-900">{{ count }}</span>
                </li>
              </ul>
            </div>

            <!-- Top Interests -->
            <div class="bg-white shadow rounded-lg p-6">
              <h3 class="text-lg font-medium text-gray-900 mb-4">Top Interests by Post Count</h3>
              <div class="overflow-y-auto max-h-64">
                <ul class="divide-y divide-gray-200">
                  <li v-for="(count, interestId) in sortedInterests" :key="interestId" class="py-3 flex justify-between">
                    <span class="text-gray-700">{{ interestId }}</span>
                    <span class="font-medium text-gray-900">{{ count }}</span>
                  </li>
                </ul>
              </div>
            </div>
          </div>
        </div>
      </div>
    </main>
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue';
import AppHeader from '../components/AppHeader.vue';
import classificationService from '../src/services/PostClassificationService';
import { useToast } from 'vue-toastification';

const toast = useToast();
const loading = ref(false);
const stats = ref({
  totalPosts: 0,
  classifiedPosts: 0,
  avgConfidence: 0,
  avgClassificationsPerPost: 0,
  signalCounts: {},
  interestPostCounts: {}
});

const sortedInterests = computed(() => {
  return Object.entries(stats.value.interestPostCounts)
    .sort(([,a], [,b]) => b - a)
    .reduce((r, [k, v]) => ({ ...r, [k]: v }), {});
});

const fetchAnalytics = async () => {
  loading.value = true;
  try {
    const response = await classificationService.getAnalytics();
    stats.value = response.data || response;
  } catch (error) {
    console.error('Error fetching analytics:', error);
    toast.error('Failed to load analytics');
  } finally {
    loading.value = false;
  }
};

onMounted(() => {
  fetchAnalytics();
});
</script>
