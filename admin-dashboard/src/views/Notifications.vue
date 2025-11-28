<template>
  <div class="min-h-screen bg-gray-50">
    <AppHeader />
    
    <main class="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
      <div class="px-4 py-6 sm:px-0">
        <div class="flex justify-between items-center mb-6">
          <h2 class="text-2xl font-bold text-gray-900">Notifications</h2>
          <button 
            @click="showComposer = true" 
            class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700"
          >
            Create Notification
          </button>
        </div>

        <NotificationComposer
          v-if="showComposer"
          @close="showComposer = false"
          @created="handleNotificationCreated"
        />

        <div v-if="!showComposer">
          <div class="mb-4">
            <select 
              v-model="statusFilter" 
              @change="loadNotifications"
              class="px-4 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
            >
              <option value="">All Statuses</option>
              <option value="draft">Draft</option>
              <option value="scheduled">Scheduled</option>
              <option value="sending">Sending</option>
              <option value="sent">Sent</option>
              <option value="failed">Failed</option>
            </select>
          </div>

          <div v-if="loading" class="text-center py-12">
            <p class="text-gray-500">Loading notifications...</p>
          </div>
          <div v-else-if="notifications.length === 0" class="text-center py-12">
            <p class="text-gray-500">No notifications found</p>
          </div>
          <div v-else class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
            <div
              v-for="notification in notifications"
              :key="notification.id"
              class="bg-white overflow-hidden shadow rounded-lg"
            >
              <div class="p-6">
                <div class="flex justify-between items-start mb-4">
                  <h3 class="text-lg font-medium text-gray-900 flex-1">{{ notification.title }}</h3>
                  <span :class="`status-badge status-${notification.status}`">
                    {{ notification.status }}
                  </span>
                </div>
                <p class="text-gray-600 mb-4">{{ notification.body }}</p>
                <div class="space-y-2 text-sm text-gray-500 mb-4">
                  <div>Type: {{ notification.type }}</div>
                  <div v-if="notification.sentAt">
                    Sent: {{ formatDate(notification.sentAt) }}
                  </div>
                  <div v-if="notification.scheduledFor">
                    Scheduled: {{ formatDate(notification.scheduledFor) }}
                  </div>
                </div>
                <div v-if="notification.stats" class="grid grid-cols-2 gap-2 pt-4 border-t border-gray-200 text-sm">
                  <div class="text-gray-600">Recipients: <span class="font-medium">{{ notification.stats.totalRecipients }}</span></div>
                  <div class="text-gray-600">Delivered: <span class="font-medium">{{ notification.stats.delivered }}</span></div>
                  <div class="text-gray-600">Opened: <span class="font-medium">{{ notification.stats.opened }}</span></div>
                  <div class="text-gray-600">Clicked: <span class="font-medium">{{ notification.stats.clicked }}</span></div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </main>
  </div>
</template>

<script>
import { ref, onMounted } from 'vue';
import { notificationService } from '../services/notificationService';
import NotificationComposer from '../components/NotificationComposer.vue';
import AppHeader from '../components/AppHeader.vue';

export default {
  name: 'Notifications',
  components: {
    NotificationComposer,
    AppHeader
  },
  setup() {
    const showComposer = ref(false);
    const notifications = ref([]);
    const loading = ref(false);
    const statusFilter = ref('');

    const loadNotifications = async () => {
      loading.value = true;
      try {
        const response = await notificationService.getPromotionalNotifications();
        let filtered = response.notifications || [];
        
        if (statusFilter.value) {
          filtered = filtered.filter(n => n.status === statusFilter.value);
        }
        
        notifications.value = filtered;
      } catch (error) {
        console.error('Error loading notifications:', error);
        alert('Failed to load notifications');
      } finally {
        loading.value = false;
      }
    };

    const handleNotificationCreated = () => {
      showComposer.value = false;
      loadNotifications();
    };

    const formatDate = (timestamp) => {
      if (!timestamp) return '';
      const date = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
      return date.toLocaleString();
    };

    onMounted(() => {
      loadNotifications();
    });

    return {
      showComposer,
      notifications,
      loading,
      statusFilter,
      loadNotifications,
      handleNotificationCreated,
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

.status-scheduled { 
  background: #dbeafe; 
  color: #1e40af; 
}

.status-sending { 
  background: #fef3c7; 
  color: #92400e; 
}

.status-sent { 
  background: #d1fae5; 
  color: #065f46; 
}

.status-failed { 
  background: #fee2e2; 
  color: #991b1b; 
}
</style>

