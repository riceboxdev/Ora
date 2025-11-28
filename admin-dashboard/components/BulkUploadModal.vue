<template>
  <div
    v-if="isOpen"
    class="fixed inset-0 z-50 overflow-y-auto"
    @click.self="$emit('close')"
  >
    <div class="flex items-center justify-center min-h-screen px-4 pt-4 pb-20 text-center sm:block sm:p-0">
      <div class="fixed inset-0 transition-opacity bg-gray-500 bg-opacity-75" @click="$emit('close')"></div>

      <div class="inline-block align-bottom bg-white rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-6xl sm:w-full">
        <div class="bg-white px-4 pt-5 pb-4 sm:p-6 sm:pb-4">
          <div class="flex items-center justify-between mb-4">
            <h3 class="text-lg font-medium text-gray-900">Bulk Upload Posts</h3>
            <button
              @click="handleClose"
              class="text-gray-400 hover:text-gray-500"
              :disabled="uploading"
            >
              <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>

          <div class="space-y-6">
            <!-- Step 1: File Upload -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">
                Select Images
              </label>
              <div
                @drop="handleDrop"
                @dragover.prevent
                @dragenter.prevent
                :class="[
                  'border-2 border-dashed rounded-lg p-8 text-center cursor-pointer transition-colors',
                  isDragging ? 'border-indigo-500 bg-indigo-50' : 'border-gray-300 hover:border-gray-400'
                ]"
                @click="triggerFileInput"
              >
                <input
                  ref="fileInput"
                  type="file"
                  multiple
                  accept="image/*"
                  @change="handleFileSelect"
                  class="hidden"
                />
                <svg class="mx-auto h-12 w-12 text-gray-400" stroke="currentColor" fill="none" viewBox="0 0 48 48">
                  <path d="M28 8H12a4 4 0 00-4 4v20m32-12v8m0 0v8a4 4 0 01-4 4H12a4 4 0 01-4-4v-4m32-4l-3.172-3.172a4 4 0 00-5.656 0L28 28M8 32l9.172-9.172a4 4 0 015.656 0L28 28m0 0l4 4m4-24h8m-4-4v8m-12 4h.02" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
                </svg>
                <p class="mt-2 text-sm text-gray-600">
                  <span class="font-semibold text-indigo-600">Click to upload</span> or drag and drop
                </p>
                <p class="text-xs text-gray-500 mt-1">PNG, JPG, GIF, WEBP, HEIC up to 50MB each</p>
              </div>
              <button
                v-if="selectedFiles.length > 0"
                @click="clearFiles"
                class="mt-2 text-sm text-red-600 hover:text-red-700"
              >
                Clear all ({{ selectedFiles.length }} files)
              </button>
            </div>

            <!-- Image Preview Grid -->
            <div v-if="selectedFiles.length > 0" class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-4 max-h-64 overflow-y-auto">
              <div
                v-for="(file, index) in selectedFiles"
                :key="index"
                class="relative group"
              >
                <img
                  :src="file.preview"
                  :alt="file.name"
                  class="w-full h-32 object-cover rounded-lg border border-gray-200"
                />
                <button
                  @click="removeFile(index)"
                  class="absolute top-1 right-1 bg-red-500 text-white rounded-full p-1 opacity-0 group-hover:opacity-100 transition-opacity"
                  :disabled="uploading"
                >
                  <svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
                <div class="mt-1 text-xs text-gray-500 truncate">{{ file.name }}</div>
              </div>
            </div>

            <!-- Step 2: User Selection -->
            <div v-if="selectedFiles.length > 0">
              <label for="userId" class="block text-sm font-medium text-gray-700 mb-1">
                User <span class="text-red-500">*</span>
              </label>
              <select
                id="userId"
                v-model="selectedUserId"
                class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
                :disabled="uploading || loadingUsers"
                required
              >
                <option value="">Select a user...</option>
                <option v-for="user in users" :key="user.id" :value="user.id">
                  {{ user.displayName || user.email || user.id }}
                </option>
              </select>
              <p v-if="loadingUsers" class="mt-1 text-xs text-gray-500">Loading users...</p>
            </div>

            <!-- Step 3: Default Metadata -->
            <div v-if="selectedFiles.length > 0" class="border-t pt-4">
              <h4 class="text-sm font-medium text-gray-700 mb-3">Default Metadata (applies to all images)</h4>
              
              <div class="space-y-4">
                <div>
                  <label for="defaultCaption" class="block text-sm font-medium text-gray-700 mb-1">
                    Caption
                  </label>
                  <textarea
                    id="defaultCaption"
                    v-model="defaultMetadata.caption"
                    rows="3"
                    class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
                    placeholder="Enter default caption..."
                    :disabled="uploading"
                  ></textarea>
                </div>

                <div>
                  <label for="defaultTags" class="block text-sm font-medium text-gray-700 mb-1">
                    Tags (comma-separated)
                  </label>
                  <input
                    id="defaultTags"
                    v-model="defaultTagsInput"
                    type="text"
                    class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
                    placeholder="tag1, tag2, tag3"
                    :disabled="uploading"
                  />
                  <p class="mt-1 text-xs text-gray-500">Separate tags with commas</p>
                </div>

                <div>
                  <label for="defaultCategories" class="block text-sm font-medium text-gray-700 mb-1">
                    Categories (comma-separated)
                  </label>
                  <input
                    id="defaultCategories"
                    v-model="defaultCategoriesInput"
                    type="text"
                    class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500"
                    placeholder="category1, category2"
                    :disabled="uploading"
                  />
                  <p class="mt-1 text-xs text-gray-500">Separate categories with commas</p>
                </div>
              </div>
            </div>

            <!-- Step 4: Per-Image Overrides -->
            <div v-if="selectedFiles.length > 0 && selectedFiles.length <= 10" class="border-t pt-4">
              <h4 class="text-sm font-medium text-gray-700 mb-3">Individual Image Overrides (optional)</h4>
              <div class="space-y-4 max-h-96 overflow-y-auto">
                <div
                  v-for="(file, index) in selectedFiles"
                  :key="index"
                  class="border border-gray-200 rounded-lg p-3"
                >
                  <div class="flex items-center justify-between mb-2">
                    <span class="text-sm font-medium text-gray-700">{{ file.name }}</span>
                    <button
                      @click="toggleImageOverride(index)"
                      class="text-xs text-indigo-600 hover:text-indigo-700"
                    >
                      {{ imageOverrides[index] ? 'Hide' : 'Override' }}
                    </button>
                  </div>
                  <div v-if="imageOverrides[index]" class="space-y-2 mt-2">
                    <input
                      v-model="imageOverrides[index].caption"
                      type="text"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded"
                      placeholder="Override caption..."
                      :disabled="uploading"
                    />
                    <input
                      v-model="imageOverrides[index].tags"
                      type="text"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded"
                      placeholder="Override tags (comma-separated)..."
                      :disabled="uploading"
                    />
                    <input
                      v-model="imageOverrides[index].categories"
                      type="text"
                      class="w-full px-2 py-1 text-sm border border-gray-300 rounded"
                      placeholder="Override categories (comma-separated)..."
                      :disabled="uploading"
                    />
                  </div>
                </div>
              </div>
              <p v-if="selectedFiles.length > 10" class="text-xs text-gray-500 mt-2">
                Individual overrides are only available for 10 or fewer images
              </p>
            </div>

            <!-- Upload Progress -->
            <div v-if="uploading" class="border-t pt-4">
              <div class="mb-2 flex items-center justify-between">
                <span class="text-sm font-medium text-gray-700">Upload Progress</span>
                <span class="text-sm text-gray-500">{{ uploadProgress.current }} / {{ uploadProgress.total }}</span>
              </div>
              <div class="w-full bg-gray-200 rounded-full h-2">
                <div
                  class="bg-indigo-600 h-2 rounded-full transition-all duration-300"
                  :style="{ width: `${(uploadProgress.current / uploadProgress.total) * 100}%` }"
                ></div>
              </div>
              <p v-if="uploadProgress.currentFile" class="mt-2 text-xs text-gray-500">
                Uploading: {{ uploadProgress.currentFile }}
              </p>
            </div>

            <!-- Error Display -->
            <div v-if="error" class="p-3 bg-red-50 border border-red-200 rounded-md">
              <p class="text-sm text-red-600">{{ error }}</p>
            </div>
          </div>
        </div>

        <div class="bg-gray-50 px-4 py-3 sm:px-6 sm:flex sm:flex-row-reverse">
          <button
            type="button"
            @click="handleUpload"
            :disabled="uploading || selectedFiles.length === 0 || !selectedUserId"
            class="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-indigo-600 text-base font-medium text-white hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:ml-3 sm:w-auto sm:text-sm disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {{ uploading ? `Uploading... (${uploadProgress.current}/${uploadProgress.total})` : `Upload ${selectedFiles.length} Post${selectedFiles.length !== 1 ? 's' : ''}` }}
          </button>
          <button
            type="button"
            @click="handleClose"
            :disabled="uploading"
            class="mt-3 w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 sm:mt-0 sm:ml-3 sm:w-auto sm:text-sm disabled:opacity-50 disabled:cursor-not-allowed"
          >
            Cancel
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted, watch } from 'vue';
import api from '../services/api';

