<template>
  <div class="min-h-screen bg-gray-50">
    <AppHeader />
    
    <main class="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
      <div class="px-4 py-6 sm:px-0">
        <!-- Header -->
        <div class="flex justify-between items-center mb-6">
          <h2 class="text-2xl font-bold text-gray-900">User Management</h2>
          <div class="flex items-center space-x-4">
            <!-- View Toggle -->
            <div class="flex items-center space-x-2 border border-gray-300 rounded-md p-1">
              <button
                @click="viewMode = 'table'"
                :class="viewMode === 'table' ? 'bg-indigo-600 text-white' : 'text-gray-700'"
                class="px-3 py-1 rounded text-sm font-medium"
              >
                Table
              </button>
              <button
                @click="viewMode = 'cards'"
                :class="viewMode === 'cards' ? 'bg-indigo-600 text-white' : 'text-gray-700'"
                class="px-3 py-1 rounded text-sm font-medium"
              >
                Cards
              </button>
            </div>
            <!-- Export Button -->
            <button
              @click="handleExport"
              class="px-4 py-2 border border-gray-300 rounded-md text-sm font-medium text-gray-700 bg-white hover:bg-gray-50"
            >
              Export All
            </button>
          </div>
        </div>

        <!-- Filters -->
        <UserFilters
          :filters="filters"
          @update:filters="handleFiltersUpdate"
          @search="handleSearch"
        />

        <!-- Sorting and Pagination Controls -->
        <div class="mb-4 flex items-center justify-between">
          <div class="flex items-center space-x-4">
            <label class="text-sm font-medium text-gray-700">Sort by:</label>
            <select
              v-model="sortBy"
              @change="fetchUsers"
              class="px-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
            >
              <option value="createdAt">Joined Date</option>
              <option value="email">Email</option>
              <option value="displayName">Name</option>
              <option value="followerCount">Followers</option>
              <option value="postCount">Posts</option>
            </select>
            <select
              v-model="sortOrder"
              @change="fetchUsers"
              class="px-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
            >
              <option value="desc">Descending</option>
              <option value="asc">Ascending</option>
            </select>
          </div>
          <div class="flex items-center space-x-2">
            <label class="text-sm font-medium text-gray-700">Items per page:</label>
            <select
              v-model="limit"
              @change="handleLimitChange"
              class="px-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
            >
              <option value="25">25</option>
              <option value="50">50</option>
              <option value="100">100</option>
            </select>
          </div>
        </div>

        <!-- Loading State -->
        <div v-if="loading" class="text-center py-12">
          <p class="text-gray-500">Loading users...</p>
        </div>

        <!-- Empty State -->
        <div v-else-if="users.length === 0" class="text-center py-12">
          <p class="text-gray-500">No users found.</p>
        </div>

        <!-- Users List -->
        <div v-else>
          <!-- Table View -->
          <UserTable
            v-if="viewMode === 'table'"
            :users="users"
            :selected-users="selectedUsers"
            :sort-by="sortBy"
            :sort-order="sortOrder"
            @select="toggleSelect"
            @select-all="toggleSelectAll"
            @sort="handleSort"
            @view="handleViewUser"
            @ban="handleBan"
            @unban="handleUnban"
            @delete="handleDelete"
          />

          <!-- Card View -->
          <div v-else class="space-y-4">
            <UserCard
              v-for="user in users"
              :key="user.id"
              :user="user"
              @ban="handleBan"
              @unban="handleUnban"
              @delete="handleDelete"
              @view="handleViewUser"
            />
          </div>

          <!-- Pagination -->
          <div class="mt-6 flex items-center justify-between">
            <div class="text-sm text-gray-700">
              Showing {{ offset + 1 }} to {{ Math.min(offset + limit, total) }} of {{ total }} users
            </div>
            <div class="flex items-center space-x-2">
              <button
                @click="handlePreviousPage"
                :disabled="offset === 0 || loading"
                class="px-4 py-2 border border-gray-300 rounded-md text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Previous
              </button>
              <button
                @click="handleNextPage"
                :disabled="offset + limit >= total || loading"
                class="px-4 py-2 border border-gray-300 rounded-md text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                Next
              </button>
            </div>
          </div>
        </div>
      </div>
    </main>

    <!-- Bulk Actions Bar -->
    <BulkActionsBar
      :selected-count="selectedUsers.length"
      :processing="bulkProcessing"
      :processing-message="bulkProcessingMessage"
      @bulk-ban="handleBulkBan"
      @bulk-unban="handleBulkUnban"
      @bulk-export="handleBulkExport"
      @clear-selection="selectedUsers = []"
    />

    <!-- User Detail Modal -->
    <UserDetailModal
      v-if="selectedUserId"
      :user-id="selectedUserId"
      @close="selectedUserId = null"
      @updated="handleUserUpdated"
    />
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import api from '../services/api';
import AppHeader from '../components/AppHeader.vue';
import UserCard from '../components/UserCard.vue';
import UserTable from '../components/UserTable.vue';
import UserFilters from '../components/UserFilters.vue';
import BulkActionsBar from '../components/BulkActionsBar.vue';
import UserDetailModal from '../components/UserDetailModal.vue';

