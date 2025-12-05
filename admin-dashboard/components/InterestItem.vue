<template>
  <div class="transition-colors">
    <div class="flex items-center justify-between border-b border-gray-100 hover:bg-gray-50" :class="{ 'bg-blue-50/30': expanded }">
      <div 
        class="flex-1 flex items-center gap-2 py-3 pr-4" 
        :style="{ paddingLeft: `${interest.level * 24 + 16}px` }"
      >
        <!-- Connector Lines (Visual Guide) -->
        <div v-if="interest.level > 0" class="absolute left-0 top-0 bottom-0 border-l border-gray-200" :style="{ left: `${interest.level * 24}px` }"></div>

        <!-- Expand/Collapse Button -->
        <button
          @click="toggleExpand"
          class="p-1 rounded text-gray-400 hover:text-gray-600 hover:bg-gray-200 transition-colors"
          :class="{ 'opacity-0 pointer-events-none': !hasChildren }"
        >
          <svg
            class="w-4 h-4 transition-transform duration-200"
            :class="{ 'rotate-90': expanded }"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
          </svg>
        </button>

        <div class="flex-1">
          <div class="flex items-center gap-2">
            <h4 class="font-medium text-gray-900">{{ interest.displayName }}</h4>
            <span class="text-xs text-gray-400 font-mono">{{ interest.name }}</span>
            <span v-if="!interest.isActive" class="ml-2 text-xs px-1.5 py-0.5 bg-red-100 text-red-700 rounded-sm">Inactive</span>
          </div>
          
          <div v-if="interest.keywords?.length" class="mt-1 flex flex-wrap gap-1">
            <span
              v-for="keyword in interest.keywords.slice(0, 3)"
              :key="keyword"
              class="text-[10px] px-1.5 py-0.5 bg-gray-100 text-gray-500 rounded border border-gray-200"
            >
              {{ keyword }}
            </span>
            <span v-if="interest.keywords.length > 3" class="text-[10px] text-gray-400 px-1">
              +{{ interest.keywords.length - 3 }} more
            </span>
          </div>
        </div>
      </div>

      <!-- Actions -->
      <div class="flex items-center gap-1 pr-4">
        <button
          @click="$emit('add-child', interest)"
          title="Add sub-interest"
          class="p-1.5 text-gray-400 hover:text-green-600 hover:bg-green-50 rounded transition-colors"
        >
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
          </svg>
        </button>
        <button
          @click="$emit('edit', interest)"
          title="Edit"
          class="p-1.5 text-gray-400 hover:text-indigo-600 hover:bg-indigo-50 rounded transition-colors"
        >
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
          </svg>
        </button>
        <button
          @click="$emit('delete', interest.id)"
          title="Delete"
          class="p-1.5 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded transition-colors"
        >
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
          </svg>
        </button>
      </div>
    </div>

    <!-- Recursive Children -->
    <div v-show="expanded && hasChildren" class="relative">
      <InterestItem
        v-for="child in children"
        :key="child.id"
        :interest="child"
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
  }
});

defineEmits(['edit', 'delete', 'add-child']);

const expanded = ref(false);

const children = computed(() => {
  return props.interest.children || [];
});

const hasChildren = computed(() => {
  return children.value.length > 0;
});

const toggleExpand = () => {
  if (hasChildren.value) {
    expanded.value = !expanded.value;
  }
};
</script>