const props = defineProps({
  isOpen: {
    type: Boolean,
    default: false
  }
});

const emit = defineEmits(['close', 'uploaded']);

const fileInput = ref(null);
const selectedFiles = ref([]);
const isDragging = ref(false);
const users = ref([]);
const loadingUsers = ref(false);
const selectedUserId = ref('');
const defaultMetadata = ref({
  caption: '',
  tags: [],
  categories: []
});
const defaultTagsInput = ref('');
const defaultCategoriesInput = ref('');
const imageOverrides = ref({});
const uploading = ref(false);
const uploadProgress = ref({
  current: 0,
  total: 0,
  currentFile: ''
});
const error = ref(null);

// Load users when modal opens
watch(() => props.isOpen, async (isOpen) => {
  if (isOpen) {
    await fetchUsers();
    resetForm();
  }
});

const fetchUsers = async () => {
  try {
    loadingUsers.value = true;
    const response = await api.get('/api/admin/users', {
      params: { limit: 100 }
    });
    users.value = response.data.users || [];
  } catch (err) {
    console.error('Error fetching users:', err);
    error.value = 'Failed to load users';
  } finally {
    loadingUsers.value = false;
  }
};

const resetForm = () => {
  selectedFiles.value = [];
  selectedUserId.value = '';
  defaultMetadata.value = { caption: '', tags: [], categories: [] };
  defaultTagsInput.value = '';
  defaultCategoriesInput.value = '';
  imageOverrides.value = {};
  error.value = null;
  uploadProgress.value = { current: 0, total: 0, currentFile: '' };
};

