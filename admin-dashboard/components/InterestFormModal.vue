<template>
  <TransitionRoot appear :show="show" as="template">
    <Dialog as="div" @close="closeModal" class="relative z-50">
      <TransitionChild
        as="template"
        enter="duration-300 ease-out"
        enter-from="opacity-0"
        enter-to="opacity-100"
        leave="duration-200 ease-in"
        leave-from="opacity-100"
        leave-to="opacity-0"
      >
        <div class="fixed inset-0 bg-black/25" />
      </TransitionChild>

      <div class="fixed inset-0 overflow-y-auto">
        <div class="flex min-h-full items-center justify-center p-4 text-center">
          <TransitionChild
            as="template"
            enter="duration-300 ease-out"
            enter-from="opacity-0 scale-95"
            enter-to="opacity-100 scale-100"
            leave="duration-200 ease-in"
            leave-from="opacity-100 scale-100"
            leave-to="opacity-0 scale-95"
          >
            <DialogPanel class="w-full max-w-2xl transform overflow-hidden rounded-2xl bg-white p-6 text-left align-middle shadow-xl transition-all">
              <DialogTitle as="h3" class="text-lg font-medium leading-6 text-gray-900">
                {{ mode === 'create' ? 'Create New Interest' : 'Edit Interest' }}
              </DialogTitle>
              
              <form @submit.prevent="handleSubmit" class="mt-4 space-y-6">
                <div class="space-y-4">
                  <!-- Name -->
                  <div>
                    <label for="name" class="block text-sm font-medium text-gray-700">
                      Name <span class="text-red-500">*</span>
                    </label>
                    <div class="mt-1">
                      <input
                        type="text"
                        id="name"
                        v-model="formData.name"
                        required
                        :disabled="mode === 'edit'"
                        class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm disabled:bg-gray-100 disabled:cursor-not-allowed"
                        placeholder="e.g., runway-models"
                      />
                    </div>
                    <p class="mt-1 text-xs text-gray-500">
                      A unique identifier for this interest (lowercase, hyphens, no spaces).
                      <span v-if="mode === 'edit'" class="text-amber-600">Changing the name will update all references.</span>
                    </p>
                  </div>

                  <!-- Display Name -->
                  <div>
                    <label for="displayName" class="block text-sm font-medium text-gray-700">
                      Display Name <span class="text-red-500">*</span>
                    </label>
                    <div class="mt-1">
                      <input
                        type="text"
                        id="displayName"
                        v-model="formData.displayName"
                        required
                        class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                        placeholder="e.g., Runway Models"
                      />
                    </div>
                    <p class="mt-1 text-xs text-gray-500">
                      The name that will be displayed to users.
                    </p>
                  </div>

                  <!-- Parent Interest -->
                  <div>
                    <label for="parentId" class="block text-sm font-medium text-gray-700">
                      Parent Interest
                    </label>
                    <div class="mt-1">
                      <select
                        id="parentId"
                        v-model="formData.parentId"
                        class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                        :disabled="mode === 'edit'"
                      >
                        <option :value="null">None (Top Level)</option>
                        <optgroup v-for="level in 0..maxParentLevel" :key="level" :label="`Level ${level} Interests`">
                          <option 
                            v-for="parent in getParentsByLevel(level)" 
                            :key="parent.id" 
                            :value="parent.id"
                            :disabled="isDescendant(interest?.id, parent.id)"
                          >
                            {{ '— '.repeat(level) }} {{ parent.name }}
                          </option>
                        </optgroup>
                      </select>
                    </div>
                    <p class="mt-1 text-xs text-gray-500">
                      Select a parent interest or leave as "None" for a top-level interest.
                      <span v-if="mode === 'edit'" class="text-amber-600">Changing the parent requires a move operation.</span>
                    </p>
                  </div>

                  <!-- Description -->
                  <div>
                    <label for="description" class="block text-sm font-medium text-gray-700">
                      Description
                    </label>
                    <div class="mt-1">
                      <textarea
                        id="description"
                        v-model="formData.description"
                        rows="3"
                        class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                        placeholder="A brief description of this interest"
                      ></textarea>
                    </div>
                  </div>

                  <!-- Keywords -->
                  <div>
                    <label for="keywords" class="block text-sm font-medium text-gray-700">
                      Keywords
                    </label>
                    <div class="mt-1">
                      <div class="flex flex-wrap gap-2 p-2 border border-gray-300 rounded-md">
                        <span 
                          v-for="(keyword, index) in formData.keywords" 
                          :key="index"
                          class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-indigo-100 text-indigo-800"
                        >
                          {{ keyword }}
                          <button 
                            type="button"
                            @click="removeKeyword(index)"
                            class="ml-1.5 inline-flex items-center justify-center h-4 w-4 rounded-full text-indigo-400 hover:bg-indigo-200 hover:text-indigo-500 focus:outline-none focus:bg-indigo-500 focus:text-white"
                          >
                            <span class="sr-only">Remove keyword</span>
                            <svg class="h-2 w-2" stroke="currentColor" fill="none" viewBox="0 0 8 8">
                              <path stroke-linecap="round" stroke-width="1.5" d="M1 1l6 6m0-6L1 7" />
                            </svg>
                          </button>
                        </span>
                        <input
                          type="text"
                          id="keywords"
                          v-model="keywordInput"
                          @keydown.enter.prevent="addKeyword"
                          @keydown.space.enter.prevent="addKeyword"
                          @keydown.backspace="handleBackspace"
                          class="flex-1 border-0 focus:ring-0 focus:outline-none text-sm"
                          placeholder="Add keywords..."
                        />
                      </div>
                    </div>
                    <p class="mt-1 text-xs text-gray-500">
                      Press Enter or Space to add a keyword. These help with search and discovery.
                    </p>
                  </div>

                  <!-- Synonyms -->
                  <div>
                    <label for="synonyms" class="block text-sm font-medium text-gray-700">
                      Synonyms
                    </label>
                    <div class="mt-1">
                      <div class="flex flex-wrap gap-2 p-2 border border-gray-300 rounded-md">
                        <span 
                          v-for="(synonym, index) in formData.synonyms" 
                          :key="index"
                          class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-purple-100 text-purple-800"
                        >
                          {{ synonym }}
                          <button 
                            type="button"
                            @click="removeSynonym(index)"
                            class="ml-1.5 inline-flex items-center justify-center h-4 w-4 rounded-full text-purple-400 hover:bg-purple-200 hover:text-purple-500 focus:outline-none focus:bg-purple-500 focus:text-white"
                          >
                            <span class="sr-only">Remove synonym</span>
                            <svg class="h-2 w-2" stroke="currentColor" fill="none" viewBox="0 0 8 8">
                              <path stroke-linecap="round" stroke-width="1.5" d="M1 1l6 6m0-6L1 7" />
                            </svg>
                          </button>
                        </span>
                        <input
                          type="text"
                          id="synonyms"
                          v-model="synonymInput"
                          @keydown.enter.prevent="addSynonym"
                          @keydown.space.enter.prevent="addSynonym"
                          @keydown.backspace="handleBackspace('synonym')"
                          class="flex-1 border-0 focus:ring-0 focus:outline-none text-sm"
                          placeholder="Add synonyms..."
                        />
                      </div>
                    </div>
                    <p class="mt-1 text-xs text-gray-500">
                      Alternative names or spellings for this interest.
                    </p>
                  </div>

                  <!-- Related Interests -->
                  <div>
                    <label for="relatedInterests" class="block text-sm font-medium text-gray-700">
                      Related Interests
                    </label>
                    <div class="mt-1">
                      <Multiselect
                        v-model="formData.relatedInterestIds"
                        :options="availableRelatedInterests"
                        mode="tags"
                        :close-on-select="false"
                        :searchable="true"
                        :create-option="false"
                        placeholder="Select related interests..."
                        :max-height="150"
                        :object="true"
                        track-by="id"
                        label="displayName"
                        class="multiselect-tags"
                      />
                    </div>
                    <p class="mt-1 text-xs text-gray-500">
                      Select other interests that are related to this one.
                    </p>
                  </div>

                  <!-- Cover Image -->
                  <div>
                    <label class="block text-sm font-medium text-gray-700">
                      Cover Image
                    </label>
                    <div class="mt-1 flex items-center">
                      <span class="inline-block h-12 w-12 overflow-hidden rounded-full bg-gray-100">
                        <img
                          v-if="formData.coverImageUrl"
                          :src="formData.coverImageUrl"
                          :alt="`${formData.displayName} cover`"
                          class="h-full w-full object-cover"
                        />
                        <svg
                          v-else
                          class="h-full w-full text-gray-300"
                          fill="currentColor"
                          viewBox="0 0 24 24"
                        >
                          <path d="M24 20.993V24H0v-2.996A14.977 14.977 0 0112.004 15c4.904 0 9.26 2.354 11.996 5.993zM16.002 8.999a4 4 0 11-8 0 4 4 0 018 0z" />
                        </svg>
                      </span>
                      <button
                        type="button"
                        class="ml-5 rounded-md border border-gray-300 bg-white py-2 px-3 text-sm font-medium leading-4 text-gray-700 shadow-sm hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
                      >
                        Change
                      </button>
                    </div>
                  </div>

                  <!-- Active Status -->
                  <div class="flex items-start">
                    <div class="flex items-center h-5">
                      <input
                        id="isActive"
                        v-model="formData.isActive"
                        type="checkbox"
                        class="h-4 w-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-500"
                      />
                    </div>
                    <div class="ml-3 text-sm">
                      <label for="isActive" class="font-medium text-gray-700">Active</label>
                      <p class="text-gray-500">Inactive interests won't be shown to users.</p>
                    </div>
                  </div>
                </div>

                <div class="mt-6 flex items-center justify-end space-x-3">
                  <button
                    type="button"
                    @click="closeModal"
                    class="inline-flex justify-center rounded-md border border-gray-300 bg-white py-2 px-4 text-sm font-medium text-gray-700 shadow-sm hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    :disabled="isSubmitting"
                    class="inline-flex justify-center rounded-md border border-transparent bg-indigo-600 py-2 px-4 text-sm font-medium text-white shadow-sm hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    {{ isSubmitting ? 'Saving...' : 'Save Interest' }}
                  </button>
                </div>
              </form>
            </DialogPanel>
          </TransitionChild>
        </div>
      </div>
    </Dialog>
  </TransitionRoot>
