<template>
  <div class="hover:bg-gray-50 transition-colors">
    <div class="px-6 py-4 flex items-center justify-between">
      <div class="flex items-center gap-4 flex-1">
        <div>
          <div class="flex items-center gap-2 mb-1">
            <button
              @click="expanded = !expanded"
              v-if="children.length > 0"
              class="p-1 hover:bg-gray-200 rounded"
            >
              <svg
                class="w-4 h-4 transition-transform"
                :class="{ 'rotate-90': expanded }"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
              </svg>
            </button>
            <div v-else class="w-6"></div>
            <div>
              <h4 class="font-medium text-gray-900">{{ interest.displayName }}</h4>
              <p class="text-xs text-gray-500">{{ interest.name }}</p>
            </div>
          </div>
          <div v-if="interest.keywords?.length" class="mt-2 ml-10 flex flex-wrap gap-1">
            <span
              v-for="keyword in interest.keywords.slice(0, 3)"
              :key="keyword"
              class="text-xs px-2 py-1 bg-gray-100 text-gray-600 rounded"
            >
              {{ keyword }}
            </span>
            <span v-if="interest.keywords.length > 3" class="text-xs text-gray-500">
              +{{ interest.keywords.length - 3 }} more
            </span>
          </div>
        </div>
      </div>

      <div class="flex items-center gap-2">
        <span class="text-xs px-2 py-1 bg-blue-100 text-blue-700 rounded">Level {{ interest.level }}</span>
        <span v-if="!interest.isActive" class="text-xs px-2 py-1 bg-red-100 text-red-700 rounded">Inactive</span>
        
        <button
          @click="$emit('add-child')"
          title="Add child interest"
          class="p-2 text-green-600 hover:bg-green-50 rounded-md transition-colors"
        >
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
          </svg>
        </button>

        <button
          @click="$emit('edit', interest)"
          title="Edit interest"
          class="p-2 text-indigo-600 hover:bg-indigo-50 rounded-md transition-colors"
        >
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
          </svg>
        </button>

        <button
          @click="$emit('delete', interest.id)"
          title="Delete interest"
          class="p-2 text-red-600 hover:bg-red-50 rounded-md transition-colors"
        >
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
          </svg>
        </button>
      </div>
    </div>

    <!-- Children -->
    <div v-if="expanded && children.length > 0" class="bg-gray-50">
      <InterestItem
        v-for="child in children"
        :key="child.id"
        :interest="child"
        :allInterests="allInterests"
        @edit="$emit('edit', $event)"
        @delete="$emit('delete', $event)"
        @add-child="$emit('add-child', $event)"
      />
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue';

const props = defineProps({
  interest: {
    type: Object,
    required: true
  },
  allInterests: {
    type: Array,
    required: true
  }
});

defineEmits(['edit', 'delete', 'add-child']);

const expanded = ref(false);

const children = computed(() => {
  return props.allInterests.filter(i => i.parentId === props.interest.id);
});
</script>