const triggerFileInput = () => {
  if (!uploading.value && fileInput.value) {
    fileInput.value.click();
  }
};

const handleFileSelect = (event) => {
  const files = Array.from(event.target.files || []);
  addFiles(files);
};

const handleDrop = (event) => {
  event.preventDefault();
  isDragging.value = false;
  const files = Array.from(event.dataTransfer.files || []);
  addFiles(files);
};

const addFiles = (files) => {
  const imageFiles = files.filter(file => file.type.startsWith('image/'));
  
  imageFiles.forEach(file => {
    const preview = URL.createObjectURL(file);
    selectedFiles.value.push({
      file,
      name: file.name,
      preview,
      width: null,
      height: null
    });
    
    // Extract image dimensions
    const img = new Image();
    img.onload = () => {
      const index = selectedFiles.value.findIndex(f => f.name === file.name);
      if (index !== -1) {
        selectedFiles.value[index].width = img.width;
        selectedFiles.value[index].height = img.height;
      }
    };
    img.src = preview;
  });
};

const removeFile = (index) => {
  if (selectedFiles.value[index]) {
    URL.revokeObjectURL(selectedFiles.value[index].preview);
    selectedFiles.value.splice(index, 1);
    // Clean up override if exists
    if (imageOverrides.value[index]) {
      delete imageOverrides.value[index];
    }
    // Reindex overrides
    const newOverrides = {};
    Object.keys(imageOverrides.value).forEach(key => {
      const keyNum = parseInt(key);
      if (keyNum < index) {
        newOverrides[keyNum] = imageOverrides.value[key];
      } else if (keyNum > index) {
        newOverrides[keyNum - 1] = imageOverrides.value[key];
      }
    });
    imageOverrides.value = newOverrides;
  }
};

const clearFiles = () => {
  selectedFiles.value.forEach(file => {
    URL.revokeObjectURL(file.preview);
  });
  selectedFiles.value = [];
  imageOverrides.value = {};
};

const toggleImageOverride = (index) => {
  if (!imageOverrides.value[index]) {
    imageOverrides.value[index] = {
      caption: '',
      tags: '',
      categories: ''
    };
  } else {
    delete imageOverrides.value[index];
  }
};

const parseCommaSeparated = (str) => {
  if (!str) return [];
  return str.split(',').map(s => s.trim()).filter(s => s);
};