const users = ref([]);
const loading = ref(true);
const viewMode = ref('table');
const selectedUsers = ref([]);
const selectedUserId = ref(null);
const bulkProcessing = ref(false);
const bulkProcessingMessage = ref('');

const limit = ref(50);
const offset = ref(0);
const total = ref(0);
const sortBy = ref('createdAt');
const sortOrder = ref('desc');

const filters = ref({
  search: '',
  status: 'all',
  activityLevel: '',
  startDate: '',
  endDate: ''
});

const fetchUsers = async () => {
  try {
    loading.value = true;
    const params = {
      limit: limit.value,
      offset: offset.value,
      sortBy: sortBy.value,
      sortOrder: sortOrder.value,
      ...filters.value
    };

    // Remove empty filters
    Object.keys(params).forEach(key => {
      if (params[key] === '' || params[key] === null) {
        delete params[key];
      }
    });

    const response = await api.get('/api/admin/users', { params });
    users.value = response.data.users || [];
    total.value = response.data.total || 0;
  } catch (error) {
    console.error('Error fetching users:', error);
    alert('Failed to load users');
  } finally {
    loading.value = false;
  }
};

const handleFiltersUpdate = (newFilters) => {
  filters.value = { ...newFilters };
  offset.value = 0; // Reset to first page
  fetchUsers();
};

const handleSearch = (searchTerm) => {
  filters.value.search = searchTerm;
  offset.value = 0;
  fetchUsers();
};

const handleSort = (columnKey) => {
  if (sortBy.value === columnKey) {
    sortOrder.value = sortOrder.value === 'asc' ? 'desc' : 'asc';
  } else {
    sortBy.value = columnKey;
    sortOrder.value = 'desc';
  }
  fetchUsers();
};

const handleLimitChange = () => {
  offset.value = 0;
  fetchUsers();
};

const handlePreviousPage = () => {
  if (offset.value > 0) {
    offset.value = Math.max(0, offset.value - limit.value);
    fetchUsers();
  }
};

const handleNextPage = () => {
  if (offset.value + limit.value < total.value) {
    offset.value += limit.value;
    fetchUsers();
  }
};

const toggleSelect = (userId) => {
  const index = selectedUsers.value.indexOf(userId);
  if (index > -1) {
    selectedUsers.value.splice(index, 1);
  } else {
    selectedUsers.value.push(userId);
  }
};

const toggleSelectAll = () => {
  if (selectedUsers.value.length === users.value.length) {
    selectedUsers.value = [];
  } else {
    selectedUsers.value = users.value.map(u => u.id);
  }
};

const handleBan = async (userId, reason) => {
  if (!confirm('Are you sure you want to ban this user?')) {
    return;
  }
  try {
    await api.post('/api/admin/users/ban', { userId, reason });
    await fetchUsers();
    alert('User banned successfully');
  } catch (error) {
    console.error('Error banning user:', error);
    alert('Failed to ban user');
  }
};

const handleUnban = async (userId) => {
  if (!confirm('Are you sure you want to unban this user?')) {
    return;
  }
  try {
    await api.post('/api/admin/users/unban', { userId });
    await fetchUsers();
    alert('User unbanned successfully');
  } catch (error) {
    console.error('Error unbanning user:', error);
    alert('Failed to unban user');
  }
};

const handleDelete = async (userId) => {
  const user = users.value.find(u => u.id === userId);
  const userName = user?.displayName || user?.email || 'this user';
  
  if (!confirm(`Are you sure you want to DELETE ${userName}? This will permanently delete their account and ALL associated data. This action cannot be undone.`)) {
    return;
  }
  
  if (!confirm('This is your final warning. Are you absolutely sure you want to delete this user and all their data?')) {
    return;
  }
  
  try {
    await api.delete(`/api/admin/users/${userId}`);
    await fetchUsers();
    alert('User deleted successfully');
  } catch (error) {
    console.error('Error deleting user:', error);
    alert(error.response?.data?.message || 'Failed to delete user');
  }
};

