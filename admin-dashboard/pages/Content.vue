<template>
  <div class="min-h-screen bg-background">
    <AppHeader />
    
    <main class="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
      <div class="px-4 py-6 sm:px-0">
        <!-- Header -->
        <div class="flex justify-between items-center mb-6">
          <h2 class="text-2xl font-bold text-foreground">Content Management</h2>
          <div class="flex items-center space-x-4">
            <Button @click="bulkUploadModalOpen = true">
              <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
              </svg>
              Bulk Upload
            </Button>
            <Input
              v-model="searchQuery"
              type="text"
              placeholder="Search posts..."
              class="w-64"
            />
            <Button
              @click="viewMode = viewMode === 'list' ? 'grid' : 'list'"
              variant="outline"
            >
              {{ viewMode === 'list' ? 'Grid View' : 'List View' }}
            </Button>
          </div>
        </div>

        <!-- Filters -->
        <PostFilters
          :model-value="filters"
          @update:filters="handleFiltersUpdate"
        />

        <!-- Bulk Actions Toolbar -->
        <Card
          v-if="selectedPosts.length > 0"
          class="mb-6 bg-primary/5 border-primary"
        >
          <CardContent class="py-4">
            <div class="flex items-center justify-between">
              <p class="text-sm font-medium text-foreground">
                {{ selectedPosts.length }} post(s) selected
              </p>
              <div class="flex items-center space-x-2">
                <Button
                  v-if="canModerate"
                  @click="handleBulkAction('approve')"
                  :disabled="bulkActionLoading"
                  size="sm"
                  class="bg-green-600 hover:bg-green-700"
                >
                  Approve
                </Button>
                <Button
                  v-if="canModerate"
                  @click="handleBulkAction('reject')"
                  :disabled="bulkActionLoading"
                  size="sm"
                  variant="destructive"
                >
                  Reject
                </Button>
                <Button
                  v-if="canModerate"
                  @click="handleBulkAction('flag')"
                  :disabled="bulkActionLoading"
                  size="sm"
                  class="bg-yellow-600 hover:bg-yellow-700"
                >
                  Flag
                </Button>
                <Button
                  @click="handleBulkAction('delete')"
                  :disabled="bulkActionLoading"
                  size="sm"
                  variant="destructive"
                >
                  Delete
                </Button>
                <Button
                  @click="clearSelection"
                  variant="outline"
                  size="sm"
                >
                  Clear Selection
                </Button>
              </div>
            </div>
          </CardContent>
        </Card>

        <!-- Loading State -->
        <div v-if="loading" class="text-center py-12">
          <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
          <p class="mt-2 text-muted-foreground">Loading content...</p>
        </div>

        <!-- Empty State -->
        <div v-else-if="filteredPosts.length === 0" class="text-center py-12">
          <svg class="mx-auto h-12 w-12 text-muted-foreground" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
          </svg>
          <h3 class="mt-2 text-sm font-medium text-foreground">No posts found</h3>
          <p class="mt-1 text-sm text-muted-foreground">
            {{ searchQuery ? 'Try adjusting your search or filters.' : 'Get started by creating a new post.' }}
          </p>
        </div>

        <!-- Posts List/Grid -->
        <div v-else>
          <!-- Select All Header -->
          <div class="flex items-center justify-between mb-4 pb-3 border-b border-border">
            <div class="flex items-center space-x-3">
              <input
                ref="selectAllCheckbox"
                type="checkbox"
                :checked="allSelected"
                @change="handleSelectAll"
                class="h-4 w-4 text-primary focus:ring-ring border-input rounded cursor-pointer"
              />
              <label class="text-sm font-medium text-foreground cursor-pointer" @click="handleSelectAllClick">
                {{ allSelected ? 'Deselect All' : 'Select All' }}
                <span class="text-muted-foreground ml-1">({{ filteredPosts.length }} posts)</span>
              </label>
            </div>
            <div v-if="selectedPosts.length > 0" class="text-sm text-primary font-medium">
              {{ selectedPosts.length }} selected
            </div>
          </div>

          <div class="space-y-4">
            <div
              v-for="post in filteredPosts"
              :key="post.id"
              class="w-full"
            >
              <PostCard
                :post="post"
                :selectable="true"
                :selected="selectedPosts.includes(post.id)"
                @select="handlePostSelect"
                @view-details="handleViewDetails"
                @edit="handleEdit"
                @delete="handleDelete"
                @approve="handleApprove"
                @reject="handleReject"
                @flag="handleFlag"
              />
            </div>
          </div>
        </div>

        <!-- Pagination -->
        <div v-if="!loading && total > limit" class="mt-6 flex items-center justify-between">
          <div class="text-sm text-muted-foreground">
            Showing {{ offset + 1 }} to {{ Math.min(offset + limit, total) }} of {{ total }} posts
          </div>
          <div class="flex items-center space-x-2">
            <Button
              @click="loadPrevious"
              :disabled="offset === 0 || loading"
              variant="outline"
            >
              Previous
            </Button>
            <Button
              @click="loadNext"
              :disabled="offset + limit >= total || loading"
              variant="outline"
            >
              Next
            </Button>
          </div>
        </div>

        <!-- Modals -->
        <PostEditModal
          :is-open="editModalOpen"
          :post="postToEdit"
          @close="editModalOpen = false"
          @save="handleSaveEdit"
        />

        <PostDetailsModal
          :is-open="detailsModalOpen"
          :post-id="postIdToView"
          @close="detailsModalOpen = false"
          @edit="handleEditFromDetails"
        />

        <BulkUploadModal
          :is-open="bulkUploadModalOpen"
          @close="bulkUploadModalOpen = false"
          @uploaded="handleBulkUploadComplete"
        />
      </div>
    </main>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import api from '../services/api';
