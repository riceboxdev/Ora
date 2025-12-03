<template>
  <div class="min-h-screen bg-gray-50">
    <AppHeader />
    
    <main class="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
      <div class="px-4 py-6 sm:px-0">
        <!-- Page Header -->
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-gray-900">Post Migration</h1>
          <p class="text-gray-600 mt-2">Migrate posts from tags/categories to interests taxonomy</p>
        </div>

        <!-- Error Alert -->
        <div v-if="error" class="mb-4 p-4 bg-red-50 border border-red-200 rounded-lg">
          <p class="text-red-800">{{ error }}</p>
        </div>

        <!-- Migration Statistics -->
        <div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
          <div class="bg-white p-6 rounded-lg shadow hover:shadow-md transition-shadow">
            <div class="text-gray-600 text-sm font-medium mb-2">Total Posts</div>
            <div class="text-3xl font-bold text-gray-900">{{ stats.total }}</div>
          </div>
          <div class="bg-blue-50 p-6 rounded-lg shadow hover:shadow-md transition-shadow">
            <div class="text-blue-600 text-sm font-medium mb-2">✓ Migrated</div>
            <div class="text-3xl font-bold text-blue-600">{{ stats.migrated }}</div>
          </div>
          <div class="bg-yellow-50 p-6 rounded-lg shadow hover:shadow-md transition-shadow">
            <div class="text-yellow-600 text-sm font-medium mb-2">⏳ Pending</div>
            <div class="text-3xl font-bold text-yellow-600">{{ stats.pending }}</div>
          </div>
          <div class="bg-green-50 p-6 rounded-lg shadow hover:shadow-md transition-shadow">
            <div class="text-green-600 text-sm font-medium mb-2">Progress</div>
            <div class="text-3xl font-bold text-green-600">{{ stats.percentage }}%</div>
          </div>
        </div>

        <!-- Migration Progress Bar -->
        <div class="bg-white p-6 rounded-lg shadow mb-6">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">Overall Progress</h3>
          <div class="w-full bg-gray-200 rounded-full h-3 overflow-hidden">
            <div 
              class="bg-gradient-to-r from-blue-500 to-green-500 h-3 rounded-full transition-all duration-500"
              :style="{ width: stats.percentage + '%' }"
            ></div>
          </div>
          <p class="text-sm text-gray-600 mt-3">
            {{ stats.migrated }} of {{ stats.total }} posts migrated
          </p>
        </div>

        <!-- Tag Mapping Configuration -->
        <div class="bg-white rounded-lg shadow mb-6 overflow-hidden">
          <div class="bg-gray-50 border-b p-6">
            <h3 class="text-lg font-semibold text-gray-900">Tag → Interest Mappings</h3>
            <p class="text-sm text-gray-600 mt-1">Configure how to map old tags to new interests</p>
          </div>

          <div class="p-6">
            <!-- Pre-configured mappings -->
            <div class="space-y-3 mb-6 max-h-96 overflow-y-auto border rounded-lg p-4 bg-gray-50">
              <div 
                v-for="(interest, tag) in tagMappings"
                :key="tag"
                class="flex items-center gap-3 p-3 bg-white rounded border border-gray-200 hover:border-gray-300 transition-colors"
              >
                <div class="flex-shrink-0 w-32">
                  <span class="font-mono text-sm text-gray-700 font-medium">{{ tag }}</span>
                </div>
                <span class="text-gray-400 text-lg">→</span>
                <select 
                  :value="interest"
                  @change="updateMapping(tag, $event.target.value)"
                  class="flex-1 px-3 py-2 border border-gray-300 rounded text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                >
                  <option value="">-- Clear Mapping --</option>
                  <optgroup label="Base Interests">
                    <option v-for="interest in availableInterests" :key="interest" :value="interest">
                      {{ formatInterestName(interest) }}
                    </option>
                  </optgroup>
                </select>
                <button 
                  @click="removeMapping(tag)"
                  class="flex-shrink-0 text-red-600 hover:text-red-800 font-bold"
                  title="Remove this mapping"
                >
                  ✕
                </button>
              </div>
            </div>

            <!-- Add new mapping -->
            <div class="flex gap-2 mb-6">
              <input 
                v-model="newTagInput"
                type="text"
                placeholder="Tag name..."
                class="flex-1 px-3 py-2 border border-gray-300 rounded text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                @keyup.enter="addNewMapping"
              />
              <select 
                v-model="newInterestInput"
                class="px-3 py-2 border border-gray-300 rounded text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
              >
                <option value="">-- Select Interest --</option>
                <option v-for="interest in availableInterests" :key="interest" :value="interest">
                  {{ formatInterestName(interest) }}
                </option>
              </select>
              <button 
                @click="addNewMapping"
                class="px-4 py-2 bg-gray-200 text-gray-700 rounded hover:bg-gray-300 text-sm font-medium"
              >
                Add
              </button>
            </div>

            <!-- Migration Preview -->
            <button 
              @click="showPreview = !showPreview"
              class="text-blue-600 hover:text-blue-800 text-sm font-medium mb-4"
            >
              {{ showPreview ? '▼ Hide' : '▶ Show' }} Migration Preview
            </button>

            <div v-if="showPreview" class="mb-6 p-4 bg-blue-50 border border-blue-200 rounded">
              <div v-if="previewLoading" class="text-center text-gray-600">
                Loading preview...
              </div>
              <div v-else-if="previewData" class="space-y-3">
                <p class="text-sm text-gray-700 font-medium">
                  Sample: {{ previewData.wouldMigrate }} of {{ previewData.sampleSize }} posts would migrate
                </p>
                <div class="max-h-48 overflow-y-auto space-y-2">
                  <div 
                    v-for="item in previewData.preview.slice(0, 5)"
                    :key="item.postId"
                    class="text-xs p-2 bg-white rounded border border-blue-200"
                  >
                    <div class="font-mono text-gray-600">{{ item.postId.substring(0, 12) }}...</div>
                    <div class="text-gray-600">
                      Tags: {{ item.originalTags.join(', ') || 'none' }}
                    </div>
                    <div class="text-blue-600" v-if="item.willMigrate">
                      → Interests: {{ item.mappedInterests.join(', ') }}
                    </div>
                    <div class="text-gray-400" v-else>
                      → No mapped interests
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Migration Controls -->
        <div class="bg-white rounded-lg shadow overflow-hidden">
          <div class="bg-gray-50 border-b p-6">
            <h3 class="text-lg font-semibold text-gray-900">Start Migration</h3>
          </div>

          <div class="p-6">
            <!-- Settings -->
            <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Batch Size</label>
                <input 
                  v-model.number="batchSize"
                  type="number"
                  min="10"
                  max="1000"
                  class="w-full px-3 py-2 border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
                <p class="text-xs text-gray-500 mt-1">Posts per request (10-1000)</p>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Limit</label>
                <input 
                  v-model.number="limit"
                  type="number"
                  min="0"
                  class="w-full px-3 py-2 border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
                <p class="text-xs text-gray-500 mt-1">Max posts (0 = unlimited)</p>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Mode</label>
                <select 
                  v-model="migrateMode"
                  class="w-full px-3 py-2 border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
                >
                  <option value="unmigrated">Unmigrated Posts Only</option>
                  <option value="all">All Posts</option>
                </select>
              </div>
            </div>

            <!-- Action Buttons -->
            <div class="flex gap-3">
              <button
                @click="startMigration"
                :disabled="isProcessing || Object.keys(tagMappings).length === 0"
                class="px-6 py-3 bg-blue-600 text-white rounded hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed font-medium transition-colors"
              >
                {{ isProcessing ? '⏳ Processing...' : '▶ Start Migration' }}
              </button>
              <button
                @click="refreshStats"
                :disabled="isProcessing"
                class="px-6 py-3 bg-gray-200 text-gray-700 rounded hover:bg-gray-300 disabled:opacity-50 disabled:cursor-not-allowed font-medium transition-colors"
              >
                🔄 Refresh Stats
              </button>
              <button
                @click="resetMappings"
                class="px-6 py-3 bg-gray-200 text-gray-700 rounded hover:bg-gray-300 font-medium transition-colors"
              >
                Reset
              </button>
            </div>

            <!-- Result Message -->
            <div v-if="migrationResult" class="mt-6 p-4 bg-green-50 border border-green-200 rounded-lg">
              <p class="text-green-800 font-medium">✓ Migration completed!</p>
              <p class="text-green-700 text-sm mt-1">
                Migrated: <span class="font-semibold">{{ migrationResult.migrated }}</span> | 
                Skipped: <span class="font-semibold">{{ migrationResult.skipped }}</span>
              </p>
              <div v-if="migrationResult.errors.length > 0" class="mt-3 text-red-700 text-sm">
                <p class="font-medium">Errors:</p>
                <ul class="list-disc list-inside mt-1">
                  <li v-for="err in migrationResult.errors.slice(0, 3)" :key="err.postId">
                    {{ err.postId }}: {{ err.error }}
                  </li>
                </ul>
              </div>
            </div>
          </div>
        </div>
      </div>
    </main>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import AppHeader from '../components/AppHeader.vue';

