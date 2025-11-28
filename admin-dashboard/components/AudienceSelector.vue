<template>
  <div class="audience-selector">
    <div class="form-group">
      <label>Target Audience</label>
      <select v-model="localAudience.type" @change="handleTypeChange">
        <option value="all">All Users</option>
        <option value="role">By Role</option>
        <option value="activity">By Activity</option>
        <option value="custom">Custom</option>
      </select>
    </div>

    <div v-if="localAudience.type === 'role'" class="form-group">
      <label>Role</label>
      <select v-model="localAudience.filters.role">
        <option value="user">User</option>
        <option value="admin">Admin</option>
        <option value="moderator">Moderator</option>
      </select>
    </div>

    <div v-if="localAudience.type === 'activity'" class="form-group">
      <label>Active in last (days)</label>
      <input
        v-model.number="localAudience.filters.days"
        type="number"
        min="1"
        max="365"
        placeholder="30"
      />
    </div>

    <div v-if="localAudience.type === 'custom'" class="form-group">
      <label>User IDs (comma-separated)</label>
      <textarea
        v-model="customUserIds"
        rows="3"
        placeholder="userId1, userId2, userId3"
        @input="handleCustomUserIds"
      ></textarea>
    </div>
  </div>
</template>

<script>
import { ref, watch } from 'vue';

export default {
  name: 'AudienceSelector',
  props: {
    modelValue: {
      type: Object,
      required: true
    }
  },
  emits: ['update:modelValue'],
  setup(props, { emit }) {
    const localAudience = ref({
      type: props.modelValue.type || 'all',
      filters: { ...props.modelValue.filters } || {}
    });

    const customUserIds = ref(
      props.modelValue.filters?.userIds?.join(', ') || ''
    );

    const handleTypeChange = () => {
      // Reset filters when type changes
      localAudience.value.filters = {};
      if (localAudience.value.type === 'role') {
        localAudience.value.filters.role = 'user';
      } else if (localAudience.value.type === 'activity') {
        localAudience.value.filters.days = 30;
      }
      emit('update:modelValue', localAudience.value);
    };

    const handleCustomUserIds = () => {
      const userIds = customUserIds.value
        .split(',')
        .map(id => id.trim())
        .filter(id => id.length > 0);
      localAudience.value.filters.userIds = userIds;
      emit('update:modelValue', localAudience.value);
    };

    watch(
      () => props.modelValue,
      (newValue) => {
        localAudience.value = {
          type: newValue.type || 'all',
          filters: { ...newValue.filters } || {}
        };
        if (newValue.filters?.userIds) {
          customUserIds.value = newValue.filters.userIds.join(', ');
        }
      },
      { deep: true }
    );

    watch(localAudience, (newValue) => {
      emit('update:modelValue', newValue);
    }, { deep: true });

    return {
      localAudience,
      customUserIds,
      handleTypeChange,
      handleCustomUserIds
    };
  }
};
</script>

<style scoped>
.audience-selector {
  margin-bottom: 1.5rem;
}

.form-group {
  margin-bottom: 1rem;
}

.form-group label {
  display: block;
  margin-bottom: 0.5rem;
  font-weight: 500;
}

.form-group select,
.form-group input,
.form-group textarea {
  width: 100%;
  padding: 0.75rem;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-size: 1rem;
}

.form-group textarea {
  resize: vertical;
  font-family: monospace;
}
</style>

