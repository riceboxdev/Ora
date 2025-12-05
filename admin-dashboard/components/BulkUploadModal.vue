<template>
  <div
    v-if="isOpen"
    class="fixed inset-0 z-50 overflow-y-auto"
    @click.self="$emit('close')"
  >
    <div class="flex items-center justify-center min-h-screen px-4 pt-4 pb-20 text-center sm:block sm:p-0">
      <div class="fixed inset-0 transition-opacity bg-black/50" @click="$emit('close')"></div>

      <Card class="inline-block align-bottom text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-6xl sm:w-full">
        <CardHeader>
          <div class="flex items-center justify-between">
            <CardTitle>Bulk Upload Posts</CardTitle>
            <Button
              @click="handleClose"
              :disabled="uploading"
              variant="ghost"
              size="sm"
            >
              <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </Button>
          </div>
        </CardHeader>
        <CardContent>
          <div class="space-y-6">
            <!-- Step 1: File Upload -->
            <div>
              <label class="block text-sm font-medium text-foreground mb-2">
                Select Images
              </label>
              <div
                @drop="handleDrop"
                @dragover.prevent
                @dragenter.prevent
                :class="[
                  'border-2 border-dashed rounded-lg p-8 text-center cursor-pointer transition-colors',
                  isDragging ? 'border-primary bg-primary/5' : 'border-border hover:border-primary/50'
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
                <svg class="mx-auto h-12 w-12 text-muted-foreground" stroke="currentColor" fill="none" viewBox="0 0 48 48">
                  <path d="M28 8H12a4 4 0 00-4 4v20m32-12v8m0 0v8a4 4 0 01-4 4H12a4 4 0 01-4-4v-4m32-4l-3.172-3.172a4 4 0 00-5.656 0L28 28M8 32l9.172-9.172a4 4 0 015.656 0L28 28m0 0l4 4m4-24h8m-4-4v8m-12 4h.02" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
                </svg>
                <p class="mt-2 text-sm text-muted-foreground">
                  <span class="font-semibold text-primary">Click to upload</span> or drag and drop
                </p>
                <p class="text-xs text-muted-foreground mt-1">PNG, JPG, GIF, WEBP, HEIC up to 50MB each</p>
              </div>
              <Button
                v-if="selectedFiles.length > 0"
                @click="clearFiles"
                variant="ghost"
                size="sm"
                class="mt-2 text-destructive hover:text-destructive"
              >
                Clear all ({{ selectedFiles.length }} files)
              </Button>
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
                  class="w-full h-32 object-cover rounded-lg border border-border"
                />
                <Button
                  @click="removeFile(index)"
                  :disabled="uploading"
                  size="sm"
                  variant="destructive"
                  class="absolute top-1 right-1 opacity-0 group-hover:opacity-100 transition-opacity h-6 w-6 p-0"
                >
                  <svg class="h-3 w-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </Button>
                <div class="mt-1 text-xs text-muted-foreground truncate">{{ file.name }}</div>
              </div>
            </div>

            <!-- Step 2: User Selection -->
            <div v-if="selectedFiles.length > 0">
              <label for="userId" class="block text-sm font-medium text-foreground mb-1">
                User <span class="text-destructive">*</span>
              </label>
              <select
                id="userId"
                v-model="selectedUserId"
                class="w-full px-3 py-2 border border-input bg-background rounded-md focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2"
                :disabled="uploading || loadingUsers"
                required
              >
                <option value="">Select a user...</option>
                <option v-for="user in users" :key="user.id" :value="user.id">
                  {{ user.displayName || user.email || user.id }}
                </option>
              </select>
              <p v-if="loadingUsers" class="mt-1 text-xs text-muted-foreground">Loading users...</p>
            </div>

            <!-- Step 3: Default Metadata -->
            <div v-if="selectedFiles.length > 0" class="border-t border-border pt-4">
              <h4 class="text-sm font-medium text-foreground mb-3">Default Metadata (applies to all images)</h4>
              
              <div class="space-y-4">
                <div>
                  <label for="defaultCaption" class="block text-sm font-medium text-foreground mb-1">
                    Caption
                  </label>
                  <textarea
                    id="defaultCaption"
                    v-model="defaultMetadata.caption"
                    rows="3"
                    class="w-full px-3 py-2 border border-input bg-background rounded-md focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2"
                    placeholder="Enter default caption..."
                    :disabled="uploading"
                  ></textarea>
                </div>

                <!-- Interests Autocomplete -->
                <div>
                  <label for="defaultInterests" class="block text-sm font-medium text-foreground mb-1">
                    Interests
                  </label>
                  <div class="space-y-2">
                    <!-- Interest Search Input -->
                    <div class="relative">
                      <Input
                        v-model="interestSearchQuery"
                        type="text"
                        placeholder="Search interests..."
                        @input="handleInterestSearch"
                        @focus="showInterestDropdown = true"
                        :disabled="uploading || loadingInterests"
                      />
                      
                      <!-- Dropdown -->
                      <div
                        v-if="showInterestDropdown && filteredInterests.length > 0"
                        class="absolute z-10 w-full mt-1 bg-popover border border-border rounded-md shadow-lg max-h-60 overflow-y-auto"
                      >
                        <button
                          v-for="interest in filteredInterests"
                          :key="interest.id"
                          @click="addInterest(interest)"
                          type="button"
                          class="w-full px-3 py-2 text-left hover:bg-accent hover:text-accent-foreground text-sm transition-colors"
                        >
                          <div class="font-medium">{{ interest.displayName }}</div>
                          <div v-if="interest.path" class="text-xs text-muted-foreground">{{ interest.path }}</div>
                        </button>
                      </div>
                    </div>

                    <!-- Selected Interests -->
                    <div v-if="selectedInterests.length > 0" class="flex flex-wrap gap-2">
                      <Badge
                        v-for="interest in selectedInterests"
                        :key="interest.id"
                        variant="secondary"
                        class="pl-2 pr-1"
                      >
                        {{ interest.displayName }}
                        <Button
                          @click="removeInterest(interest.id)"
                          :disabled="uploading"
                          variant="ghost"
                          size="sm"
                          class="ml-1 h-4 w-4 p-0 hover:bg-destructive/20"
                        >
                          <svg class="h-3 w-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                          </svg>
                        </Button>
                      </Badge>
                    </div>
                    
                    <p v-if="loadingInterests" class="text-xs text-muted-foreground">Loading interests...</p>
                    <p v-else class="text-xs text-muted-foreground">Type to search and select interests from the taxonomy</p>
                  </div>
                </div>
              </div>
            </div>

            <!-- Upload Progress -->
            <div v-if="uploading" class="border-t border-border pt-4">
              <div class="mb-2 flex items-center justify-between">
                <span class="text-sm font-medium text-foreground">Upload Progress</span>
                <span class="text-sm text-muted-foreground">{{ uploadProgress.current }} / {{ uploadProgress.total }}</span>
              </div>
              <div class="w-full bg-secondary rounded-full h-2">
                <div
                  class="bg-primary h-2 rounded-full transition-all duration-300"
                  :style="{ width: `${(uploadProgress.current / uploadProgress.total) * 100}%` }"
                ></div>
              </div>
              <p v-if="uploadProgress.currentFile" class="mt-2 text-xs text-muted-foreground">
                Uploading: {{ uploadProgress.currentFile }}
              </p>
            </div>

            <!-- Error Display -->
            <div v-if="error" class="p-3 bg-destructive/10 border border-destructive rounded-md">
              <p class="text-sm text-destructive">{{ error }}</p>
            </div>
          </div>
        </CardContent>

        <div class="bg-muted/50 px-4 py-3 sm:px-6 sm:flex sm:flex-row-reverse gap-3">
          <Button
            @click="handleUpload"
            :disabled="uploading || selectedFiles.length === 0 || !selectedUserId"
          >
            {{ uploading ? `Uploading... (${uploadProgress.current}/${uploadProgress.total})` : `Upload ${selectedFiles.length} Post${selectedFiles.length !== 1 ? 's' : ''}` }}
          </Button>
          <Button
            @click="handleClose"
            :disabled="uploading"
            variant="outline"
          >
            Cancel
          </Button>
        </div>
      </Card>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch, onUnmounted } from 'vue';
