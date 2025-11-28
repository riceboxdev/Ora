<template>
  <div class="bg-white border border-gray-200 rounded-lg p-4 mb-6">
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
      <!-- Search -->
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Search</label>
        <input
          v-model="localSearch"
          type="text"
          placeholder="Email, name, username..."
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
          @input="debouncedSearch"
        />
      </div>

      <!-- Status Filter -->
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Status</label>
        <select
          v-model="localFilters.status"
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
          @change="$emit('update:filters', localFilters)"
        >
          <option value="all">All Users</option>
          <option value="active">Active</option>
          <option value="banned">Banned</option>
          <option value="admin">Admins</option>
        </select>
      </div>

      <!-- Activity Level -->
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Activity Level</label>
        <select
          v-model="localFilters.activityLevel"
          class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
          @change="$emit('update:filters', localFilters)"
        >
          <option value="">All</option>
          <option value="active">Active (30 days)</option>
          <option value="inactive">Inactive</option>
          <option value="new">New (7 days)</option>
        </select>
      </div>

      <!-- Date Range -->
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Joined Date</label>
        <div class="flex gap-2">
          <input
            v-model="localFilters.startDate"
            type="date"
            class="flex-1 px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
            @change="$emit('update:filters', localFilters)"
          />
          <input
            v-model="localFilters.endDate"
            type="date"
            class="flex-1 px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
            @change="$emit('update:filters', localFilters)"
          />
        </div>
      </div>
    </div>

    <!-- Clear Filters Button -->
    <div class="mt-4 flex justify-end">
      <button
        @click="clearFilters"
        class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
      >
        Clear Filters
      </button>
    </div>
  </div>
</template>

<script setup>
import { ref, watch } from 'vue';

const props = defineProps({
  filters: {
    type: Object,
    default: () => ({
      search: '',
      status: 'all',
      activityLevel: '',
      startDate: '',
      endDate: ''
    })
  }
});

const emit = defineEmits(['update:filters', 'search']);

const localFilters = ref({ ...props.filters });
const localSearch = ref(props.filters.search || '');

let searchTimeout = null;

const debouncedSearch = () => {
  clearTimeout(searchTimeout);
  searchTimeout = setTimeout(() => {
    localFilters.value.search = localSearch.value;
    emit('update:filters', localFilters.value);
    emit('search', localSearch.value);
  }, 300);
};

const clearFilters = () => {
  localFilters.value = {
    search: '',
    status: 'all',
    activityLevel: '',
    startDate: '',
    endDate: ''
  };
  localSearch.value = '';
  emit('update:filters', localFilters.value);
};

watch(() => props.filters, (newFilters) => {
  localFilters.value = { ...newFilters };
  localSearch.value = newFilters.search || '';
}, { deep: true });
</script>





