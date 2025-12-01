<template>
  <div class="min-h-screen bg-gray-50">
    <AppHeader />
    
    <main class="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
      <div class="px-4 py-6 sm:px-0">
        <!-- Header -->
        <div class="flex justify-between items-center mb-6">
          <h2 class="text-2xl font-bold text-gray-900">Interest Taxonomy</h2>
          <div class="flex items-center space-x-4">
            <button
              @click="openCreateModal"
              class="px-4 py-2 bg-indigo-600 text-white rounded-md text-sm font-medium hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
            >
              Create Interest
            </button>
            <button
              @click="exportTaxonomy"
              class="px-4 py-2 border border-gray-300 rounded-md text-sm font-medium text-gray-700 bg-white hover:bg-gray-50"
            >
              Export
            </button>
            <input
              v-model="searchQuery"
              type="text"
              placeholder="Search interests..."
              class="px-4 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 text-sm"
            />
          </div>
        </div>

        <!-- Stats -->
        <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4 mb-6">
          <div class="bg-white overflow-hidden shadow rounded-lg">
            <div class="px-4 py-5 sm:p-6">
              <div class="flex items-center">
                <div class="flex-shrink-0 bg-indigo-500 rounded-md p-3">
                  <svg class="h-6 w-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
                  </svg>
                </div>
                <div class="ml-5 w-0 flex-1">
                  <dl>
                    <dt class="text-sm font-medium text-gray-500 truncate">
                      Total Interests
                    </dt>
                    <dd class="flex items-baseline">
                      <div class="text-2xl font-semibold text-gray-900">
                        {{ stats.totalInterests }}
                      </div>
                    </dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>

          <div class="bg-white overflow-hidden shadow rounded-lg">
            <div class="px-4 py-5 sm:p-6">
              <div class="flex items-center">
                <div class="flex-shrink-0 bg-green-500 rounded-md p-3">
                  <svg class="h-6 w-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
                  </svg>
                </div>
                <div class="ml-5 w-0 flex-1">
                  <dl>
                    <dt class="text-sm font-medium text-gray-500 truncate">
                      Total Followers
                    </dt>
                    <dd class="flex items-baseline">
                      <div class="text-2xl font-semibold text-gray-900">
                        {{ stats.totalFollowers }}
                      </div>
                    </dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>

          <div class="bg-white overflow-hidden shadow rounded-lg">
            <div class="px-4 py-5 sm:p-6">
              <div class="flex items-center">
                <div class="flex-shrink-0 bg-blue-500 rounded-md p-3">
                  <svg class="h-6 w-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 20H5a2 2 0 01-2-2V6a2 2 0 012-2h10a2 2 0 012 2v1m2 13a2 2 0 01-2-2V7m2 13a2 2 0 002-2V9a2 2 0 00-2-2h-2m-4-3H9M7 16h6M7 8h6v4H7V8z" />
                  </svg>
                </div>
                <div class="ml-5 w-0 flex-1">
                  <dl>
                    <dt class="text-sm font-medium text-gray-500 truncate">
                      Total Posts
                    </dt>
                    <dd class="flex items-baseline">
                      <div class="text-2xl font-semibold text-gray-900">
                        {{ stats.totalPosts }}
                      </div>
                    </dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>

          <div class="bg-white overflow-hidden shadow rounded-lg">
            <div class="px-4 py-5 sm:p-6">
              <div class="flex items-center">
                <div class="flex-shrink-0 bg-yellow-500 rounded-md p-3">
                  <svg class="h-6 w-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6" />
                  </svg>
                </div>
                <div class="ml-5 w-0 flex-1">
                  <dl>
                    <dt class="text-sm font-medium text-gray-500 truncate">
                      Weekly Growth
                    </dt>
                    <dd class="flex items-baseline">
                      <div class="text-2xl font-semibold text-gray-900">
                        {{ stats.weeklyGrowth }}%
                      </div>
                      <div :class="[stats.weeklyGrowth >= 0 ? 'text-green-600' : 'text-red-600', 'ml-2 flex items-baseline text-sm font-semibold']">
                        <span v-if="stats.weeklyGrowth >= 0">+</span>{{ stats.weeklyGrowth }}%
                        <svg :class="stats.weeklyGrowth >= 0 ? 'text-green-500' : 'text-red-500', 'ml-1 h-4 w-4'" fill="currentColor" viewBox="0 0 20 20" aria-hidden="true">
                          <path fill-rule="evenodd" d="M5.293 9.707a1 1 0 010-1.414l4-4a1 1 0 011.414 0l4 4a1 1 0 01-1.414 1.414L11 7.414V15a1 1 0 11-2 0V7.414L6.707 9.707a1 1 0 01-1.414 0z" clip-rule="evenodd" />
                        </svg>
                      </div>
                    </dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Main Content -->
        <div class="bg-white shadow overflow-hidden sm:rounded-lg">
          <div class="px-4 py-5 sm:px-6 flex justify-between items-center">
            <h3 class="text-lg leading-6 font-medium text-gray-900">
              Interest Hierarchy
            </h3>
            <div class="flex items-center space-x-2">
              <div class="text-sm text-gray-500">
                Showing {{ filteredInterests.length }} of {{ interests.length }} interests
              </div>
              <select
                v-model="sortBy"
                class="mt-1 block pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md"
              >
                <option value="name">Name (A-Z)</option>
                <option value="postCount">Post Count</option>
                <option value="followerCount">Follower Count</option>
                <option value="level">Level</option>
              </select>
            </div>
          </div>
          
          <div class="border-t border-gray-200">
            <div v-if="loading" class="text-center py-12">
              <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600"></div>
              <p class="mt-2 text-gray-500">Loading interests...</p>
            </div>
            
            <div v-else-if="filteredInterests.length === 0" class="text-center py-12">
              <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1" d="M9.172 16.172a4 4 0 015.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <h3 class="mt-2 text-sm font-medium text-gray-900">No interests found</h3>
              <p class="mt-1 text-sm text-gray-500">
                Get started by creating a new interest.
              </p>
              <div class="mt-6">
                <button
                  @click="openCreateModal"
                  class="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                >
                  <svg class="-ml-1 mr-2 h-5 w-5" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                    <path fill-rule="evenodd" d="M10 5a1 1 0 011 1v3h3a1 1 0 110 2h-3v3a1 1 0 11-2 0v-3H6a1 1 0 110-2h3V6a1 1 0 011-1z" clip-rule="evenodd" />
                  </svg>
                  New Interest
                </button>
              </div>
            </div>
            
            <ul v-else class="divide-y divide-gray-200">
              <li v-for="interest in sortedInterests" :key="interest.id">
                <div class="px-4 py-4 sm:px-6">
                  <div class="flex items-center justify-between">
                    <div class="flex items-center">
                      <div 
                        class="flex-shrink-0 h-10 w-10 rounded-full bg-indigo-100 flex items-center justify-center"
                        :style="{ marginLeft: `${interest.level * 1.5}rem` }"
                      >
                        <svg class="h-6 w-6 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z" />
                        </svg>
                      </div>
                      <div class="ml-4">
                        <div class="flex items-center">
                          <p class="text-sm font-medium text-indigo-600 truncate">
                            {{ interest.displayName }}
                          </p>
                          <span v-if="!interest.isActive" class="ml-2 inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
                            Inactive
                          </span>
                        </div>
                        <div class="mt-1 flex items-center text-sm text-gray-500">
                          <span class="truncate">
                            {{ Array.isArray(interest.path) ? interest.path.join(' > ') : '' }}
                          </span>
                        </div>
                      </div>
                    </div>
                    <div class="ml-2 flex-shrink-0 flex">
                      <div class="flex items-center space-x-4">
                        <div class="text-sm text-gray-500">
                          <span class="font-medium text-gray-900">{{ interest.postCount || 0 }}</span> posts
                        </div>
                        <div class="text-sm text-gray-500">
                          <span class="font-medium text-gray-900">{{ interest.followerCount || 0 }}</span> followers
                        </div>
                        <div class="flex space-x-2">
                          <button
                            @click="openEditModal(interest)"
                            class="text-indigo-600 hover:text-indigo-900"
                            title="Edit"
                          >
                            <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                            </svg>
                          </button>
                          <button
                            @click="confirmDelete(interest)"
                            class="text-red-600 hover:text-red-900"
                            title="Delete"
                          >
                            <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                            </svg>
                          </button>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </li>
            </ul>
            
            <!-- Pagination -->
            <div v-if="totalPages > 1" class="bg-white px-4 py-3 flex items-center justify-between border-t border-gray-200 sm:px-6">
              <div class="flex-1 flex justify-between sm:hidden">
                <button
                  @click="currentPage--"
                  :disabled="currentPage === 1"
                  class="relative inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
                >
                  Previous
                </button>
                <button
                  @click="currentPage++"
                  :disabled="currentPage === totalPages"
                  class="ml-3 relative inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50"
                >
                  Next
                </button>
              </div>
              <div class="hidden sm:flex-1 sm:flex sm:items-center sm:justify-between">
                <div>
                  <p class="text-sm text-gray-700">
                    Showing <span class="font-medium">{{ (currentPage - 1) * pageSize + 1 }}</span>
                    to <span class="font-medium">{{ Math.min(currentPage * pageSize, filteredInterests.length) }}</span>
                    of <span class="font-medium">{{ filteredInterests.length }}</span> results
                  </p>
                </div>
                <div>
                  <nav class="relative z-0 inline-flex rounded-md shadow-sm -space-x-px" aria-label="Pagination">
                    <button
                      @click="currentPage--"
                      :disabled="currentPage === 1"
                      :class="[currentPage === 1 ? 'opacity-50 cursor-not-allowed' : 'hover:bg-gray-50', 'relative inline-flex items-center px-2 py-2 rounded-l-md border border-gray-300 bg-white text-sm font-medium text-gray-500']"
                    >
                      <span class="sr-only">Previous</span>
                      <svg class="h-5 w-5" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                        <path fill-rule="evenodd" d="M12.707 5.293a1 1 0 010 1.414L9.414 10l3.293 3.293a1 1 0 01-1.414 1.414l-4-4a1 1 0 010-1.414l4-4a1 1 0 011.414 0z" clip-rule="evenodd" />
                      </svg>
                    </button>
                    <button
                      v-for="page in visiblePages"
                      :key="page"
                      @click="currentPage = page"
                      :aria-current="currentPage === page ? 'page' : undefined"
                      :class="[currentPage === page ? 'z-10 bg-indigo-50 border-indigo-500 text-indigo-600' : 'bg-white border-gray-300 text-gray-500 hover:bg-gray-50', 'relative inline-flex items-center px-4 py-2 border text-sm font-medium']"
                    >
                      {{ page }}
                    </button>
                    <button
                      @click="currentPage++"
                      :disabled="currentPage === totalPages"
                      :class="[currentPage === totalPages ? 'opacity-50 cursor-not-allowed' : 'hover:bg-gray-50', 'relative inline-flex items-center px-2 py-2 rounded-r-md border border-gray-300 bg-white text-sm font-medium text-gray-500']"
                    >
                      <span class="sr-only">Next</span>
                      <svg class="h-5 w-5" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                        <path fill-rule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clip-rule="evenodd" />
                      </svg>
                    </button>
                  </nav>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </main>

    <!-- Create/Edit Interest Modal -->
    <InterestFormModal
      :show="showInterestModal"
      :interest="currentInterest"
      :parentInterests="parentInterests"
      :mode="modalMode"
      @close="closeModal"
      @saved="handleInterestSaved"
    />

    <!-- Delete Confirmation Modal -->
    <ConfirmationModal
      :show="showDeleteModal"
      title="Delete Interest"
      :message="`Are you sure you want to delete '${currentInterest?.displayName}'? This action cannot be undone.`"
      confirmText="Delete"
      variant="danger"
      @confirm="deleteInterest"
      @cancel="showDeleteModal = false"
    >
      <div v-if="currentInterest" class="mt-4 bg-yellow-50 border-l-4 border-yellow-400 p-4">
        <div class="flex">
          <div class="flex-shrink-0">
            <svg class="h-5 w-5 text-yellow-400" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
            </svg>
          </div>
          <div class="ml-3">
            <h3 class="text-sm font-medium text-yellow-800">Warning</h3>
            <div class="mt-2 text-sm text-yellow-700">
              <p v-if="(currentInterest.postCount || 0) > 0 || (currentInterest.followerCount || 0) > 0">
                This interest has {{ currentInterest.postCount || 0 }} posts and {{ currentInterest.followerCount || 0 }} followers.
                Consider deactivating it instead of deleting to preserve content and user preferences.
              </p>
              <p v-else>
                This action cannot be undone.
              </p>
            </div>
          </div>
        </div>
      </div>
    </ConfirmationModal>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useRouter } from 'vue-router';