const handleBulkBan = async () => {
  if (selectedUsers.value.length === 0) return;
  
  if (!confirm(`Are you sure you want to ban ${selectedUsers.value.length} user(s)?`)) {
    return;
  }
  
  try {
    bulkProcessing.value = true;
    bulkProcessingMessage.value = `Banning ${selectedUsers.value.length} users...`;
    
    const response = await api.post('/api/admin/users/bulk', {
      userIds: selectedUsers.value,
      action: 'ban'
    });
    
    bulkProcessingMessage.value = `Successfully banned ${response.data.successCount} users`;
    selectedUsers.value = [];
    await fetchUsers();
    
    setTimeout(() => {
      bulkProcessing.value = false;
      bulkProcessingMessage.value = '';
    }, 2000);
  } catch (error) {
    console.error('Error bulk banning users:', error);
    alert('Failed to ban users');
    bulkProcessing.value = false;
    bulkProcessingMessage.value = '';
  }
};

const handleBulkUnban = async () => {
  if (selectedUsers.value.length === 0) return;
  
  if (!confirm(`Are you sure you want to unban ${selectedUsers.value.length} user(s)?`)) {
    return;
  }
  
  try {
    bulkProcessing.value = true;
    bulkProcessingMessage.value = `Unbanning ${selectedUsers.value.length} users...`;
    
    const response = await api.post('/api/admin/users/bulk', {
      userIds: selectedUsers.value,
      action: 'unban'
    });
    
    bulkProcessingMessage.value = `Successfully unbanned ${response.data.successCount} users`;
    selectedUsers.value = [];
    await fetchUsers();
    
    setTimeout(() => {
      bulkProcessing.value = false;
      bulkProcessingMessage.value = '';
    }, 2000);
  } catch (error) {
    console.error('Error bulk unbanning users:', error);
    alert('Failed to unban users');
    bulkProcessing.value = false;
    bulkProcessingMessage.value = '';
  }
};

const handleBulkExport = async () => {
  if (selectedUsers.value.length === 0) return;
  
  try {
    // Export selected users
    const selectedUsersData = users.value.filter(u => selectedUsers.value.includes(u.id));
    const csv = convertToCSV(selectedUsersData);
    downloadCSV(csv, 'selected-users.csv');
    selectedUsers.value = [];
  } catch (error) {
    console.error('Error exporting users:', error);
    alert('Failed to export users');
  }
};

const handleExport = async () => {
  try {
    const params = {
      format: 'csv',
      ...filters.value
    };
    
    Object.keys(params).forEach(key => {
      if (params[key] === '' || params[key] === null) {
        delete params[key];
      }
    });
    
    const response = await api.get('/api/admin/users/export', {
      params,
      responseType: 'blob'
    });
    
    const url = window.URL.createObjectURL(new Blob([response.data]));
    const link = document.createElement('a');
    link.href = url;
    link.setAttribute('download', 'users-export.csv');
    document.body.appendChild(link);
    link.click();
    link.remove();
  } catch (error) {
    console.error('Error exporting users:', error);
    alert('Failed to export users');
  }
};

const convertToCSV = (data) => {
  if (data.length === 0) return '';
  
  const headers = ['id', 'email', 'username', 'displayName', 'isBanned', 'isAdmin', 'createdAt', 'postCount', 'followerCount'];
  const rows = data.map(user => [
    user.id,
    user.email || '',
    user.username || '',
    user.displayName || '',
    user.isBanned ? 'Yes' : 'No',
    user.isAdmin ? 'Yes' : 'No',
    user.createdAt ? new Date(user.createdAt).toISOString() : '',
    user.stats?.postCount || 0,
    user.stats?.followerCount || 0
  ]);
  
  return [
    headers.join(','),
    ...rows.map(row => row.map(cell => `"${String(cell).replace(/"/g, '""')}"`).join(','))
  ].join('\n');
};

const downloadCSV = (csv, filename) => {
  const blob = new Blob([csv], { type: 'text/csv' });
  const url = window.URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.setAttribute('download', filename);
  document.body.appendChild(link);
  link.click();
  link.remove();
};

const handleViewUser = (userId) => {
  selectedUserId.value = userId;
};

const handleUserUpdated = () => {
  fetchUsers();
};

onMounted(() => {
  fetchUsers();
});
</script>