</template>

<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { Dialog, DialogPanel, DialogTitle, TransitionChild, TransitionRoot } from '@headlessui/vue';
import Multiselect from '@vueform/multiselect';
import '@vueform/multiselect/themes/default.css';

const props = defineProps({
  show: {
    type: Boolean,
    required: true
  },
  interest: {
    type: Object,
    default: () => ({
      name: '',
      displayName: '',
      parentId: null,
      description: '',
      isActive: true,
      keywords: [],
      synonyms: [],
      relatedInterestIds: []
    })
  },
  parentInterests: {
    type: Array,
    default: () => []
  },
  mode: {
    type: String,
    default: 'create',
    validator: (value) => ['create', 'edit'].includes(value)
  }
});

const emit = defineEmits(['close', 'saved']);

// Form data
const formData = ref({
  ...props.interest,
  relatedInterestIds: props.interest.relatedInterestIds || []
});

// UI state
const isSubmitting = ref(false);
const keywordInput = ref('');
const synonymInput = ref('');
const lastRemovedKeyword = ref(null);
const lastRemovedSynonym = ref(null);

// Computed properties
const availableRelatedInterests = computed(() => {
  return props.parentInterests
    .filter(interest => interest.id !== props.interest?.id) // Exclude self
    .map(interest => ({
      id: interest.id,
      displayName: interest.path ? `${interest.path} > ${interest.name}` : interest.name
    }));
});

