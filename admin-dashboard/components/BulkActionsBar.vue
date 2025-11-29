<template>
  <div
    v-if="selectedCount > 0"
    class="fixed bottom-0 left-0 right-0 bg-white border-t border-gray-200 shadow-lg z-50"
  >
    <div class="max-w-7xl mx-auto px-4 py-4">
      <div class="flex items-center justify-between">
        <div class="flex items-center space-x-4">
          <span class="text-sm font-medium text-gray-700">
            {{ selectedCount }} user{{ selectedCount !== 1 ? 's' : '' }} selected
          </span>
        </div>
        <div class="flex items-center space-x-2">
          <button
            @click="$emit('bulk-ban')"
            class="px-4 py-2 text-sm font-medium text-red-600 bg-red-50 border border-red-200 rounded-md hover:bg-red-100"
            :disabled="processing"
          >
            Ban Selected
          </button>
          <button
            @click="$emit('bulk-unban')"
            class="px-4 py-2 text-sm font-medium text-green-600 bg-green-50 border border-green-200 rounded-md hover:bg-green-100"
            :disabled="processing"
          >
            Unban Selected
          </button>
          <button
            @click="$emit('bulk-export')"
            class="px-4 py-2 text-sm font-medium text-indigo-600 bg-indigo-50 border border-indigo-200 rounded-md hover:bg-indigo-100"
            :disabled="processing"
          >
            Export Selected
          </button>
          <button
            @click="$emit('clear-selection')"
            class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
            :disabled="processing"
          >
            Clear
          </button>
        </div>
      </div>
      <div v-if="processing" class="mt-2">
        <div class="bg-blue-50 border border-blue-200 rounded-md p-2">
          <p class="text-sm text-blue-700">{{ processingMessage }}</p>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
defineProps({
  selectedCount: {
    type: Number,
    required: true
  },
  processing: {
    type: Boolean,
    default: false
  },
  processingMessage: {
    type: String,
    default: 'Processing...'
  }
});

defineEmits(['bulk-ban', 'bulk-unban', 'bulk-export', 'clear-selection']);
</script>








