<template>
  <div class="composer-overlay" @click.self="$emit('close')">
    <div class="composer-modal">
      <div class="composer-header">
        <h2>Create Notification</h2>
        <button @click="$emit('close')" class="close-btn">&times;</button>
      </div>

      <form @submit.prevent="handleSubmit" class="composer-form">
        <div class="form-group">
          <label>Type</label>
          <SelectRoot v-model="form.type">
            <SelectTrigger class="w-full">
              <SelectValue placeholder="Select type" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="announcement">Announcement</SelectItem>
              <SelectItem value="promo">Promo</SelectItem>
              <SelectItem value="feature_update">Feature Update</SelectItem>
              <SelectItem value="event">Event</SelectItem>
            </SelectContent>
          </SelectRoot>
        </div>

        <div class="form-group">
          <label>Title</label>
          <input
            v-model="form.title"
            type="text"
            required
            maxlength="100"
            placeholder="Notification title"
          />
        </div>

        <div class="form-group">
          <label>Body</label>
          <textarea
            v-model="form.body"
            required
            rows="4"
            maxlength="500"
            placeholder="Notification message"
          ></textarea>
        </div>

        <div class="form-group">
          <label>Image URL (optional)</label>
          <input
            v-model="form.imageUrl"
            type="url"
            placeholder="https://example.com/image.jpg"
          />
        </div>

        <div class="form-group">
          <label>Deep Link (optional)</label>
          <input
            v-model="form.deepLink"
            type="text"
            placeholder="ora://post/123"
          />
        </div>

        <AudienceSelector v-model="form.targetAudience" />

        <div class="form-group">
          <label>
            <input
              v-model="form.schedule"
              type="checkbox"
            />
            Schedule for later
          </label>
          <input
            v-if="form.schedule"
            v-model="form.scheduledFor"
            type="datetime-local"
            required
          />
        </div>

        <div class="form-actions">
          <button type="button" @click="$emit('close')" class="btn btn-secondary">
            Cancel
          </button>
          <button type="submit" :disabled="submitting" class="btn btn-primary">
            {{ submitting ? 'Creating...' : 'Create Notification' }}
          </button>
        </div>
      </form>
    </div>
  </div>
</template>

<script>
import { ref } from 'vue';
import { notificationService } from '../services/notificationService';
import AudienceSelector from './AudienceSelector.vue';
import { SelectRoot, SelectContent, SelectItem, SelectTrigger, SelectValue } from 'reka-ui';

export default {
  name: 'NotificationComposer',
  components: {
    AudienceSelector
  },
  emits: ['close', 'created'],
  setup(props, { emit }) {
    const form = ref({
      type: 'announcement',
      title: '',
      body: '',
      imageUrl: '',
      deepLink: '',
      targetAudience: {
        type: 'all',
        filters: {}
      },
      schedule: false,
      scheduledFor: ''
    });

    const submitting = ref(false);

    const handleSubmit = async () => {
      submitting.value = true;
      try {
        const payload = {
          title: form.value.title,
          body: form.value.body,
          type: form.value.type,
          targetAudience: form.value.targetAudience,
          ...(form.value.imageUrl && { imageUrl: form.value.imageUrl }),
          ...(form.value.deepLink && { deepLink: form.value.deepLink }),
          ...(form.value.schedule && form.value.scheduledFor && {
            scheduledFor: new Date(form.value.scheduledFor).toISOString()
          })
        };

        await notificationService.createPromotionalNotification(payload);
        emit('created');
      } catch (error) {
        console.error('Error creating notification:', error);
        alert('Failed to create notification: ' + (error.response?.data?.message || error.message));
      } finally {
        submitting.value = false;
      }
    };

    return {
      form,
      submitting,
      handleSubmit
    };
  }
};
</script>

<style scoped>
.composer-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.composer-modal {
  background: white;
  border-radius: 8px;
  width: 90%;
  max-width: 600px;
  max-height: 90vh;
  overflow-y: auto;
}

.composer-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1.5rem;
  border-bottom: 1px solid #eee;
}

.composer-header h2 {
  margin: 0;
  font-size: 1.5rem;
}

.close-btn {
  background: none;
  border: none;
  font-size: 2rem;
  cursor: pointer;
  color: #666;
  line-height: 1;
}

.composer-form {
  padding: 1.5rem;
}

.form-group {
  margin-bottom: 1.5rem;
}

.form-group label {
  display: block;
  margin-bottom: 0.5rem;
  font-weight: 500;
}

.form-group input[type="text"],
.form-group input[type="url"],
.form-group input[type="datetime-local"],
.form-group select,
.form-group textarea {
  width: 100%;
  padding: 0.75rem;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-size: 1rem;
}

.form-group textarea {
  resize: vertical;
}

.form-group input[type="checkbox"] {
  margin-right: 0.5rem;
}

.form-actions {
  display: flex;
  justify-content: flex-end;
  gap: 1rem;
  margin-top: 2rem;
}

.btn {
  padding: 0.75rem 1.5rem;
  border: none;
  border-radius: 4px;
  font-size: 1rem;
  cursor: pointer;
  font-weight: 500;
}

.btn-primary {
  background: #3b82f6;
  color: white;
}

.btn-primary:hover:not(:disabled) {
  background: #2563eb;
}

.btn-primary:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.btn-secondary {
  background: #e5e7eb;
  color: #374151;
}

.btn-secondary:hover {
  background: #d1d5db;
}
</style>

