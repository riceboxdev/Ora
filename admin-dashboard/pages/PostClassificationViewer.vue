<template>
  <div class="min-h-screen bg-gray-50">
    <AppHeader />
    
    <main class="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
      <div class="px-4 py-6 sm:px-0">
        <!-- Header -->
        <div class="flex justify-between items-center mb-6">
          <h2 class="text-2xl font-bold text-gray-900">Post Classifications</h2>
          <div class="flex items-center space-x-4">
            <button
              @click="triggerBulkClassification"
              class="px-4 py-2 bg-indigo-600 text-white rounded-md text-sm font-medium hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
            >
              Classify Unclassified
            </button>
            <router-link
              to="/classification/analytics"
              class="px-4 py-2 border border-gray-300 rounded-md text-sm font-medium text-gray-700 bg-white hover:bg-gray-50"
            >
              Analytics
            </router-link>
          </div>
        </div>

        <!-- Filters -->
        <div class="bg-white shadow rounded-lg mb-6 p-4">
          <div class="grid grid-cols-1 gap-4 sm:grid-cols-4">
            <div>
              <label class="block text-sm font-medium text-gray-700">Interest ID</label>
              <input
                v-model="filters.interestId"
                type="text"
                placeholder="e.g. fashion"
                class="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700">Min Confidence</label>
              <input
                v-model="filters.minConfidence"
                type="number"
                step="0.1"
                min="0"
                max="1"
                class="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm"
              />
            </div>
            <div class="flex items-end">
              <label class="flex items-center space-x-2 cursor-pointer">
                <input
                  v-model="filters.unclassifiedOnly"
                  type="checkbox"
                  class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded"
                />
                <span class="text-sm font-medium text-gray-700">Unclassified Only</span>
              </label>
            </div>
            <div class="flex items-end">
              <button
                @click="fetchClassifications"
                class="w-full px-4 py-2 bg-gray-100 text-gray-700 rounded-md text-sm font-medium hover:bg-gray-200 focus:outline-none"
              >
                Apply Filters
              </button>
            </div>
          </div>
        </div>

        <!-- Content -->
        <div class="bg-white shadow overflow-hidden sm:rounded-lg">
          <div v-if="loading" class="text-center py-12">
            <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600"></div>
            <p class="mt-2 text-gray-500">Loading classifications...</p>
          </div>
          
          <div v-else-if="classifications.length === 0" class="text-center py-12">
            <p class="text-gray-500">No classifications found matching criteria.</p>
          </div>

          <ul v-else class="divide-y divide-gray-200">
            <li v-for="item in classifications" :key="item.postId" class="hover:bg-gray-50">
              <div class="px-4 py-4 sm:px-6">
                <div class="flex items-center justify-between">
                  <div class="flex items-center flex-1 min-w-0">
                    <div class="flex-shrink-0 h-16 w-16 bg-gray-200 rounded overflow-hidden">
                      <img 
                        v-if="item.post?.thumbnailUrl || item.post?.imageUrl" 
                        :src="item.post?.thumbnailUrl || item.post?.imageUrl" 
                        class="h-full w-full object-cover"
                      />
                      <div v-else class="h-full w-full flex items-center justify-center text-gray-400">
                        <svg class="h-8 w-8" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                        </svg>
                      </div>
                    </div>
                    <div class="ml-4 flex-1">
                      <div class="flex items-center justify-between">
                        <p class="text-sm font-medium text-indigo-600 truncate">
                          {{ item.post?.caption || 'No caption' }}
                        </p>
                        <div class="ml-2 flex-shrink-0 flex">
                          <p class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-green-100 text-green-800">
                            {{ item.version ? `v${item.version}` : 'v1.0' }}
                          </p>
                        </div>
                      </div>
                      <div class="mt-2 flex flex-wrap gap-2">
                        <span 
                          v-for="cls in (item.classifications || []).slice(0, 3)" 
                          :key="cls.interestId"
                          class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800"
                        >
                          {{ cls.interestName }} ({{ Math.round(cls.confidence * 100) }}%)
                        </span>
                        <span v-if="(item.classifications || []).length > 3" class="text-xs text-gray-500 self-center">
                          +{{ item.classifications.length - 3 }} more
                        </span>
                      </div>
                    </div>
                  </div>
                  <div class="ml-4 flex-shrink-0">
                    <router-link 
                      :to="`/classification/${item.postId}`"
                      class="text-indigo-600 hover:text-indigo-900 text-sm font-medium"
                    >
                      View Details
                    </router-link>
                  </div>
                </div>
              </div>
            </li>
          </ul>
        </div>
      </div>
    </main>
  </div>
</template>

<script setup>
import { ref, onMounted, reactive } from 'vue';
import AppHeader from '../components/AppHeader.vue';
import classificationService from '../src/services/PostClassificationService';
import { useToast } from 'vue-toastification';

const toast = useToast();
const loading = ref(false);
const classifications = ref([]);
const filters = reactive({
  interestId: '',
  minConfidence: '',
  unclassifiedOnly: false
});

const fetchClassifications = async () => {
  loading.value = true;
  try {
    const params = {
      interestId: filters.interestId || undefined,
      minConfidence: filters.minConfidence || undefined,
      unclassifiedOnly: filters.unclassifiedOnly
    };
    const response = await classificationService.getClassifications(params);
    classifications.value = Array.isArray(response) ? response : (response.data || []);
  } catch (error) {
    console.error('Error fetching classifications:', error);
    toast.error('Failed to load classifications');
  } finally {
    loading.value = false;
  }
};

const triggerBulkClassification = async () => {
  try {
    await classificationService.bulkClassify({ batchSize: 50 });
    toast.success('Bulk classification triggered');
  } catch (error) {
    console.error('Error triggering bulk classification:', error);
    toast.error('Failed to trigger bulk classification');
  }
};

onMounted(() => {
  fetchClassifications();
});
</script>
