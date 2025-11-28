<template>
  <div class="bg-white border border-gray-200 rounded-lg p-4 mb-6">
    <div class="flex items-center justify-between mb-4">
      <h3 class="text-sm font-medium text-gray-900">Filters & Sorting</h3>
      <button
        v-if="hasActiveFilters"
        @click="clearFilters"
        class="text-sm text-indigo-600 hover:text-indigo-700"
      >
        Clear All
      </button>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
      <!-- Status Filter -->
      <div>
        <label for="status" class="block text-xs font-medium text-gray-700 mb-1">
          Status
        </label>
        <select
          id="status"
          v-model="filters.status"
          @change="$emit('update:filters', filters)"
          class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 text-sm"
        >
          <option value="all">All Statuses</option>
          <option value="pending">Pending</option>
          <option value="approved">Approved</option>
          <option value="rejected">Rejected</option>
          <option value="flagged">Flagged</option>
        </select>
      </div>

      <!-- Sort By -->
      <div>
        <label for="sortBy" class="block text-xs font-medium text-gray-700 mb-1">
          Sort By
        </label>
        <select
          id="sortBy"
          v-model="filters.sortBy"
          @change="$emit('update:filters', filters)"
          class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 text-sm"
        >
          <option value="createdAt">Date</option>
          <option value="likeCount">Likes</option>
          <option value="commentCount">Comments</option>
          <option value="viewCount">Views</option>
        </select>
      </div>

      <!-- Sort Order -->
      <div>
        <label for="sortOrder" class="block text-xs font-medium text-gray-700 mb-1">
          Order
        </label>
        <select
          id="sortOrder"
          v-model="filters.sortOrder"
          @change="$emit('update:filters', filters)"
          class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 text-sm"
        >
          <option value="desc">Descending</option>
          <option value="asc">Ascending</option>
        </select>
      </div>

      <!-- Date Range -->
      <div>
        <label for="dateRange" class="block text-xs font-medium text-gray-700 mb-1">
          Date Range
        </label>
        <select
          id="dateRange"
          v-model="dateRangePreset"
          @change="handleDateRangeChange"
          class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 text-sm"
        >
          <option value="all">All Time</option>
          <option value="today">Today</option>
          <option value="week">Last 7 Days</option>
          <option value="month">Last 30 Days</option>
          <option value="custom">Custom Range</option>
        </select>
      </div>
    </div>

    <!-- Custom Date Range -->
    <div v-if="dateRangePreset === 'custom'" class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
      <div>
        <label for="startDate" class="block text-xs font-medium text-gray-700 mb-1">
          Start Date
        </label>
        <input
          id="startDate"
          v-model="filters.startDate"
          type="date"
          @change="$emit('update:filters', filters)"
          class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 text-sm"
        />
      </div>
      <div>
        <label for="endDate" class="block text-xs font-medium text-gray-700 mb-1">
          End Date
        </label>
        <input
          id="endDate"
          v-model="filters.endDate"
          type="date"
          @change="$emit('update:filters', filters)"
          class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 text-sm"
        />
      </div>
    </div>

    <!-- User and Tag Filters -->
    <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
      <div>
        <label for="userId" class="block text-xs font-medium text-gray-700 mb-1">
          User ID
        </label>
        <input
          id="userId"
          v-model="filters.userId"
          type="text"
          placeholder="Filter by user ID..."
          @input="$emit('update:filters', filters)"
          class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 text-sm"
        />
      </div>
      <div>
        <label for="tag" class="block text-xs font-medium text-gray-700 mb-1">
          Tag
        </label>
        <input
          id="tag"
          v-model="filters.tag"
          type="text"
          placeholder="Filter by tag..."
          @input="$emit('update:filters', filters)"
          class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 text-sm"
        />
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch } from 'vue';

const props = defineProps({
  modelValue: {
    type: Object,
    default: () => ({
      status: 'all',
      sortBy: 'createdAt',
      sortOrder: 'desc',
      startDate: null,
      endDate: null,
      userId: '',
      tag: ''
    })
  }
});

const emit = defineEmits(['update:modelValue', 'update:filters']);

const filters = ref({ ...props.modelValue });
const dateRangePreset = ref('all');

const hasActiveFilters = computed(() => {
  return filters.value.status !== 'all' ||
    filters.value.userId !== '' ||
    filters.value.tag !== '' ||
    filters.value.startDate !== null ||
    filters.value.endDate !== null ||
    dateRangePreset.value !== 'all';
});

watch(() => props.modelValue, (newValue) => {
  filters.value = { ...newValue };
  updateDateRangePreset();
}, { deep: true });

const updateDateRangePreset = () => {
  if (filters.value.startDate || filters.value.endDate) {
    dateRangePreset.value = 'custom';
  } else {
    dateRangePreset.value = 'all';
  }
};

const handleDateRangeChange = () => {
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  
  switch (dateRangePreset.value) {
    case 'today':
      filters.value.startDate = today.toISOString().split('T')[0];
      filters.value.endDate = today.toISOString().split('T')[0];
      break;
    case 'week':
      const weekAgo = new Date(today);
      weekAgo.setDate(weekAgo.getDate() - 7);
      filters.value.startDate = weekAgo.toISOString().split('T')[0];
      filters.value.endDate = today.toISOString().split('T')[0];
      break;
    case 'month':
      const monthAgo = new Date(today);
      monthAgo.setDate(monthAgo.getDate() - 30);
      filters.value.startDate = monthAgo.toISOString().split('T')[0];
      filters.value.endDate = today.toISOString().split('T')[0];
      break;
    case 'all':
      filters.value.startDate = null;
      filters.value.endDate = null;
      break;
    case 'custom':
      // Keep existing dates or set to null
      if (!filters.value.startDate && !filters.value.endDate) {
        filters.value.startDate = null;
        filters.value.endDate = null;
      }
      break;
  }
  
  emit('update:filters', filters.value);
};

const clearFilters = () => {
  filters.value = {
    status: 'all',
    sortBy: 'createdAt',
    sortOrder: 'desc',
    startDate: null,
    endDate: null,
    userId: '',
    tag: ''
  };
  dateRangePreset.value = 'all';
  emit('update:filters', filters.value);
};
</script>