const maxParentLevel = computed(() => {
  if (!props.parentInterests.length) return 0;
  return Math.max(...props.parentInterests.map(i => i.level || 0));
});

// Methods
const closeModal = () => {
  emit('close');
};

const handleSubmit = async () => {
  isSubmitting.value = true;
  
  try {
    // Prepare the data for submission
    const submissionData = {
      ...formData.value,
      // Ensure arrays are properly formatted
      keywords: formData.value.keywords || [],
      synonyms: formData.value.synonyms || [],
      relatedInterestIds: formData.value.relatedInterestIds || []
    };
    
    // In a real app, you would call your API here
    // const response = mode.value === 'create' 
    //   ? await api.post('/interests', submissionData)
    //   : await api.put(`/interests/${formData.value.id}`, submissionData);
    
    // For now, we'll just emit the form data
    emit('saved', submissionData);
    
    // Reset form
    if (props.mode === 'create') {
      formData.value = {
        name: '',
        displayName: '',
        parentId: null,
        description: '',
        isActive: true,
        keywords: [],
        synonyms: [],
        relatedInterestIds: []
      };
    }
    
    closeModal();
  } catch (error) {
    console.error('Failed to save interest:', error);
    // Show error notification
  } finally {
    isSubmitting.value = false;
  }
};

