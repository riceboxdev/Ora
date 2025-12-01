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

        <div v-if="loading" class="text-center py-12">
          <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600"></div>
          <p class="mt-2 text-gray-500">Loading details...</p>
        </div>

        <div v-else-if="!classification" class="text-center py-12">
          <p class="text-gray-500">Classification not found.</p>
        </div>

        <div v-else class="grid grid-cols-1 gap-6 lg:grid-cols-3">
          <!-- Post Info -->
          <div class="bg-white shadow overflow-hidden sm:rounded-lg">
            <div class="px-4 py-5 sm:px-6">
              <h3 class="text-lg leading-6 font-medium text-gray-900">Post Details</h3>
            </div>
            <div class="border-t border-gray-200">
              <div class="aspect-w-1 aspect-h-1 w-full bg-gray-200">
                <img 
                  v-if="classification.post?.imageUrl" 
                  :src="classification.post.imageUrl" 
                  class="w-full h-64 object-cover"
                />
              </div>
              <div class="px-4 py-5 sm:px-6">
                <p class="text-sm text-gray-500 mb-2">Caption</p>
                <p class="text-sm text-gray-900">{{ classification.post?.caption || 'No caption' }}</p>
                
                <div class="mt-4">
                  <p class="text-sm text-gray-500 mb-2">User Tags</p>
                  <div class="flex flex-wrap gap-2">
                    <span 
                      v-for="tag in (classification.post?.tags || [])" 
                      :key="tag"
                      class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800"
                    >
                      #{{ tag }}
                    </span>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- Classifications -->
          <div class="lg:col-span-2 space-y-6">
            <div class="bg-white shadow overflow-hidden sm:rounded-lg">
              <div class="px-4 py-5 sm:px-6 flex justify-between items-center">
                <h3 class="text-lg leading-6 font-medium text-gray-900">Classifications</h3>
                <div class="flex space-x-2">
                  <button
                    @click="reclassify"
                    class="px-3 py-1.5 border border-gray-300 rounded-md text-sm font-medium text-gray-700 hover:bg-gray-50"
                  >
                    Re-run Model
                  </button>
                  <button
                    @click="showAddModal = true"
                    class="px-3 py-1.5 bg-indigo-600 text-white rounded-md text-sm font-medium hover:bg-indigo-700"
                  >
                    Add Interest
                  </button>
                </div>
              </div>
              <div class="border-t border-gray-200">
                <ul class="divide-y divide-gray-200">
                  <li v-for="cls in (classification.classifications || [])" :key="cls.interestId" class="px-4 py-4 sm:px-6">
                    <div class="flex items-center justify-between">
                      <div class="flex-1">
                        <div class="flex items-center">
                          <h4 class="text-sm font-bold text-gray-900">{{ cls.interestName }}</h4>
                          <span class="ml-2 text-xs text-gray-500">{{ cls.interestId }}</span>
                        </div>
                        <div class="mt-2 w-full bg-gray-200 rounded-full h-2.5">
                          <div class="bg-indigo-600 h-2.5 rounded-full" :style="{ width: `${cls.confidence * 100}%` }"></div>
                        </div>
                        <div class="mt-1 flex justify-between text-xs text-gray-500">
                          <span>Confidence: {{ (cls.confidence * 100).toFixed(1) }}%</span>
                          <span>Level: {{ cls.interestLevel }}</span>
                        </div>
                        <div class="mt-2 flex flex-wrap gap-1">
                          <span 
                            v-for="signal in cls.signals" 
                            :key="signal"
                            class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-yellow-100 text-yellow-800"
                          >
                            {{ signal }}
                          </span>
                        </div>
                      </div>
                      <div class="ml-4">
                        <button 
                          @click="removeInterest(cls.interestId)"
                          class="text-red-600 hover:text-red-900 text-sm font-medium"
                        >
                          Remove
                        </button>
                      </div>
                    </div>
                  </li>
                </ul>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Add Interest Modal -->
      <div v-if="showAddModal" class="fixed z-10 inset-0 overflow-y-auto" aria-labelledby="modal-title" role="dialog" aria-modal="true">
        <div class="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
          <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity" aria-hidden="true" @click="showAddModal = false"></div>
          <span class="hidden sm:inline-block sm:align-middle sm:h-screen" aria-hidden="true">&#8203;</span>
          <div class="inline-block align-bottom bg-white rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg sm:w-full">
            <div class="bg-white px-4 pt-5 pb-4 sm:p-6 sm:pb-4">
              <h3 class="text-lg leading-6 font-medium text-gray-900" id="modal-title">Add Interest</h3>
              <div class="mt-4 space-y-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700">Interest ID</label>
                  <input v-model="newInterest.id" type="text" class="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm" />
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700">Confidence (0.0 - 1.0)</label>
                  <input v-model.number="newInterest.confidence" type="number" step="0.1" min="0" max="1" class="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm" />
                </div>
              </div>
            </div>
            <div class="bg-gray-50 px-4 py-3 sm:px-6 sm:flex sm:flex-row-reverse">
              <button @click="addInterest" type="button" class="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-indigo-600 text-base font-medium text-white hover:bg-indigo-700 focus:outline-none sm:ml-3 sm:w-auto sm:text-sm">
                Add
              </button>
              <button @click="showAddModal = false" type="button" class="mt-3 w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 focus:outline-none sm:mt-0 sm:ml-3 sm:w-auto sm:text-sm">
                Cancel
              </button>
            </div>
          </div>
        </div>
      </div>

    </main>
  </div>
</template>

<script setup>
import { ref, onMounted, reactive } from 'vue';
import { useRoute } from 'vue-router';
import AppHeader from '../components/AppHeader.vue';
import classificationService from '../src/services/PostClassificationService';
import { useToast } from 'vue-toastification';

const route = useRoute();
const toast = useToast();
const loading = ref(false);
const classification = ref(null);
const showAddModal = ref(false);
const newInterest = reactive({ id: '', confidence: 1.0 });

const fetchDetails = async () => {
  loading.value = true;
  try {
    const response = await classificationService.getClassification(route.params.postId);
    classification.value = response.data || response;
  } catch (error) {
    console.error('Error fetching details:', error);
    toast.error('Failed to load classification details');
  } finally {
    loading.value = false;
  }
};

const reclassify = async () => {
  try {
    await classificationService.reclassifyPost(route.params.postId);
    toast.success('Reclassification triggered');
    // Ideally poll for updates or wait
  } catch (error) {
    toast.error('Failed to trigger reclassification');
  }
};

const addInterest = async () => {
  try {
    await classificationService.addInterest(route.params.postId, {
      interestId: newInterest.id,
      confidence: newInterest.confidence
    });
    toast.success('Interest added');
    showAddModal.value = false;
    fetchDetails();
  } catch (error) {
    toast.error('Failed to add interest');
  }
};

const removeInterest = async (interestId) => {
  if (!confirm('Are you sure?')) return;
  try {
    await classificationService.removeInterest(route.params.postId, interestId);
    toast.success('Interest removed');
    fetchDetails();
  } catch (error) {
    toast.error('Failed to remove interest');
  }
};

onMounted(() => {
  fetchDetails();
});
</script>