import AppHeader from '../components/AppHeader.vue';
import PostCard from '../components/PostCard.vue';
import PostEditModal from '../components/PostEditModal.vue';
import PostDetailsModal from '../components/PostDetailsModal.vue';
import PostFilters from '../components/PostFilters.vue';
import BulkUploadModal from '../components/BulkUploadModal.vue';
import Button from '@/components/ui/Button.vue';
import Input from '@/components/ui/Input.vue';
import Card from '@/components/ui/Card.vue';
import CardContent from '@/components/ui/CardContent.vue';
import { useAuthStore } from '../stores/auth';

const authStore = useAuthStore();

const posts = ref([]);
const loading = ref(true);
const loadingMore = ref(false);
const searchQuery = ref('');
const viewMode = ref('list');
const selectedPosts = ref([]);
const bulkActionLoading = ref(false);
const selectAllCheckbox = ref(null);

// Pagination
const limit = ref(50);
const offset = ref(0);
const total = ref(0);

// Filters
const filters = ref({
  status: 'all',
  sortBy: 'createdAt',
  sortOrder: 'desc',
  startDate: null,
  endDate: null,
  userId: '',
  tag: ''
});

// Modals
const editModalOpen = ref(false);
const detailsModalOpen = ref(false);
const bulkUploadModalOpen = ref(false);
const postToEdit = ref(null);
const postIdToView = ref(null);

const canModerate = computed(() => {
  const role = authStore.admin?.role;
  return role === 'super_admin' || role === 'moderator';
});

const filteredPosts = computed(() => {
  let result = posts.value;

  // Client-side search filter
  if (searchQuery.value) {
    const query = searchQuery.value.toLowerCase();
    result = result.filter(post => 
      (post.caption && post.caption.toLowerCase().includes(query)) ||
      (post.tags && post.tags.some(tag => tag.toLowerCase().includes(query))) ||
      (post.username && post.username.toLowerCase().includes(query))
    );
  }

  return result;
});

const allSelected = computed(() => {
  return filteredPosts.value.length > 0 && 
    filteredPosts.value.every(post => selectedPosts.value.includes(post.id));
});

const someSelected = computed(() => {
  const selectedCount = filteredPosts.value.filter(post => 
    selectedPosts.value.includes(post.id)
  ).length;
  return selectedCount > 0 && selectedCount < filteredPosts.value.length;
});

// Watch for indeterminate state changes
watch([someSelected, allSelected], () => {
  if (selectAllCheckbox.value) {
    selectAllCheckbox.value.indeterminate = someSelected.value;
  }
}, { immediate: true });

const fetchPosts = async () => {
  try {
    loading.value = true;
    
    const params = {
      limit: limit.value,
      offset: offset.value,
      sortBy: filters.value.sortBy,
      sortOrder: filters.value.sortOrder
    };

    if (filters.value.status && filters.value.status !== 'all') {
      params.status = filters.value.status;
    }

    if (filters.value.userId) {
      params.userId = filters.value.userId;
    }

    if (filters.value.tag) {
      params.tag = filters.value.tag;
    }

    if (filters.value.startDate) {
      params.startDate = new Date(filters.value.startDate).getTime().toString();
    }

    if (filters.value.endDate) {
      params.endDate = new Date(filters.value.endDate).getTime().toString();
    }

    const response = await api.get('/api/admin/posts', { params });
    posts.value = response.data.posts || [];
    total.value = response.data.total || 0;
  } catch (error) {
    console.error('Error fetching posts:', error);
    alert('Failed to load posts');
    posts.value = [];
  } finally {
    loading.value = false;
  }
};

const handleFiltersUpdate = (newFilters) => {
  filters.value = { ...newFilters };
  offset.value = 0; // Reset to first page
  fetchPosts();
};