const stats = ref({
  total: 0,
  migrated: 0,
  pending: 0,
  percentage: 0
});

// Default tag mappings
const tagMappings = ref({
  nature: 'photography',
  landscape: 'travel',
  animals: 'pets',
  food: 'food',
  architecture: 'home',
  people: 'photography',
  art: 'entertainment',
  abstract: 'photography',
  space: 'photography',
  vintage: 'photography'
});

const availableInterests = ref([
  'fashion', 'beauty', 'food', 'fitness', 'home', 
  'travel', 'photography', 'entertainment', 'technology', 'pets'
]);

const batchSize = ref(100);
const limit = ref(0);
const migrateMode = ref('unmigrated');
const isProcessing = ref(false);
const migrationResult = ref(null);
const error = ref(null);
const showPreview = ref(false);
const previewData = ref(null);
const previewLoading = ref(false);

// Add new mapping inputs
const newTagInput = ref('');
const newInterestInput = ref('');

onMounted(() => {
  refreshStats();
});

function formatInterestName(interest) {
  return interest
    .split('-')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
}

async function refreshStats() {
  try {
    error.value = null;
    const response = await fetch('/api/admin/posts/migration-stats');
    const data = await response.json();
    if (data.success) {
      stats.value = data.stats;
    }
  } catch (err) {
    error.value = 'Failed to load statistics';
    console.error('Error fetching stats:', err);
  }
}

