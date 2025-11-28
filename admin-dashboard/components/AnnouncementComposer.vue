<template>
  <div class="composer-overlay" @click.self="$emit('close')">
    <div class="composer-modal">
      <div class="composer-header">
        <h2>{{ editing ? 'Edit Announcement' : 'Create Announcement' }}</h2>
        <button @click="$emit('close')" class="close-btn">&times;</button>
      </div>

      <form @submit.prevent="handleSubmit" class="composer-form">
        <div class="form-group">
          <label>Title</label>
          <input
            v-model="form.title"
            type="text"
            required
            maxlength="100"
            placeholder="Announcement title"
          />
        </div>

        <div class="form-group">
          <label>Pages</label>
          <div class="pages-container">
            <div
              v-for="(page, index) in form.pages"
              :key="index"
              class="page-item"
            >
              <div class="page-header">
                <h3>Page {{ index + 1 }}</h3>
                <div class="page-actions">
                  <button
                    type="button"
                    @click="movePage(index, 'up')"
                    :disabled="index === 0"
                    class="btn-icon"
                    title="Move up"
                  >
                    ↑
                  </button>
                  <button
                    type="button"
                    @click="movePage(index, 'down')"
                    :disabled="index === form.pages.length - 1"
                    class="btn-icon"
                    title="Move down"
                  >
                    ↓
                  </button>
                  <button
                    type="button"
                    @click="removePage(index)"
                    :disabled="form.pages.length === 1"
                    class="btn-icon btn-danger"
                    title="Remove page"
                  >
                    ×
                  </button>
                </div>
              </div>

              <div class="page-content">
                <div class="form-group">
                  <label>Page Title (optional)</label>
                  <input
                    v-model="page.title"
                    type="text"
                    maxlength="100"
                    placeholder="Page title (optional)"
                  />
                </div>

                <div class="form-group">
                  <label>Body <span class="required">*</span></label>
                  <textarea
                    v-model="page.body"
                    required
                    rows="4"
                    maxlength="1000"
                    placeholder="Page content"
                  ></textarea>
                </div>

                <div class="form-group">
                  <label>Image URL (optional)</label>
                  <input
                    v-model="page.imageUrl"
                    type="url"
                    placeholder="https://example.com/image.jpg"
                  />
                </div>

                <div class="form-group">
                  <label>Layout</label>
                  <select v-model="page.layout">
                    <option value="default">Default</option>
                    <option value="centered">Centered</option>
                    <option value="image-top">Image Top</option>
                  </select>
                </div>
              </div>
            </div>

            <button
              type="button"
              @click="addPage"
              class="btn btn-secondary btn-add-page"
            >
              + Add Page
            </button>
          </div>
        </div>

        <AudienceSelector v-model="form.targetAudience" />

        <div class="form-group">
          <label>Status</label>
          <select v-model="form.status" required>
            <option value="draft">Draft</option>
            <option value="active">Active</option>
            <option value="archived">Archived</option>
          </select>
        </div>

        <div class="form-actions">
          <button type="button" @click="$emit('close')" class="btn btn-secondary">
            Cancel
          </button>
          <button type="submit" :disabled="submitting" class="btn btn-primary">
            {{ submitting ? 'Saving...' : (editing ? 'Update' : 'Create') }}
          </button>
        </div>
      </form>
    </div>
  </div>
</template>

<script>
import { ref, computed } from 'vue';
import { announcementService } from '../services/announcementService';
import AudienceSelector from './AudienceSelector.vue';

export default {
  name: 'AnnouncementComposer',
  components: {
    AudienceSelector
  },
  props: {
    announcement: {
      type: Object,
      default: null
    }
  },
  emits: ['close', 'created', 'updated'],
  setup(props, { emit }) {
    const editing = computed(() => !!props.announcement);

    const form = ref({
      title: props.announcement?.title || '',
      pages: props.announcement?.pages || [
        {
          title: '',
          body: '',
          imageUrl: '',
          layout: 'default'
        }
      ],
      targetAudience: props.announcement?.targetAudience || {
        type: 'all',
        filters: {}
      },
      status: props.announcement?.status || 'draft'
    });

    const submitting = ref(false);

    const addPage = () => {
      form.value.pages.push({
        title: '',
        body: '',
        imageUrl: '',
        layout: 'default'
      });
    };

    const removePage = (index) => {
      if (form.value.pages.length > 1) {
        form.value.pages.splice(index, 1);
      }
    };

    const movePage = (index, direction) => {
      const pages = form.value.pages;
      if (direction === 'up' && index > 0) {
        [pages[index], pages[index - 1]] = [pages[index - 1], pages[index]];
      } else if (direction === 'down' && index < pages.length - 1) {
        [pages[index], pages[index + 1]] = [pages[index + 1], pages[index]];
      }
    };

    const handleSubmit = async () => {
      submitting.value = true;
      try {
        // Clean up pages - remove empty optional fields
        const cleanedPages = form.value.pages.map(page => {
          const cleaned = {
            body: page.body
          };
          if (page.title) cleaned.title = page.title;
          if (page.imageUrl) cleaned.imageUrl = page.imageUrl;
          if (page.layout && page.layout !== 'default') cleaned.layout = page.layout;
          return cleaned;
        });

        const payload = {
          title: form.value.title,
          pages: cleanedPages,
          targetAudience: form.value.targetAudience,
          status: form.value.status
        };

        if (editing.value) {
          await announcementService.updateAnnouncement(props.announcement.id, payload);
          emit('updated');
        } else {
          await announcementService.createAnnouncement(payload);
          emit('created');
        }
      } catch (error) {
        console.error('Error saving announcement:', error);
        alert('Failed to save announcement: ' + (error.response?.data?.message || error.message));
      } finally {
        submitting.value = false;
      }
    };

    return {
      form,
      submitting,
      editing,
      addPage,
      removePage,
      movePage,
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
  max-width: 800px;
  max-height: 90vh;
  overflow-y: auto;
}

.composer-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1.5rem;
  border-bottom: 1px solid #eee;
  position: sticky;
  top: 0;
  background: white;
  z-index: 10;
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

.form-group label .required {
  color: #ef4444;
}

.form-group input[type="text"],
.form-group input[type="url"],
.form-group select,
.form-group textarea {
  width: 100%;
  padding: 0.75rem;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-size: 1rem;
  box-sizing: border-box;
}

.form-group textarea {
  resize: vertical;
}

.pages-container {
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

.page-item {
  border: 1px solid #ddd;
  border-radius: 8px;
  padding: 1rem;
  background: #f9fafb;
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
  padding-bottom: 0.5rem;
  border-bottom: 1px solid #e5e7eb;
}

.page-header h3 {
  margin: 0;
  font-size: 1.1rem;
  color: #374151;
}

.page-actions {
  display: flex;
  gap: 0.5rem;
}

.btn-icon {
  background: white;
  border: 1px solid #ddd;
  border-radius: 4px;
  padding: 0.25rem 0.5rem;
  cursor: pointer;
  font-size: 1rem;
  color: #374151;
}

.btn-icon:hover:not(:disabled) {
  background: #f3f4f6;
}

.btn-icon:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.btn-icon.btn-danger {
  color: #ef4444;
  border-color: #fca5a5;
}

.btn-icon.btn-danger:hover:not(:disabled) {
  background: #fee2e2;
}

.page-content {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.btn-add-page {
  margin-top: 0.5rem;
}

.form-actions {
  display: flex;
  justify-content: flex-end;
  gap: 1rem;
  margin-top: 2rem;
  padding-top: 1.5rem;
  border-top: 1px solid #eee;
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