const handlePostSelect = (postId, isSelected) => {
  if (isSelected) {
    if (!selectedPosts.value.includes(postId)) {
      selectedPosts.value.push(postId);
    }
  } else {
    selectedPosts.value = selectedPosts.value.filter(id => id !== postId);
  }
};

const handleSelectAll = (event) => {
  const shouldSelect = event.target.checked;
  
  if (shouldSelect) {
    // Select all filtered posts
    filteredPosts.value.forEach(post => {
      if (!selectedPosts.value.includes(post.id)) {
        selectedPosts.value.push(post.id);
      }
    });
  } else {
    // Deselect all filtered posts
    const filteredPostIds = filteredPosts.value.map(post => post.id);
    selectedPosts.value = selectedPosts.value.filter(id => !filteredPostIds.includes(id));
  }
};

const handleSelectAllClick = () => {
  if (selectAllCheckbox.value) {
    selectAllCheckbox.value.click();
  }
};

const clearSelection = () => {
  selectedPosts.value = [];
};

const handleBulkAction = async (action) => {
  if (selectedPosts.value.length === 0) return;

  let confirmMessage = '';
  switch (action) {
    case 'delete':
      confirmMessage = `Are you sure you want to delete ${selectedPosts.value.length} post(s)?`;
      break;
    case 'approve':
      confirmMessage = `Are you sure you want to approve ${selectedPosts.value.length} post(s)?`;
      break;
    case 'reject':
      confirmMessage = `Are you sure you want to reject ${selectedPosts.value.length} post(s)?`;
      break;
    case 'flag':
      confirmMessage = `Are you sure you want to flag ${selectedPosts.value.length} post(s)?`;
      break;
  }

  if (!confirm(confirmMessage)) {
    return;
  }

  try {
    bulkActionLoading.value = true;
    await api.post('/api/admin/posts/bulk', {
      postIds: selectedPosts.value,
      action: action
    });

    alert(`Successfully ${action}d ${selectedPosts.value.length} post(s)`);
    clearSelection();
    await fetchPosts();
  } catch (error) {
    console.error(`Error performing bulk ${action}:`, error);
    alert(`Failed to ${action} posts`);
  } finally {
    bulkActionLoading.value = false;
  }
};

const handleViewDetails = (postId) => {
  postIdToView.value = postId;
  detailsModalOpen.value = true;
};

const handleEdit = (postId) => {
  postToEdit.value = posts.value.find(p => p.id === postId);
  editModalOpen.value = true;
};

const handleEditFromDetails = (postId) => {
  detailsModalOpen.value = false;
  handleEdit(postId);
};

const handleSaveEdit = async (postId, updateData) => {
  try {
    await api.put(`/api/admin/posts/${postId}`, updateData);
    alert('Post updated successfully');
    editModalOpen.value = false;
    postToEdit.value = null;
    await fetchPosts();
  } catch (error) {
    console.error('Error updating post:', error);
    alert('Failed to update post');
  }
};

const handleApprove = async (postId) => {
  try {
    await api.post('/api/admin/moderation/approve', { postId });
    alert('Post approved');
    await fetchPosts();
  } catch (error) {
    console.error('Error approving post:', error);
    alert('Failed to approve post');
  }
};

const handleReject = async (postId) => {
  if (!confirm('Are you sure you want to reject this post?')) {
    return;
  }
  try {
    await api.post('/api/admin/moderation/reject', { postId });
    alert('Post rejected');
    await fetchPosts();
  } catch (error) {
    console.error('Error rejecting post:', error);
    alert('Failed to reject post');
  }
};

const handleFlag = async (postId) => {
  try {
    await api.post('/api/admin/moderation/flag', { postId });
    alert('Post flagged');
    await fetchPosts();
  } catch (error) {
    console.error('Error flagging post:', error);
    alert('Failed to flag post');
  }
};

const handleDelete = async (postId) => {
  if (!confirm('Are you sure you want to delete this post?')) {
    return;
  }
  try {
    await api.delete(`/api/admin/posts/${postId}`);
    alert('Post deleted');
    await fetchPosts();
  } catch (error) {
    console.error('Error deleting post:', error);
    alert('Failed to delete post');
  }
};

const loadNext = async () => {
  if (offset.value + limit.value >= total.value) return;
  offset.value += limit.value;
  await fetchPosts();
};

const loadPrevious = async () => {
  if (offset.value === 0) return;
  offset.value = Math.max(0, offset.value - limit.value);
  await fetchPosts();
};

const handleBulkUploadComplete = async (data) => {
  alert(`Successfully uploaded ${data.posts?.length || 0} post(s)`);
  await fetchPosts();
};

onMounted(() => {
  fetchPosts();
});
</script>