import AppHeader from '../components/AppHeader.vue';
import InterestFormModal from '../components/InterestFormModal.vue';
import ConfirmationModal from '../components/ConfirmationModal.vue';
import * as interestService from '../src/services/interestService';
import { useToast } from 'vue-toastification';

// State
const loading = ref(true);
const searchQuery = ref('');
const sortBy = ref('name');
const currentPage = ref(1);
const pageSize = 20;
const showInterestModal = ref(false);
const showDeleteModal = ref(false);
const modalMode = ref('create');
const currentInterest = ref(null);

// State
const interests = ref([]);
const toast = useToast();

// Computed properties
const filteredInterests = computed(() => {
  if (!Array.isArray(interests.value)) return [];
  
  if (!searchQuery.value) return interests.value;
  
  const query = searchQuery.value.toLowerCase();
  return interests.value.filter(interest => {
    if (!interest) return false;
    
    const nameMatch = interest.name?.toLowerCase().includes(query) || false;
    const displayNameMatch = interest.displayName?.toLowerCase().includes(query) || false;
    const keywordsMatch = Array.isArray(interest.keywords) 
      ? interest.keywords.some(kw => kw?.toLowerCase().includes(query))
      : false;
    const synonymsMatch = Array.isArray(interest.synonyms)
      ? interest.synonyms.some(syn => syn?.toLowerCase().includes(query))
      : false;
      
    return nameMatch || displayNameMatch || keywordsMatch || synonymsMatch;
  });
});

