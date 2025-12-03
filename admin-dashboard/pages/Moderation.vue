<template>
  <div class="min-h-screen bg-gray-50">
    <AppHeader />
    
    <main class="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
      <div class="px-4 py-6 sm:px-0">
        <!-- Tabs -->
        <div class="border-b border-gray-200 mb-6">
          <nav class="-mb-px flex space-x-8">
            <button
              @click="activeTab = 'posts'"
              :class="[
                'whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm',
                activeTab === 'posts'
                  ? 'border-indigo-500 text-indigo-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              ]"
            >
              Post Moderation
            </button>
            <button
              @click="activeTab = 'appeals'"
              :class="[
                'whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm',
                activeTab === 'appeals'
                  ? 'border-indigo-500 text-indigo-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              ]"
            >
              Ban Appeals
            </button>
          </nav>
        </div>

        <!-- Posts Tab -->
        <div v-if="activeTab === 'posts'">
          <div class="flex justify-between items-center mb-6">
            <h2 class="text-2xl font-bold text-gray-900">Moderation Queue</h2>
            <div class="flex items-center space-x-4">
              <select
                v-model="statusFilter"
                @change="fetchQueue"
                class="px-4 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
              >
                <option value="pending">Pending</option>
                <option value="flagged">Flagged</option>
                <option value="all">All</option>
              </select>
            </div>
          </div>
          
          <div v-if="loading" class="text-center py-12">
            <p class="text-gray-500">Loading moderation queue...</p>
          </div>
          
          <div v-else-if="posts.length === 0" class="text-center py-12">
            <p class="text-gray-500">No posts in moderation queue.</p>
          </div>
          
          <div v-else class="space-y-4">
            <PostModerationCard
              v-for="post in posts"
              :key="post.id"
              :post="post"
              @approve="handleApprove"
              @reject="handleReject"
              @flag="handleFlag"
            />
          </div>
        </div>

        <!-- Appeals Tab -->
        <div v-if="activeTab === 'appeals'">
          <div class="flex justify-between items-center mb-6">
            <h2 class="text-2xl font-bold text-gray-900">Ban Appeals</h2>
            <div class="flex items-center space-x-4">
              <select
                v-model="appealStatusFilter"
                @change="fetchAppeals"
                class="px-4 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
              >
                <option value="">All</option>
                <option value="pending">Pending</option>
                <option value="approved">Approved</option>
                <option value="rejected">Rejected</option>
              </select>
            </div>
          </div>
          
          <div v-if="appealsLoading" class="text-center py-12">
            <p class="text-gray-500">Loading appeals...</p>
          </div>
          
          <div v-else-if="appeals.length === 0" class="text-center py-12">
            <p class="text-gray-500">No ban appeals found.</p>
          </div>
          
          <div v-else class="space-y-4">
            <div
              v-for="appeal in appeals"
              :key="appeal.id"
              class="bg-white shadow rounded-lg p-6"
            >
              <div class="flex justify-between items-start mb-4">
                <div>
                  <p class="text-sm text-gray-500">User ID: {{ appeal.userId }}</p>
                  <p class="text-sm text-gray-500">
                    Submitted: {{ formatDate(appeal.submittedAt) }}
                  </p>
                  <span
                    :class="[
                      'inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium mt-2',
                      appeal.status === 'pending' ? 'bg-yellow-100 text-yellow-800' :
                      appeal.status === 'approved' ? 'bg-green-100 text-green-800' :
                      'bg-red-100 text-red-800'
                    ]"
                  >
                    {{ appeal.status }}
                  </span>
                </div>
                <div v-if="appeal.status === 'pending'" class="flex space-x-2">
                  <button
                    @click="handleApproveAppeal(appeal.id)"
                    class="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700"
                  >
                    Approve
                  </button>
                  <button
                    @click="handleRejectAppeal(appeal.id)"
                    class="px-4 py-2 bg-red-600 text-white rounded-md hover:bg-red-700"
                  >
                    Reject
                  </button>
                </div>
              </div>
              
              <div class="mb-4">
                <p class="text-sm font-medium text-gray-700 mb-2">Appeal Reason:</p>
                <p class="text-sm text-gray-900 bg-gray-50 p-3 rounded">{{ appeal.reason }}</p>
              </div>
              
              <div v-if="appeal.reviewedAt" class="mt-4 pt-4 border-t border-gray-200">
                <p class="text-sm text-gray-500">
                  Reviewed: {{ formatDate(appeal.reviewedAt) }}
                </p>
                <p v-if="appeal.reviewNotes" class="text-sm text-gray-700 mt-2">
                  Notes: {{ appeal.reviewNotes }}
                </p>
              </div>
              
              <div v-if="showReviewNotes[appeal.id]" class="mt-4">
                <textarea
                  v-model="reviewNotes[appeal.id]"
                  placeholder="Review notes (optional)"
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
                  rows="3"
                ></textarea>
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
import PostModerationCard from '../components/PostModerationCard.vue';

