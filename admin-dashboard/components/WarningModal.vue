<template>
  <div
    class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50"
    @click.self="$emit('close')"
  >
    <div class="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
      <div class="flex justify-between items-center mb-4">
        <h3 class="text-lg font-medium text-gray-900">Issue Warning</h3>
        <button
          @click="$emit('close')"
          class="text-gray-400 hover:text-gray-500"
        >
          ✕
        </button>
      </div>

      <form @submit.prevent="handleSubmit" class="space-y-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Warning Type</label>
          <select
            v-model="form.warningType"
            required
            class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
          >
            <option value="">Select type...</option>
            <option value="spam">Spam</option>
            <option value="harassment">Harassment</option>
            <option value="inappropriate_content">Inappropriate Content</option>
            <option value="terms_violation">Terms Violation</option>
            <option value="other">Other</option>
          </select>
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Reason *</label>
          <textarea
            v-model="form.reason"
            required
            rows="4"
            placeholder="Explain why this warning is being issued..."
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
            class="px-4 py-2 text-sm font-medium text-white bg-yellow-600 border border-transparent rounded-md hover:bg-yellow-700 disabled:opacity-50"
          >
            {{ submitting ? 'Issuing...' : 'Issue Warning' }}
          </button>
        </div>
      </form>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue';
import api from '../services/api';

const props = defineProps({
  userId: {
    type: String,
    required: true
  }
});

const emit = defineEmits(['close', 'warned']);

const form = ref({
  warningType: '',
  reason: '',
  notes: ''
});

const submitting = ref(false);

const handleSubmit = async () => {
  try {
    submitting.value = true;
    await api.post(`/api/admin/users/${props.userId}/warn`, form.value);
    emit('warned');
  } catch (error) {
    console.error('Error issuing warning:', error);
    alert('Failed to issue warning');
  } finally {
    submitting.value = false;
  }
};
</script>