import api from '../services/api';
import { useInterestService } from '../composables/interestService';
import Button from '@/components/ui/Button.vue';
import Input from '@/components/ui/Input.vue';
import Card from '@/components/ui/Card.vue';
import CardHeader from '@/components/ui/CardHeader.vue';
import CardTitle from '@/components/ui/CardTitle.vue';
import CardContent from '@/components/ui/CardContent.vue';
import Badge from '@/components/ui/Badge.vue';

const props = defineProps({
  isOpen: {
    type: Boolean,
    default: false
  }
});

const emit = defineEmits(['close', 'uploaded']);

const { getInterests, getInterestTree } = useInterestService();

const fileInput = ref(null);
const selectedFiles = ref([]);
const isDragging = ref(false);
const users = ref([]);
const loadingUsers = ref(false);
const selectedUserId = ref('');
const defaultMetadata = ref({
  caption: '',
  interests: []
});

// Interests state
const allInterests = ref([]);
const loadingInterests = ref(false);
const selectedInterests = ref([]);
const interestSearchQuery = ref('');
const showInterestDropdown = ref(false);

const uploading = ref(false);
const uploadProgress = ref({
  current: 0,
  total: 0,
  currentFile: ''
});
const error = ref(null);

// Filtered interests based on search query
const filteredInterests = computed(() => {
  if (!interestSearchQuery.value) {
    return allInterests.value.slice(0, 10); // Show top 10 by default
  }
  
  const query = interestSearchQuery.value.toLowerCase();
  return allInterests.value
    .filter(interest => {
      // Search in display name, keywords, and synonyms
      const searchText = [
        interest.displayName,
        ...(interest.keywords || []),
        ...(interest.synonyms || [])
      ].join(' ').toLowerCase();
      
      return searchText.includes(query);
    })
    .slice(0, 20); // Limit results
});

