<template>
  <div class="min-h-screen bg-gray-50">
    <AppHeader />
    
    <main class="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
      <div class="px-4 py-6 sm:px-0">
        <div class="flex justify-between items-center mb-6">
          <h2 class="text-2xl font-bold text-gray-900">Announcements</h2>
          <button 
            @click="showComposer = true" 
            class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700"
          >
            Create Announcement
          </button>
        </div>

        <AnnouncementComposer
          v-if="showComposer"
          :announcement="editingAnnouncement"
          @close="handleComposerClose"
          @created="handleAnnouncementCreated"
          @updated="handleAnnouncementUpdated"
        />

        <div v-if="!showComposer">
          <div class="mb-4">
            <select 
              v-model="statusFilter" 
              @change="loadAnnouncements"
              class="px-4 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
            >
              <option value="">All Statuses</option>
              <option value="draft">Draft</option>
              <option value="active">Active</option>
              <option value="archived">Archived</option>
            </select>
          </div>

          <div v-if="loading" class="text-center py-12">
            <p class="text-gray-500">Loading announcements...</p>
          </div>
          <div v-else-if="announcements.length === 0" class="text-center py-12">
            <p class="text-gray-500">No announcements found</p>
          </div>
          <div v-else class="bg-white shadow overflow-hidden sm:rounded-md">
            <ul class="divide-y divide-gray-200">
              <li v-for="announcement in announcements" :key="announcement.id">
                <div class="px-4 py-4 sm:px-6">
                  <div class="flex items-center justify-between">
                    <div class="flex-1 min-w-0">
                      <div class="flex items-center justify-between mb-2">
                        <h3 class="text-lg font-medium text-gray-900 truncate">{{ announcement.title }}</h3>
                        <span :class="`ml-2 status-badge status-${announcement.status}`">
                          {{ announcement.status }}
                        </span>
                      </div>
                      <div v-if="announcement.pages && announcement.pages.length > 0" class="text-sm text-gray-600 mb-3">
                        <p>{{ announcement.pages.length }} page(s)</p>
                      </div>
                      <div class="flex flex-wrap gap-4 text-sm text-gray-500 mb-3">
                        <div v-if="announcement.createdAt">
                          Created: <span class="font-medium text-gray-700">{{ formatDate(announcement.createdAt) }}</span>
                        </div>
                        <div v-if="announcement.updatedAt">
                          Updated: <span class="font-medium text-gray-700">{{ formatDate(announcement.updatedAt) }}</span>
                        </div>
                      </div>
                      <div v-if="announcement.stats" class="flex flex-wrap gap-4 pt-3 border-t border-gray-200 text-sm">
                        <div class="text-gray-600">Views: <span class="font-medium text-gray-900">{{ announcement.stats.totalViews || 0 }}</span></div>
                        <div class="text-gray-600">Recipients: <span class="font-medium text-gray-900">{{ announcement.stats.totalRecipients || 0 }}</span></div>
                      </div>
                    </div>
                    <div class="ml-4 flex-shrink-0 flex gap-2">
                      <button
                        @click="handleEdit(announcement)"
                        class="inline-flex items-center px-3 py-2 border border-gray-300 text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                      >
                        Edit
                      </button>
                      <button
                        @click="handleDelete(announcement.id)"
                        class="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-white bg-red-600 hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500"
                      >
                        Delete
                      </button>
                    </div>
                  </div>
                </div>
              </li>
            </ul>
          </div>
        </div>
      </div>
    </main>
  </div>
</template>

<script>
import { ref, onMounted } from 'vue';
import { announcementService } from '../composables/announcementService';
import AnnouncementComposer from '../components/AnnouncementComposer.vue';
import AppHeader from '../components/AppHeader.vue';

export default {
  name: 'Announcements',
  components: {
    AnnouncementComposer,
    AppHeader
  },
  setup() {
    const showComposer = ref(false);
    const editingAnnouncement = ref(null);
    const announcements = ref([]);
    const loading = ref(false);
    const statusFilter = ref('');

    const loadAnnouncements = async () => {
      loading.value = true;
      try {
        const response = await announcementService.getAnnouncements(statusFilter.value || null);
        announcements.value = response.announcements || [];
      } catch (error) {
        console.error('Error loading announcements:', error);
        alert('Failed to load announcements');
      } finally {
        loading.value = false;
      }
    };

    const handleComposerClose = () => {
      showComposer.value = false;
      editingAnnouncement.value = null;
    };

    const handleAnnouncementCreated = () => {
      showComposer.value = false;
      loadAnnouncements();
    };

    const handleAnnouncementUpdated = () => {
      showComposer.value = false;
      editingAnnouncement.value = null;
      loadAnnouncements();
    };

    const handleEdit = (announcement) => {
      editingAnnouncement.value = announcement;
      showComposer.value = true;
    };

    const handleDelete = async (announcementId) => {
      if (!confirm('Are you sure you want to delete this announcement?')) {
        return;
      }

      try {
        await announcementService.deleteAnnouncement(announcementId);
        await loadAnnouncements();
      } catch (error) {
        console.error('Error deleting announcement:', error);
        alert('Failed to delete announcement: ' + (error.response?.data?.message || error.message));
      }
    };

    const formatDate = (timestamp) => {
      if (!timestamp) return '';
      const date = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
      return date.toLocaleString();
    };

    onMounted(() => {
      loadAnnouncements();
    });

    return {
      showComposer,
      editingAnnouncement,
      announcements,
      loading,
      statusFilter,
      loadAnnouncements,
      handleComposerClose,
      handleAnnouncementCreated,
      handleAnnouncementUpdated,
      handleEdit,
      handleDelete,
      formatDate
    };
  }
};
</script>

<style scoped>
.status-badge {
  padding: 0.25rem 0.75rem;
  border-radius: 12px;
  font-size: 0.75rem;
  font-weight: 600;
  text-transform: uppercase;
}

.status-draft { 
  background: #f3f4f6; 
  color: #6b7280; 
}

.status-active { 
  background: #d1fae5; 
  color: #065f46; 
}

.status-archived { 
  background: #fee2e2; 
  color: #991b1b; 
}
</style>
