<template>
  <div v-if="isOpen" class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
    <div class="bg-white rounded-lg shadow-lg max-w-md w-full p-6">
      <h3 class="text-lg font-semibold text-gray-900 mb-4">
        {{ parentId ? 'Create Sub-Interest' : 'Create New Interest' }}
      </h3>
      
      <form @submit.prevent="submitCreateInterest" class="space-y-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Name (ID)</label>
          <input
            v-model="form.name"
            type="text"
            placeholder="fashion-basics"
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500"
            required
          />
          <p class="text-xs text-gray-500 mt-1">Lowercase with hyphens</p>
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Display Name</label>
          <input
            v-model="form.displayName"
            type="text"
            placeholder="Fashion Basics"
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500"
            required
          />
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Description (optional)</label>
          <textarea
            v-model="form.description"
            rows="3"
            placeholder="Brief description of this interest..."
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500"
          ></textarea>
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Keywords (comma-separated)</label>
          <input
            v-model="form.keywordsInput"
            type="text"
            placeholder="fashion, style, clothing"
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500"
          />
        </div>

        <div v-if="error" class="text-sm text-red-600">
          {{ error }}
        </div>

        <div class="flex gap-3 pt-4">
          <button
            type="button"
            @click="close"
            class="flex-1 px-4 py-2 text-gray-700 border border-gray-300 rounded-md hover:bg-gray-50"
          >
            Cancel
          </button>
          <button
            type="submit"
            :disabled="creating"
            class="flex-1 px-4 py-2 bg-indigo-600 text-white rounded-md hover:bg-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {{ creating ? 'Creating...' : 'Create' }}
          </button>
        </div>
      </form>
    </div>
  </div>
</template>

<script setup>
import { ref, watch } from 'vue';
import { useInterestService } from '../composables/interestService';

const props = defineProps({
  isOpen: {
    type: Boolean,
    required: true
  },
  parentId: {
    type: String,
    default: null
  }
});

const emit = defineEmits(['close', 'created']);

const { createInterest } = useInterestService();

const creating = ref(false);
const error = ref(null);

const form = ref({
  name: '',
  displayName: '',
  description: '',
  keywordsInput: ''
});

// Reset form when modal opens
watch(() => props.isOpen, (newVal) => {
  if (newVal) {
    resetForm();
  }
});

function resetForm() {
  form.value = {
    name: '',
    displayName: '',
    description: '',
    keywordsInput: ''
  };
  error.value = null;
}

function close() {
  emit('close');
}

async function submitCreateInterest() {
  try {
    creating.value = true;
    error.value = null;

    const keywords = form.value.keywordsInput
      .split(',')
      .map(k => k.trim())
      .filter(k => k);

    const newInterest = await createInterest({
      name: form.value.name,
      displayName: form.value.displayName,
      description: form.value.description || null,
      keywords,
      parentId: props.parentId 
    });

    emit('created', newInterest);
    close();
  } catch (err) {
    error.value = err.response?.data?.message || err.message || 'Failed to create interest';
    console.error('Error creating interest:', err);
  } finally {
    creating.value = false;
  }
}
</script>
