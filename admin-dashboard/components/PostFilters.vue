<template>
  <div class="bg-white border border-gray-200 rounded-lg p-4 mb-6">
    <div class="flex items-center justify-between mb-4">
      <h3 class="text-sm font-medium text-gray-900">Filters & Sorting</h3>
      <Button
        v-if="hasActiveFilters"
        @click="clearFilters"
        variant="ghost"
        size="sm"
        class="h-auto p-0 text-indigo-600 hover:text-indigo-700"
      >
        Clear All
      </Button>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
      <!-- Status Filter -->
      <div class="space-y-1">
        <label class="text-xs font-medium text-gray-700">Status</label>
        <Select :model-value="filters.status" @update:model-value="(v) => updateFilter('status', v)">
          <SelectItem value="all">All Statuses</SelectItem>
          <SelectItem value="pending">Pending</SelectItem>
          <SelectItem value="approved">Approved</SelectItem>
          <SelectItem value="rejected">Rejected</SelectItem>
          <SelectItem value="flagged">Flagged</SelectItem>
        </Select>
      </div>

      <!-- Sort By -->
      <div class="space-y-1">
        <label class="text-xs font-medium text-gray-700">Sort By</label>
        <Select :model-value="filters.sortBy" @update:model-value="(v) => updateFilter('sortBy', v)">
          <SelectItem value="createdAt">Date</SelectItem>
          <SelectItem value="likeCount">Likes</SelectItem>
          <SelectItem value="commentCount">Comments</SelectItem>
          <SelectItem value="viewCount">Views</SelectItem>
        </Select>
      </div>

      <!-- Sort Order -->
      <div class="space-y-1">
        <label class="text-xs font-medium text-gray-700">Order</label>
        <Select :model-value="filters.sortOrder" @update:model-value="(v) => updateFilter('sortOrder', v)">
          <SelectItem value="desc">Descending</SelectItem>
          <SelectItem value="asc">Ascending</SelectItem>
        </Select>
      </div>

      <!-- Date Range -->
      <div class="space-y-1">
        <label class="text-xs font-medium text-gray-700">Date Range</label>
        <Select :model-value="dateRangePreset" @update:model-value="handleDateRangeChange">
          <SelectItem value="all">All Time</SelectItem>
          <SelectItem value="today">Today</SelectItem>
          <SelectItem value="week">Last 7 Days</SelectItem>
          <SelectItem value="month">Last 30 Days</SelectItem>
          <SelectItem value="custom">Custom Range</SelectItem>
        </Select>
      </div>
    </div>

    <!-- Custom Date Range -->
    <div v-if="dateRangePreset === 'custom'" class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
      <div class="space-y-1">
        <label class="text-xs font-medium text-gray-700">Start Date</label>
        <Input
          type="date"
          :model-value="filters.startDate"
          @update:model-value="(v) => updateFilter('startDate', v)"
        />
      </div>
      <div class="space-y-1">
        <label class="text-xs font-medium text-gray-700">End Date</label>
        <Input
          type="date"
          :model-value="filters.endDate"
          @update:model-value="(v) => updateFilter('endDate', v)"
        />
      </div>
    </div>

    <!-- User and Tag Filters -->
    <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
      <div class="space-y-1">
        <label class="text-xs font-medium text-gray-700">User ID</label>
        <Input
          :model-value="filters.userId"
          placeholder="Filter by user ID..."
          @update:model-value="(v) => updateFilter('userId', v)"
        />
      </div>
      <div class="space-y-1">
        <label class="text-xs font-medium text-gray-700">Tag</label>
        <Input
          :model-value="filters.tag"
          placeholder="Filter by tag..."
          @update:model-value="(v) => updateFilter('tag', v)"
        />
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch } from 'vue';
import Button from '@/components/ui/Button.vue';
import Select from '@/components/ui/Select.vue';
import SelectItem from '@/components/ui/SelectItem.vue';
import Input from '@/components/ui/Input.vue';

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

const updateFilter = (key, value) => {
  filters.value[key] = value;
  emit('update:filters', filters.value);
};

const handleDateRangeChange = (value) => {
  dateRangePreset.value = value;
  
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  
  switch (value) {
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
      if (!filters.value.startDate && !filters.value.endDate) {
        filters.value.startDate = null;
        filters.value.endDate = null;
      }
      break;
  }
  
  emit('update:filters', filters.value);
};
</script>