const sortedInterests = computed(() => {
  const sorted = [...filteredInterests.value].filter(item => item != null);
  
  switch (sortBy.value) {
    case 'name':
      sorted.sort((a, b) => (a?.displayName || '').localeCompare(b?.displayName || ''));
      break;
    case 'postCount':
      sorted.sort((a, b) => (b?.postCount || 0) - (a?.postCount || 0));
      break;
    case 'followerCount':
      sorted.sort((a, b) => (b?.followerCount || 0) - (a?.followerCount || 0));
      break;
    case 'level':
      sorted.sort((a, b) => (a?.level || 0) - (b?.level || 0) || (a?.displayName || '').localeCompare(b?.displayName || ''));
      break;
  }
  
  return sorted;
});

const totalPages = computed(() => Math.ceil(filteredInterests.value.length / pageSize));

const visiblePages = computed(() => {
  const pages = [];
  const maxVisiblePages = 5;
  
  if (totalPages.value <= maxVisiblePages) {
    for (let i = 1; i <= totalPages.value; i++) {
      pages.push(i);
    }
  } else {
    let startPage = Math.max(1, currentPage.value - Math.floor(maxVisiblePages / 2));
    let endPage = startPage + maxVisiblePages - 1;
    
    if (endPage > totalPages.value) {
      endPage = totalPages.value;
      startPage = Math.max(1, endPage - maxVisiblePages + 1);
    }
    
    for (let i = startPage; i <= endPage; i++) {
      pages.push(i);
    }
  }
  
  return pages;
});