async function loadPreview() {
  if (Object.keys(tagMappings.value).length === 0) {
    return;
  }

  previewLoading.value = true;
  try {
    const mappingsJson = JSON.stringify(tagMappings.value);
    const response = await fetch(
      `/api/admin/posts/migration-preview?tagMappings=${encodeURIComponent(mappingsJson)}`
    );
    const data = await response.json();
    if (data.success) {
      previewData.value = data;
    }
  } catch (err) {
    console.error('Error loading preview:', err);
  } finally {
    previewLoading.value = false;
  }
}

async function startMigration() {
  if (!confirm('Start migration with current mappings? This cannot be undone.')) return;
  
  isProcessing.value = true;
  migrationResult.value = null;
  error.value = null;
  
  try {
    const response = await fetch('/api/admin/posts/migrate-interests', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        batchSize: batchSize.value,
        limit: limit.value || null,
        tagMappings: tagMappings.value,
        updateAll: migrateMode.value === 'all'
      })
    });
    
    const data = await response.json();
    if (data.success) {
      migrationResult.value = data;
      setTimeout(() => {
        refreshStats();
      }, 1000);
    } else {
      error.value = data.message || 'Migration failed';
    }
  } catch (err) {
    error.value = err.message || 'Migration error';
    console.error('Migration error:', err);
  } finally {
    isProcessing.value = false;
  }
}

function updateMapping(tag, interest) {
  if (interest) {
    tagMappings.value[tag] = interest;
  }
}

function removeMapping(tag) {
  delete tagMappings.value[tag];
  tagMappings.value = { ...tagMappings.value };
}

function addNewMapping() {
  if (newTagInput.value && newInterestInput.value) {
    tagMappings.value[newTagInput.value.toLowerCase()] = newInterestInput.value;
    tagMappings.value = { ...tagMappings.value };
    newTagInput.value = '';
    newInterestInput.value = '';
  }
}

function resetMappings() {
  if (confirm('Reset all mappings to defaults?')) {
    tagMappings.value = {
      nature: 'photography',
      landscape: 'travel',
      animals: 'pets',
      food: 'food',
      architecture: 'home',
      people: 'photography',
      art: 'entertainment',
      abstract: 'photography',
      space: 'photography',
      vintage: 'photography'
    };
    migrationResult.value = null;
  }
}
</script>