// Keyword management
const addKeyword = () => {
  const keyword = keywordInput.value.trim();
  if (keyword && !formData.value.keywords.includes(keyword)) {
    formData.value.keywords = [...(formData.value.keywords || []), keyword];
  }
  keywordInput.value = '';
};

const removeKeyword = (index) => {
  lastRemovedKeyword.value = formData.value.keywords[index];
  formData.value.keywords = formData.value.keywords.filter((_, i) => i !== index);
};

// Synonym management
const addSynonym = () => {
  const synonym = synonymInput.value.trim();
  if (synonym && !formData.value.synonyms.includes(synonym)) {
    formData.value.synonyms = [...(formData.value.synonyms || []), synonym];
  }
  synonymInput.value = '';
};

const removeSynonym = (index) => {
  lastRemovedSynonym.value = formData.value.synonyms[index];
  formData.value.synonyms = formData.value.synonyms.filter((_, i) => i !== index);
};

// Handle backspace to restore last removed item
const handleBackspace = (type) => {
  if (type === 'synonym') {
    if (synonymInput.value === '' && lastRemovedSynonym.value) {
      addSynonym(lastRemovedSynonym.value);
      lastRemovedSynonym.value = null;
    }
  } else {
    if (keywordInput.value === '' && lastRemovedKeyword.value) {
      addKeyword(lastRemovedKeyword.value);
      lastRemovedKeyword.value = null;
    }
  }
};

// Helper methods
const getParentsByLevel = (level) => {
  return props.parentInterests.filter(interest => (interest.level || 0) === level);
};

const isDescendant = (currentId, parentId) => {
  if (!currentId || !parentId) return false;
  // In a real app, you would check the hierarchy
  return false;
};

// Watch for prop changes
watch(() => props.interest, (newInterest) => {
  formData.value = {
    ...newInterest,
    relatedInterestIds: newInterest.relatedInterestIds || []
  };
}, { immediate: true });
</script>

<style scoped>
/* Custom styles for the multiselect component */
:deep(.multiselect-tags) {
  @apply border-gray-300 rounded-md shadow-sm focus:border-indigo-500 focus:ring-indigo-500;
}
:deep(.multiselect-tag) {
  @apply bg-indigo-100 text-indigo-800 text-xs font-medium mr-1 mb-1;
}
:deep(.multiselect-tag-remove) {
  @apply text-indigo-400 hover:text-indigo-600 hover:bg-indigo-200;
}
:deep(.multiselect-option) {
  @apply text-sm;
}
:deep(.multiselect-option.is-selected) {
  @apply bg-indigo-100 text-indigo-900;
}
:deep(.multiselect-option.is-pointed) {
  @apply bg-indigo-50 text-indigo-900;
}
</style>