const parentInterests = computed(() => {
  if (!Array.isArray(interests.value)) return [];
  
  return interests.value
    .filter(interest => interest && interest.isActive)
    .map(interest => ({
      id: interest.id,
      name: interest.displayName || '',
      level: interest.level || 0,
      path: Array.isArray(interest.path) ? interest.path.join(' > ') : ''
    }));
});

const stats = computed(() => {
  const interestsArray = Array.isArray(interests.value) ? interests.value : [];
  
  return {
    totalInterests: interestsArray.length,
    totalPosts: interestsArray.reduce((sum, interest) => sum + (interest?.postCount || 0), 0),
    totalFollowers: interestsArray.reduce((sum, interest) => sum + (interest?.followerCount || 0), 0),
    weeklyGrowth: 2.5 // This would be calculated from actual data
  };
});

// Methods
const openCreateModal = () => {
  currentInterest.value = {
    id: null,
    name: '',
    displayName: '',
    parentId: null,
    description: '',
    isActive: true,
    keywords: [],
    synonyms: [],
    relatedInterestIds: [],
    postCount: 0,
    followerCount: 0,
    level: 0,
    path: []
  };
  modalMode.value = 'create';
  showInterestModal.value = true;
};

const openEditModal = (interest) => {
  currentInterest.value = { 
    id: interest.id || null,
    name: interest.name || '',
    displayName: interest.displayName || '',
    parentId: interest.parentId || null,
    description: interest.description || '',
    isActive: interest.isActive !== undefined ? interest.isActive : true,
    keywords: Array.isArray(interest.keywords) ? [...interest.keywords] : [],
    synonyms: Array.isArray(interest.synonyms) ? [...interest.synonyms] : [],
    relatedInterestIds: Array.isArray(interest.relatedInterestIds) ? [...interest.relatedInterestIds] : [],
    postCount: interest.postCount || 0,
    followerCount: interest.followerCount || 0,
    level: interest.level || 0,
    path: Array.isArray(interest.path) ? [...interest.path] : []
  };
  modalMode.value = 'edit';
  showInterestModal.value = true;
};