const posts = ref([]);
const loading = ref(true);
const statusFilter = ref('pending');
const activeTab = ref('posts');

const appeals = ref([]);
const appealsLoading = ref(false);
const appealStatusFilter = ref('');
const reviewNotes = ref({});
const showReviewNotes = ref({});

async function fetchQueue() {
  loading.value = true;
  try {
    const statusParam = statusFilter.value === 'all' ? '' : `status=${statusFilter.value}`;
    const response = await api.get(`/api/admin/moderation/queue?${statusParam}`);
    const data = response.data;
    posts.value = data.posts;
  } catch (err) {
    console.error('Error fetching queue:', err);
    alert('Failed to load moderation queue');
  } finally {
    loading.value = false;
  }
}

async function handleApprove(post) {
  try {
    await api.post('/api/admin/moderation/approve', { postId: post.id });
    // Remove from queue
    posts.value = posts.value.filter(p => p.id !== post.id);
    alert('Post approved');
  } catch (err) {
    console.error('Error approving post:', err);
    alert('Failed to approve post');
  }
}

async function handleReject(post) {
  if (!confirm('Are you sure you want to reject this post?')) {
    return;
  }
  try {
    await api.post('/api/admin/moderation/reject', { postId: post.id });
    // Remove from queue
    posts.value = posts.value.filter(p => p.id !== post.id);
    alert('Post rejected');
  } catch (err) {
    console.error('Error rejecting post:', err);
    alert('Failed to reject post');
  }
}

const handleFlag = async (postId) => {
  try {
    await api.post('/api/admin/moderation/flag', { postId });
    const post = posts.value.find(p => p.id === postId);
    if (post) {
      post.moderationStatus = 'flagged';
    }
    alert('Post flagged');
  } catch (error) {
    console.error('Error flagging post:', error);
    alert('Failed to flag post');
  }
};

const fetchAppeals = async () => {
  try {
    appealsLoading.value = true;
    const params = {};
    if (appealStatusFilter.value) {
      params.status = appealStatusFilter.value;
    }
    const response = await api.get('/api/admin/appeals', { params });
    appeals.value = response.data.appeals || [];
  } catch (error) {
    console.error('Error fetching appeals:', error);
    alert('Failed to load appeals');
  } finally {
    appealsLoading.value = false;
  }
};

const handleApproveAppeal = async (appealId) => {
  if (!confirm('Are you sure you want to approve this appeal? This will unban the user.')) {
    return;
  }
  try {
    await api.post(`/api/admin/appeals/${appealId}/review`, {
      status: 'approved',
      reviewNotes: reviewNotes.value[appealId] || null
    });
    await fetchAppeals();
    alert('Appeal approved and user unbanned');
  } catch (error) {
    console.error('Error approving appeal:', error);
    alert('Failed to approve appeal');
  }
};

const handleRejectAppeal = async (appealId) => {
  if (!confirm('Are you sure you want to reject this appeal?')) {
    return;
  }
  try {
    await api.post(`/api/admin/appeals/${appealId}/review`, {
      status: 'rejected',
      reviewNotes: reviewNotes.value[appealId] || null
    });
    await fetchAppeals();
    alert('Appeal rejected');
  } catch (error) {
    console.error('Error rejecting appeal:', error);
    alert('Failed to reject appeal');
  }
};

const formatDate = (timestamp) => {
  if (!timestamp) return 'N/A';
  const date = timestamp.toDate ? timestamp.toDate() : new Date(timestamp.seconds * 1000);
  return date.toLocaleString();
};

onMounted(() => {
  fetchQueue();
  fetchAppeals();
});
</script>

