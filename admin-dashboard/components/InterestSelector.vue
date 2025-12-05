<template>
  <div class="border rounded-md p-4 bg-white">
    <div v-if="loading" class="text-center py-2 text-gray-500">
      Loading interests...
    </div>
    
    <div v-else-if="error" class="text-red-500 py-2">
      {{ error }}
    </div>

    <div v-else class="max-h-60 overflow-y-auto space-y-1">
      <div v-if="interests.length === 0" class="text-gray-500 italic">
        No interests found.
      </div>
      
      <div v-for="interest in flattenedInterests" :key="interest.id" 
           class="flex items-center group hover:bg-gray-50 p-1 rounded">
        <div :style="{ paddingLeft: `${interest.level * 20}px` }" class="flex items-center w-full">
          <input 
            type="checkbox" 
            :id="`interest-${interest.id}`"
            :value="interest.id"
            :checked="modelValue.includes(interest.id)"
            @change="toggleInterest(interest.id)"
            class="h-4 w-4 text-indigo-600 focus:ring-indigo-500 border-gray-300 rounded mr-2"
          />
          <label :for="`interest-${interest.id}`" class="text-sm text-gray-700 w-full cursor-pointer select-none">
            {{ interest.displayName }}
            <span v-if="interest.level > 0" class="text-xs text-gray-400 ml-1">
              ({{ interest.parentName }})
            </span>
          </label>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue';
import { useInterestService } from '../composables/interestService';

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

// Flatten the tree for easier rendering in a single list while preserving order
const flattenedInterests = computed(() => {
  const result = [];
  
  const traverse = (nodes, parentName = null) => {
    for (const node of nodes) {
      result.push({
        id: node.id,
        displayName: node.displayName,
        level: node.level,
        parentName: parentName
      });
      
      if (node.children && node.children.length > 0) {
        traverse(node.children, node.displayName);
      }
    }
  };
  
  traverse(interests.value);
  return result;
});

const toggleInterest = (interestId) => {
  const newSelection = [...props.modelValue];
  const index = newSelection.indexOf(interestId);
  
  if (index === -1) {
    newSelection.push(interestId);
  } else {
    newSelection.splice(index, 1);
  }
  
  emit('update:modelValue', newSelection);
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