const handleUpload = async () => {
  if (selectedFiles.value.length === 0 || !selectedUserId.value) {
    error.value = 'Please select images and a user';
    return;
  }

  uploading.value = true;
  error.value = null;
  uploadProgress.value = {
    current: 0,
    total: selectedFiles.value.length * 2, // Upload + create
    currentFile: ''
  };

  const uploadedImages = [];
  const uploadedImageUrls = []; // Track for rollback
  let postsCreated = false;

  try {
    const defaultTags = parseCommaSeparated(defaultTagsInput.value);
    const defaultCategories = parseCommaSeparated(defaultCategoriesInput.value);

    // Step 1: Upload all images
    for (let i = 0; i < selectedFiles.value.length; i++) {
      const fileData = selectedFiles.value[i];
      uploadProgress.value.currentFile = fileData.name;
      uploadProgress.value.current = i;

      try {
        const formData = new FormData();
        formData.append('image', fileData.file);
        if (fileData.width) {
          formData.append('imageWidth', fileData.width.toString());
        }
        if (fileData.height) {
          formData.append('imageHeight', fileData.height.toString());
        }

        // Don't set Content-Type header - let axios set it automatically with boundary
        const uploadResponse = await api.post('/api/admin/posts/upload-image', formData, {
          timeout: 60000, // 60 second timeout for large files
          maxContentLength: Infinity,
          maxBodyLength: Infinity
        });

        if (!uploadResponse.data || !uploadResponse.data.imageUrl) {
          throw new Error(`Upload failed for ${fileData.name}: Invalid response`);
        }

        uploadedImages.push({
          ...uploadResponse.data,
          index: i
        });
        uploadedImageUrls.push(uploadResponse.data.imageUrl);
      } catch (uploadErr) {
        console.error(`Failed to upload ${fileData.name}:`, uploadErr);
        // If we have some images uploaded, we need to rollback
        if (uploadedImages.length > 0) {
          error.value = `Failed to upload ${fileData.name}. ${uploadedImages.length} image(s) were uploaded but will not be used.`;
          // Note: We can't delete Cloudflare images, but we won't create posts for them
          throw new Error(`Upload failed at ${fileData.name}. Partial upload detected.`);
        } else {
          throw uploadErr;
        }
      }
    }

    // Step 2: Create posts
    uploadProgress.value.current = selectedFiles.value.length;
    const posts = uploadedImages.map((img, idx) => {
      const fileIndex = img.index;
      const override = imageOverrides.value[fileIndex] || {};
      
      return {
        userId: selectedUserId.value,
        imageUrl: img.imageUrl,
        thumbnailUrl: img.thumbnailUrl,
        imageWidth: img.imageWidth || selectedFiles.value[fileIndex].width,
        imageHeight: img.imageHeight || selectedFiles.value[fileIndex].height,
        caption: override.caption || defaultMetadata.value.caption || null,
        tags: override.tags ? parseCommaSeparated(override.tags) : defaultTags,
        categories: override.categories ? parseCommaSeparated(override.categories) : defaultCategories
      };
    });

    // Create posts in bulk
    uploadProgress.value.currentFile = 'Creating posts...';
    try {
      const createResponse = await api.post('/api/admin/posts/bulk-create', { posts });
      postsCreated = true;

      // Clean up preview URLs
      selectedFiles.value.forEach(file => {
        URL.revokeObjectURL(file.preview);
      });

      emit('uploaded', createResponse.data);
      handleClose();
    } catch (createErr) {
      console.error('Failed to create posts:', createErr);
      // Rollback handled by backend, but we should inform user
      const rollbackInfo = createErr.response?.data?.rollbackAttempted 
        ? ' The backend attempted to rollback any created posts.' 
        : '';
      error.value = `Failed to create posts: ${createErr.response?.data?.message || createErr.message}${rollbackInfo}`;
      throw createErr;
    }
  } catch (err) {
    console.error('Upload error:', err);
    
    // If we uploaded images but didn't create posts, inform user
    if (uploadedImages.length > 0 && !postsCreated) {
      error.value = `Upload failed: ${err.response?.data?.message || err.message || 'Unknown error'}. ${uploadedImages.length} image(s) were uploaded to Cloudflare but no posts were created. The images are stored but not linked to any posts.`;
    } else {
      error.value = err.response?.data?.message || err.message || 'Failed to upload images';
    }
    
    // Show detailed error if available
    if (err.response?.data?.debug) {
      console.error('Upload debug info:', err.response.data.debug);
    }
  } finally {
    uploading.value = false;
    uploadProgress.value = { current: 0, total: 0, currentFile: '' };
  }
};

const handleClose = () => {
  if (!uploading.value) {
    clearFiles();
    emit('close');
  }
};

// Cleanup on unmount
onUnmounted(() => {
  clearFiles();
});
</script>