// Load users and interests when modal opens
watch(() => props.isOpen, async (isOpen) => {
  if (isOpen) {
    await Promise.all([fetchUsers(), fetchInterests()]);
    resetForm();
  }
});

// Close dropdown when clicking outside
watch(interestSearchQuery, () => {
  if (!interestSearchQuery.value) {
    showInterestDropdown.value = false;
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

const fetchInterests = async () => {
  try {
    loadingInterests.value = true;
    // Get all interests (not just root)
    const interests = await getInterests();
    
    // Flatten the tree to get all interests
    const flattenInterests = (interests, parentPath = '') => {
      return interests.flatMap(interest => {
        const path = parentPath ? `${parentPath} > ${interest.displayName}` : interest.displayName;
        const flattened = [{
          ...interest,
          path
        }];
        
        if (interest.children && interest.children.length > 0) {
          flattened.push(...flattenInterests(interest.children, path));
        }
        
        return flattened;
      });
    };
    
    // Try to get the full tree for better context
    try {
      const tree = await getInterestTree();
      allInterests.value = flattenInterests(tree);
    } catch {
      // Fallback to simple list
      allInterests.value = interests.map(i => ({
        ...i,
        path: i.displayName
      }));
    }
  } catch (err) {
    console.error('Error fetching interests:', err);
    error.value = 'Failed to load interests';
  } finally {
    loadingInterests.value = false;
  }
};

const handleInterestSearch = () => {
  showInterestDropdown.value = true;
};

const addInterest = (interest) => {
  // Don't add if already selected
  if (!selectedInterests.value.find(i => i.id === interest.id)) {
    selectedInterests.value.push(interest);
  }
  
  // Clear search and hide dropdown
  interestSearchQuery.value = '';
  showInterestDropdown.value = false;
};

const removeInterest = (interestId) => {
  selectedInterests.value = selectedInterests.value.filter(i => i.id !== interestId);
};

const resetForm = () => {
  selectedFiles.value = [];
  selectedUserId.value = '';
  defaultMetadata.value = { caption: '', interests: [] };
  selectedInterests.value = [];
  interestSearchQuery.value = '';
  showInterestDropdown.value = false;
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
  }
};

const clearFiles = () => {
  selectedFiles.value.forEach(file => {
    URL.revokeObjectURL(file.preview);
  });
  selectedFiles.value = [];
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
  const uploadedImageUrls = [];
  let postsCreated = false;

  try {
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

        const uploadResponse = await api.post('/api/admin/posts/upload-image', formData, {
          timeout: 60000,
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
        if (uploadedImages.length > 0) {
          error.value = `Failed to upload ${fileData.name}. ${uploadedImages.length} image(s) were uploaded but will not be used.`;
          throw new Error(`Upload failed at ${fileData.name}. Partial upload detected.`);
        } else {
          throw uploadErr;
        }
      }
    }

    // Step 2: Create posts with interests
    uploadProgress.value.current = selectedFiles.value.length;
    const posts = uploadedImages.map((img, idx) => {
      const fileIndex = img.index;
      
      return {
        userId: selectedUserId.value,
        imageUrl: img.imageUrl,
        thumbnailUrl: img.thumbnailUrl,
        imageWidth: img.imageWidth || selectedFiles.value[fileIndex].width,
        imageHeight: img.imageHeight || selectedFiles.value[fileIndex].height,
        caption: defaultMetadata.value.caption || null,
        // Use interest IDs instead of tags/categories
        interestIds: selectedInterests.value.map(i => i.id)
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
      const rollbackInfo = createErr.response?.data?.rollbackAttempted 
        ? ' The backend attempted to rollback any created posts.' 
        : '';
      error.value = `Failed to create posts: ${createErr.response?.data?.message || createErr.message}${rollbackInfo}`;
      throw createErr;
    }
  } catch (err) {
    console.error('Upload error:', err);
    
    if (uploadedImages.length > 0 && !postsCreated) {
      error.value = `Upload failed: ${err.response?.data?.message || err.message || 'Unknown error'}. ${uploadedImages.length} image(s) were uploaded to Cloudflare but no posts were created.`;
    } else {
      error.value = err.response?.data?.message || err.message || 'Failed to upload images';
    }
    
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
