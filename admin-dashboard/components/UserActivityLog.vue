<template>
  <div class="space-y-4">
    <!-- Filters -->
    <div class="flex items-center space-x-4">
      <label class="text-sm font-medium text-gray-700">Activity Type:</label>
      <select
        v-model="activityType"
        @change="fetchActivity"
        class="px-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
      >
        <option value="">All</option>
        <option value="post">Posts</option>
        <option value="comment">Comments</option>
      </select>
      <label class="text-sm font-medium text-gray-700">Date Range:</label>
      <input
        v-model="startDate"
        type="date"
        @change="fetchActivity"
        class="px-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
      />
      <input
        v-model="endDate"
        type="date"
        @change="fetchActivity"
        class="px-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
      />
    </div>

    <!-- Loading State -->
    <div v-if="loading" class="text-center py-8">
      <p class="text-gray-500">Loading activity...</p>
    </div>

    <!-- Activity Timeline -->
    <div v-else-if="activities.length > 0" class="space-y-4">
      <div
        v-for="activity in activities"
        :key="activity.id"
        class="border-l-4 border-indigo-500 pl-4 py-2"
      >
        <div class="flex items-start justify-between">
          <div class="flex-1">
            <div class="flex items-center space-x-2">
              <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-indigo-100 text-indigo-800">
                {{ activity.type }}
              </span>
              <span class="text-sm text-gray-500">{{ formatDate(activity.timestamp) }}</span>
            </div>
            <div v-if="activity.metadata" class="mt-2 text-sm text-gray-700">
              <div v-if="activity.metadata.caption" class="truncate">
                {{ activity.metadata.caption }}
              </div>
              <div v-if="activity.metadata.text" class="truncate">
                {{ activity.metadata.text }}
              </div>
              <div v-if="activity.metadata.moderationStatus" class="mt-1">
                <span
                  :class="{
                    'bg-green-100 text-green-800': activity.metadata.moderationStatus === 'approved',
                    'bg-yellow-100 text-yellow-800': activity.metadata.moderationStatus === 'pending',
                    'bg-red-100 text-red-800': activity.metadata.moderationStatus === 'rejected'
                  }"
                  class="inline-flex items-center px-2 py-1 rounded text-xs font-medium"
                >
                  {{ activity.metadata.moderationStatus }}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Pagination -->
      <div v-if="total > limit" class="flex items-center justify-between mt-4">
        <div class="text-sm text-gray-700">
          Showing {{ offset + 1 }} to {{ Math.min(offset + limit, total) }} of {{ total }} activities
        </div>
        <div class="flex items-center space-x-2">
          <button
            @click="handlePreviousPage"
            :disabled="offset === 0"
            class="px-4 py-2 border border-gray-300 rounded-md text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 disabled:opacity-50"
          >
            Previous
          </button>
          <button
            @click="handleNextPage"
            :disabled="offset + limit >= total"
            class="px-4 py-2 border border-gray-300 rounded-md text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 disabled:opacity-50"
          >
            Next
          </button>
        </div>
      </div>
    </div>

    <!-- Empty State -->
    <div v-else class="text-center py-8">
      <p class="text-gray-500">No activity found.</p>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import api from '../services/api';

const props = defineProps({
  userId: {
    type: String,
    required: true
  }
});

const activities = ref([]);
const loading = ref(true);
const activityType = ref('');
const startDate = ref('');
const endDate = ref('');
const limit = ref(50);
const offset = ref(0);
const total = ref(0);

const fetchActivity = async () => {
  try {
    loading.value = true;
    const params = {
      limit: limit.value,
      offset: offset.value,
      ...(activityType.value && { activityType: activityType.value }),
      ...(startDate.value && { startDate: new Date(startDate.value).getTime() }),
      ...(endDate.value && { endDate: new Date(endDate.value).getTime() })
    };

    const response = await api.get(`/api/admin/users/${props.userId}/activity`, { params });
    activities.value = response.data.activities || [];
    total.value = response.data.total || 0;
  } catch (error) {
    console.error('Error fetching activity:', error);
  } finally {
    loading.value = false;
  }
};

const handlePreviousPage = () => {
  if (offset.value > 0) {
    offset.value = Math.max(0, offset.value - limit.value);
    fetchActivity();
  }
};

const handleNextPage = () => {
  if (offset.value + limit.value < total.value) {
    offset.value += limit.value;
    fetchActivity();
  }
};

const formatDate = (timestamp) => {
  if (!timestamp) return 'Unknown';
  const date = new Date(timestamp);
  return date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
};

onMounted(() => {
  fetchActivity();
});
</script>