const closeModal = () => {
  showInterestModal.value = false;
  showDeleteModal.value = false;
  currentInterest.value = null;
};

const handleInterestSaved = async (formData) => {
  try {
    let savedInterest;
    
    if (modalMode.value === 'create') {
      savedInterest = await interestService.createInterest(formData);
      interests.value.push(savedInterest);
      toast.success('Interest created successfully');
    } else {
      const { id, ...updates } = formData;
      savedInterest = await interestService.updateInterest(id, updates);
      
      const index = interests.value.findIndex(i => i.id === savedInterest.id);
      if (index !== -1) {
        interests.value[index] = savedInterest;
      }
      
      toast.success('Interest updated successfully');
    }
    
    closeModal();
  } catch (error) {
    console.error('Error saving interest:', error);
    toast.error(`Failed to save interest: ${error.response?.data?.message || error.message}`);
  }
};

const confirmDelete = (interest) => {
  currentInterest.value = { ...interest };
  showDeleteModal.value = true;
};

const deleteInterest = async () => {
  if (!currentInterest.value) return;
  
  try {
    await interestService.deleteInterest(currentInterest.value.id);
    
    // Update local state
    const index = interests.value.findIndex(i => i.id === currentInterest.value.id);
    if (index !== -1) {
      interests.value.splice(index, 1);
    }
    
    toast.success(`Interest "${currentInterest.value.displayName}" deleted successfully`);
    showDeleteModal.value = false;
    currentInterest.value = null;
  } catch (error) {
    console.error('Failed to delete interest:', error);
    toast.error(`Failed to delete interest: ${error.response?.data?.message || error.message}`);
  }
};

const exportTaxonomy = async () => {
  try {
    const blob = await interestService.exportInterests();
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `interest-taxonomy-${new Date().toISOString().split('T')[0]}.csv`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
    
    toast.success('Interest taxonomy exported successfully');
  } catch (error) {
    console.error('Error exporting interests:', error);
    toast.error(`Failed to export interests: ${error.response?.data?.message || error.message}`);
  }
};

// Lifecycle hooks
onMounted(async () => {
  await fetchInterests();
});

// Methods
const fetchInterests = async () => {
  try {
    loading.value = true;
    const response = await interestService.getInterests({
      includeStats: true,
      includeInactive: true
    });
    interests.value = response.data;
    loading.value = false;
  } catch (error) {
    console.error('Failed to fetch interests:', error);
    toast.error('Failed to load interests. Please try again.');
    loading.value = false;
  }
};

// Watchers
watch([currentPage, searchQuery], () => {
  currentPage.value = 1; // Reset to first page when search query changes
});
</script>
