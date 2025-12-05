<template>
  <div class="border rounded-md p-4 bg-white">
    <div v-if="loading" class="text-center py-2 text-gray-500">
      Loading interests...
    </div>
    
    <div v-else class="flex flex-col h-full">
      <div class="p-2 border-b flex justify-between items-center bg-gray-50">
        <span class="text-xs font-medium text-gray-500">Select Interests</span>
        <button 
          @click="openCreateModal(null)"
          class="text-xs text-indigo-600 hover:text-indigo-800 font-medium flex items-center gap-1"
        >
          <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" /></svg>
          New Interest
        </button>
      </div>

    <div v-if="error" class="text-red-500 py-2 px-4">
      {{ error }}
    </div>

    <div v-else class="max-h-60 overflow-y-auto space-y-1 p-2">
      <div v-if="interests.length === 0" class="text-gray-500 italic">
        No interests found.
      </div>
      
      <div v-for="interest in flattenedInterests.list" :key="interest.id" 
           class="flex items-center group hover:bg-gray-50 p-1 rounded justify-between">
        <div :style="{ paddingLeft: `${interest.level * 20}px` }" class="flex items-center flex-1 min-w-0">
          <input 
            type="checkbox" 
            :id="`interest-${interest.id}`"
            :value="interest.id"
            :checked="modelValue.includes(interest.id)"
            @change="toggleInterest(interest.id)"
            class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded mr-2 flex-shrink-0"
          />
          <label :for="`interest-${interest.id}`" class="text-sm text-gray-700 w-full cursor-pointer select-none truncate">
            {{ interest.displayName }}
            <span v-if="interest.level > 0" class="text-xs text-gray-400 ml-1">
              ({{ interest.parentName }})
            </span>
          </label>
        </div>
        
        <!-- Add Sub-interest Button (Optional, can be hidden for simplicity) -->
        <button 
          @click.stop="openCreateModal(interest.id)"
          class="opacity-0 group-hover:opacity-100 p-1 text-gray-400 hover:text-green-600"
          title="Add sub-interest"
        >
          <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" /></svg>
        </button>
      </div>
    </div>
    </div>
    
    <InterestCreateModal 
      :is-open="showCreateModal"
      :parent-id="createParentId"
      @close="showCreateModal = false"
      @created="handleInterestCreated"
    />
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue';
import { useInterestService } from '../composables/interestService';
import InterestCreateModal from './InterestCreateModal.vue';

const props = defineProps({
  modelValue: {
    type: Array,
    default: () => []
  }
});

const emit = defineEmits(['update:modelValue']);

const { getInterestTree } = useInterestService();
const interests = ref([]);
const loading = ref(true);
const error = ref(null);
const showCreateModal = ref(false);
const createParentId = ref(null);

function openCreateModal(parentId) {
  createParentId.value = parentId;
  showCreateModal.value = true;
}

async function handleInterestCreated(newInterest) {
  // Reload tree to show new interest
  try {
    loading.value = true;
    interests.value = await getInterestTree();
    
    // Auto-select the newly created interest
    const newSelection = [...props.modelValue, newInterest.id];
    emit('update:modelValue', newSelection);
  } catch (err) {
    console.error('Failed to reload interests', err);
  } finally {
    loading.value = false;
  }
}

// Flatten the tree for easier rendering in a single list while preserving order
const flattenedInterests = computed(() => {
  const result = [];
  const map = new Map(); // Helper map for parent lookups

  const flatten = (items, level = 0, parentName = '') => {
    for (const item of items) {
      // Ensure parentId is available
      const flatItem = { ...item, level, parentName };
      result.push(flatItem);
      map.set(item.id, flatItem);
      
      if (item.children && item.children.length > 0) {
        flatten(item.children, level + 1, item.displayName);
      }
    }
  };
  
  if (interests.value) {
    flatten(interests.value);
  }
  return { list: result, map };
});

function toggleInterest(id) {
  const newSelection = new Set(props.modelValue);
  
  if (newSelection.has(id)) {
    newSelection.delete(id);
  } else {
    newSelection.add(id);
    
    // Auto-select parents
    let current = flattenedInterests.value.map.get(id);
    while (current && current.parentId) {
      newSelection.add(current.parentId);
      current = flattenedInterests.value.map.get(current.parentId);
    }
  }
  
  emit('update:modelValue', Array.from(newSelection));
};

onMounted(async () => {
  try {
    loading.value = true;
    interests.value = await getInterestTree();
  } catch (err) {
    error.value = 'Failed to load interests';
    console.error(err);
  } finally {
    loading.value = false;
  }
});
</script>
