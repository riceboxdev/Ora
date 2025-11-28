<template>
  <div
    class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50"
    @click.self="$emit('close')"
  >
    <div class="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
      <div class="flex justify-between items-center mb-4">
        <h3 class="text-lg font-medium text-gray-900">Temporary Ban</h3>
        <button
          @click="$emit('close')"
          class="text-gray-400 hover:text-gray-500"
        >
          ✕
        </button>
      </div>

      <form @submit.prevent="handleSubmit" class="space-y-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Duration (Hours) *</label>
          <input
            v-model.number="form.duration"
            type="number"
            min="1"
            required
            placeholder="e.g., 24"
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
          />
          <p class="mt-1 text-xs text-gray-500">
            Ban will automatically expire after this duration
          </p>
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Reason *</label>
          <textarea
            v-model="form.reason"
            required
            rows="4"
            placeholder="Explain why this temporary ban is being issued..."
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
          ></textarea>
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Notes (Optional)</label>
          <textarea
            v-model="form.notes"
            rows="3"
            placeholder="Additional notes for internal use..."
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
          ></textarea>
        </div>

        <div v-if="form.duration" class="bg-blue-50 border border-blue-200 rounded-md p-3">
          <p class="text-sm text-blue-700">
            Ban will expire on: {{ expirationDate }}
          </p>
        </div>

        <div class="flex justify-end space-x-2 pt-4">
          <button
            type="button"
            @click="$emit('close')"
            class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
          >
            Cancel
          </button>
          <button
            type="submit"
            :disabled="submitting"
            class="px-4 py-2 text-sm font-medium text-white bg-orange-600 border border-transparent rounded-md hover:bg-orange-700 disabled:opacity-50"
          >
            {{ submitting ? 'Banning...' : 'Issue Temporary Ban' }}
          </button>
        </div>
      </form>
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue';
import api from '../services/api';

const props = defineProps({
  userId: {
    type: String,
    required: true
  }
});

const emit = defineEmits(['close', 'banned']);

const form = ref({
  duration: 24,
  reason: '',
  notes: ''
});

const submitting = ref(false);

const expirationDate = computed(() => {
  if (!form.value.duration) return '';
  const date = new Date();
  date.setHours(date.getHours() + form.value.duration);
  return date.toLocaleString();
});

const handleSubmit = async () => {
  try {
    submitting.value = true;
    await api.post(`/api/admin/users/${props.userId}/temp-ban`, form.value);
    emit('banned');
  } catch (error) {
    console.error('Error issuing temporary ban:', error);
    alert('Failed to issue temporary ban');
  } finally {
    submitting.value = false;
  }
};
</script>





