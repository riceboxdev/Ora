<template>
  <div class="min-h-screen bg-gray-50">
    <AppHeader />
    
    <main class="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
      <div class="px-4 py-6 sm:px-0">
        <!-- Page Header -->
        <div class="mb-8">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-3xl font-bold text-gray-900">Enhanced Post Migration</h1>
              <p class="text-gray-600 mt-2">Intelligent migration from tags to interests with real-time progress</p>
            </div>
            <div class="flex gap-3">
              <button
                @click="refreshAllData"
                :disabled="isLoading"
                class="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 disabled:opacity-50 font-medium transition-colors"
              >
                🔄 Refresh
              </button>
              <button
                @click="showMigrationHistory = !showMigrationHistory"
                class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 font-medium transition-colors"
              >
                📊 History
              </button>
            </div>
          </div>
        </div>

        <!-- Alert Messages -->
        <div v-if="alert.show" :class="alertClasses" class="mb-6 p-4 rounded-lg border">
          <div class="flex items-center">
            <span class="text-xl mr-3">{{ alert.icon }}</span>
            <div class="flex-1">
              <p class="font-medium">{{ alert.title }}</p>
              <p v-if="alert.message" class="text-sm mt-1 opacity-90">{{ alert.message }}</p>
            </div>
            <button @click="alert.show = false" class="ml-4 text-lg font-bold opacity-70 hover:opacity-100">×</button>
          </div>
        </div>

        <!-- Migration Statistics Dashboard -->
        <div class="grid grid-cols-1 md:grid-cols-5 gap-4 mb-8">
          <div class="bg-white p-6 rounded-lg shadow hover:shadow-md transition-shadow">
            <div class="text-gray-600 text-sm font-medium mb-2">Total Posts</div>
            <div class="text-3xl font-bold text-gray-900">{{ migrationStats.total }}</div>
          </div>
          <div class="bg-blue-50 p-6 rounded-lg shadow hover:shadow-md transition-shadow">
            <div class="text-blue-600 text-sm font-medium mb-2">✓ Completed</div>
            <div class="text-3xl font-bold text-blue-600">{{ migrationStats.completed }}</div>
          </div>
          <div class="bg-yellow-50 p-6 rounded-lg shadow hover:shadow-md transition-shadow">
            <div class="text-yellow-600 text-sm font-medium mb-2">⏳ Running</div>
            <div class="text-3xl font-bold text-yellow-600">{{ migrationStats.running }}</div>
          </div>
          <div class="bg-red-50 p-6 rounded-lg shadow hover:shadow-md transition-shadow">
            <div class="text-red-600 text-sm font-medium mb-2">❌ Failed</div>
            <div class="text-3xl font-bold text-red-600">{{ migrationStats.failed }}</div>
          </div>
          <div class="bg-green-50 p-6 rounded-lg shadow hover:shadow-md transition-shadow">
            <div class="text-green-600 text-sm font-medium mb-2">Success Rate</div>
            <div class="text-3xl font-bold text-green-600">{{ migrationStats.successRate }}%</div>
          </div>
        </div>

        <!-- Active Migration Progress -->
        <div v-if="activeMigration" class="bg-white rounded-lg shadow mb-8">
          <div class="bg-gradient-to-r from-blue-500 to-green-500 text-white p-6 rounded-t-lg">
            <div class="flex items-center justify-between">
              <div>
                <h3 class="text-xl font-semibold">{{ activeMigration.id }}</h3>
                <p class="opacity-90">Status: {{ formatStatus(activeMigration.status) }}</p>
              </div>
              <div class="flex gap-2">
                <button
                  v-if="activeMigration.status === 'running'"
                  @click="pauseMigration(activeMigration.id)"
                  class="px-4 py-2 bg-white bg-opacity-20 rounded hover:bg-opacity-30 transition-colors"
                >
                  ⏸️ Pause
                </button>
                <button
                  v-if="activeMigration.status === 'paused'"
                  @click="startMigration(activeMigration.id)"
                  class="px-4 py-2 bg-white bg-opacity-20 rounded hover:bg-opacity-30 transition-colors"
                >
                  ▶️ Resume
                </button>
                <button
                  v-if="['running', 'paused'].includes(activeMigration.status)"
                  @click="stopMigration(activeMigration.id)"
                  class="px-4 py-2 bg-red-600 bg-opacity-80 rounded hover:bg-opacity-100 transition-colors"
                >
                  ⏹️ Stop
                </button>
              </div>
            </div>
          </div>
          
          <div class="p-6">
            <!-- Progress Bar -->
            <div class="mb-4">
              <div class="flex justify-between text-sm text-gray-600 mb-2">
                <span>Progress</span>
                <span>{{ activeMigration.progress.processed || 0 }} / {{ activeMigration.progress.total || 0 }}</span>
              </div>
              <div class="w-full bg-gray-200 rounded-full h-3">
                <div 
                  class="bg-gradient-to-r from-blue-500 to-green-500 h-3 rounded-full transition-all duration-500"
                  :style="{ width: (activeMigration.progress.percentage || 0) + '%' }"
                ></div>
              </div>
              <div class="text-center text-sm text-gray-600 mt-2">
                {{ activeMigration.progress.percentage || 0 }}% Complete
              </div>
            </div>

            <!-- Progress Details -->
            <div class="grid grid-cols-2 md:grid-cols-4 gap-4 text-center">
              <div class="bg-green-50 p-3 rounded">
                <div class="text-2xl font-bold text-green-600">{{ activeMigration.progress.migrated || 0 }}</div>
                <div class="text-sm text-gray-600">Migrated</div>
              </div>
              <div class="bg-gray-50 p-3 rounded">
                <div class="text-2xl font-bold text-gray-600">{{ activeMigration.progress.skipped || 0 }}</div>
                <div class="text-sm text-gray-600">Skipped</div>
              </div>
              <div class="bg-red-50 p-3 rounded">
                <div class="text-2xl font-bold text-red-600">{{ activeMigration.progress.failed || 0 }}</div>
                <div class="text-sm text-gray-600">Failed</div>
              </div>
              <div class="bg-blue-50 p-3 rounded">
                <div class="text-2xl font-bold text-blue-600">{{ activeMigration.progress.processed || 0 }}</div>
                <div class="text-sm text-gray-600">Processed</div>
              </div>
            </div>

            <!-- Errors (if any) -->
            <div v-if="activeMigration.errors && activeMigration.errors.length > 0" class="mt-4">
              <h4 class="text-red-600 font-medium mb-2">Recent Errors ({{ activeMigration.errors.length }})</h4>
              <div class="max-h-32 overflow-y-auto bg-red-50 border border-red-200 rounded p-3">
                <div v-for="error in activeMigration.errors.slice(-3)" :key="error.timestamp" class="text-sm text-red-700 mb-1">
                  {{ error.postId }}: {{ error.message }}
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Smart Tag Analysis -->
        <div class="bg-white rounded-lg shadow mb-8">
          <div class="bg-gray-50 border-b p-6">
            <div class="flex items-center justify-between">
              <div>
                <h3 class="text-lg font-semibold text-gray-900">Smart Tag Analysis</h3>
                <p class="text-sm text-gray-600 mt-1">AI-powered mapping suggestions based on your data</p>
              </div>
              <button
                @click="analyzeTagsForMappings"
                :disabled="isAnalyzing"
                class="px-4 py-2 bg-purple-600 text-white rounded hover:bg-purple-700 disabled:opacity-50 font-medium transition-colors"
              >
                {{ isAnalyzing ? '🔄 Analyzing...' : '🧠 Analyze Tags' }}
              </button>
            </div>
          </div>

          <div v-if="tagAnalysis" class="p-6">
            <div class="mb-4 text-sm text-gray-600">
              Found {{ tagAnalysis.totalTags }} unique tags from {{ tagAnalysis.analysisMetadata.postsAnalyzed }} posts
            </div>
            
            <div class="max-h-96 overflow-y-auto">
              <div class="grid gap-3">
                <div 
                  v-for="suggestion in tagAnalysis.suggestions.slice(0, 20)" 
                  :key="suggestion.tag"
                  class="flex items-center gap-4 p-3 bg-gray-50 rounded border hover:border-gray-300 transition-colors"
                >
                  <div class="flex-shrink-0 w-32">
                    <div class="font-mono text-sm font-medium">{{ suggestion.tag }}</div>
                    <div class="text-xs text-gray-500">{{ suggestion.count }} posts</div>
                  </div>
                  
                  <div class="flex-shrink-0">
                    <div class="text-xs text-gray-500 mb-1">Confidence: {{ Math.round(suggestion.confidence * 100) }}%</div>
                    <div :class="confidenceBarClass(suggestion.confidence)" class="w-16 h-2 rounded-full"></div>
                  </div>
                  
                  <span class="text-gray-400 text-lg">→</span>
                  
                  <select 
                    :value="tagMappings[suggestion.tag] || suggestion.suggestedInterest"
                    @change="updateMapping(suggestion.tag, $event.target.value)"
                    class="flex-1 px-3 py-2 border border-gray-300 rounded text-sm focus:outline-none focus:ring-2 focus:ring-purple-500"
                  >
                    <option value="">-- No Mapping --</option>
                    <optgroup label="Available Interests">
                      <option v-for="interest in availableInterests" :key="interest" :value="interest">
                        {{ formatInterestName(interest) }}
                      </option>
                    </optgroup>
                  </select>
                  
                  <button
                    @click="applyMapping(suggestion.tag, suggestion.suggestedInterest)"
                    :disabled="tagMappings[suggestion.tag] === suggestion.suggestedInterest"
                    class="flex-shrink-0 px-3 py-2 bg-green-100 text-green-700 rounded text-sm hover:bg-green-200 disabled:opacity-50 transition-colors"
                  >
                    Apply
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Tag Mappings Configuration -->
        <div class="bg-white rounded-lg shadow mb-8">
          <div class="bg-gray-50 border-b p-6">
            <h3 class="text-lg font-semibold text-gray-900">Tag → Interest Mappings</h3>
            <p class="text-sm text-gray-600 mt-1">Configure how tags should map to interests</p>
          </div>

          <div class="p-6">
            <!-- Current mappings -->
            <div v-if="Object.keys(tagMappings).length > 0" class="space-y-3 mb-6 max-h-96 overflow-y-auto border rounded-lg p-4 bg-gray-50">
              <div 
                v-for="(interest, tag) in tagMappings"
                :key="tag"
                class="flex items-center gap-3 p-3 bg-white rounded border border-gray-200 hover:border-gray-300 transition-colors"
              >
                <div class="flex-shrink-0 w-32">
                  <span class="font-mono text-sm text-gray-700 font-medium">{{ tag }}</span>
                </div>
                <span class="text-gray-400 text-lg">→</span>
                <div class="flex-1">
                  <span class="px-3 py-1 bg-blue-100 text-blue-700 rounded-full text-sm font-medium">
                    {{ formatInterestName(interest) }}
                  </span>
                </div>
                <button 
                  @click="removeMapping(tag)"
                  class="flex-shrink-0 text-red-600 hover:text-red-800 font-bold"
                  title="Remove this mapping"
                >
                  ✕
                </button>
              </div>
            </div>

            <!-- Add new mapping manually -->
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
                :disabled="!newTagInput || !newInterestInput"
                class="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 disabled:opacity-50 text-sm font-medium transition-colors"
              >
                Add Mapping
              </button>
            </div>
          </div>
        </div>

        <!-- Migration Configuration & Controls -->
        <div class="bg-white rounded-lg shadow mb-8">
          <div class="bg-gray-50 border-b p-6">
            <h3 class="text-lg font-semibold text-gray-900">Migration Configuration</h3>
            <p class="text-sm text-gray-600 mt-1">Configure and start your migration</p>
          </div>

          <div class="p-6">
            <!-- Configuration Options -->
            <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-6">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Batch Size</label>
                <input 
                  v-model.number="migrationConfig.batchSize"
                  type="number"
                  min="10"
                  max="500"
                  class="w-full px-3 py-2 border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
                <p class="text-xs text-gray-500 mt-1">Posts per batch (10-500)</p>
              </div>
              
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Post Limit</label>
                <input 
                  v-model.number="migrationConfig.limit"
                  type="number"
                  min="0"
                  class="w-full px-3 py-2 border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
                />
                <p class="text-xs text-gray-500 mt-1">Max posts to migrate (0 = unlimited)</p>
              </div>
              
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Update Mode</label>
                <select 
                  v-model="migrationConfig.updateAll"
                  class="w-full px-3 py-2 border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
                >
                  <option :value="false">Unmigrated Posts Only</option>
                  <option :value="true">All Posts (Overwrite)</option>
                </select>
              </div>
            </div>

            <!-- Validation Results -->
            <div v-if="validationResult" class="mb-6">
              <div v-if="!validationResult.valid" class="bg-red-50 border border-red-200 rounded p-4 mb-4">
                <h4 class="text-red-800 font-medium mb-2">❌ Configuration Errors</h4>
                <ul class="text-red-700 text-sm space-y-1">
                  <li v-for="error in validationResult.errors" :key="error">• {{ error }}</li>
                </ul>
              </div>
              
              <div v-if="validationResult.warnings && validationResult.warnings.length > 0" class="bg-yellow-50 border border-yellow-200 rounded p-4 mb-4">
                <h4 class="text-yellow-800 font-medium mb-2">⚠️ Warnings</h4>
                <ul class="text-yellow-700 text-sm space-y-1">
                  <li v-for="warning in validationResult.warnings" :key="warning">• {{ warning }}</li>
                </ul>
              </div>
            </div>

            <!-- Action Buttons -->
            <div class="flex gap-3">
              <button
                @click="validateConfiguration"
                :disabled="isLoading || Object.keys(tagMappings).length === 0"
                class="px-6 py-3 bg-purple-600 text-white rounded-lg hover:bg-purple-700 disabled:opacity-50 font-medium transition-colors"
              >
                {{ isLoading ? '⏳' : '🔍' }} Validate
              </button>
              
              <button
                @click="runDryRun"
                :disabled="isLoading || !validationResult?.valid"
                class="px-6 py-3 bg-yellow-600 text-white rounded-lg hover:bg-yellow-700 disabled:opacity-50 font-medium transition-colors"
              >
                {{ isLoading ? '⏳ Running...' : '🧪 Dry Run' }}
              </button>
              
              <button
                @click="createAndStartMigration"
                :disabled="isLoading || !validationResult?.valid || activeMigration"
                class="px-6 py-3 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:opacity-50 font-medium transition-colors"
              >
                {{ isLoading ? '⏳ Starting...' : '▶️ Start Migration' }}
              </button>
              
              <button
                @click="resetConfiguration"
                class="px-6 py-3 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 font-medium transition-colors"
              >
                🔄 Reset
              </button>
            </div>
          </div>
        </div>

        <!-- Migration History -->
        <div v-if="showMigrationHistory" class="bg-white rounded-lg shadow">
          <div class="bg-gray-50 border-b p-6">
            <h3 class="text-lg font-semibold text-gray-900">Migration History</h3>
            <p class="text-sm text-gray-600 mt-1">Recent migration jobs and their status</p>
          </div>

          <div class="overflow-x-auto">
            <table class="w-full">
              <thead class="bg-gray-50 border-b">
                <tr>
                  <th class="text-left p-4 text-sm font-medium text-gray-700">ID</th>
                  <th class="text-left p-4 text-sm font-medium text-gray-700">Status</th>
                  <th class="text-left p-4 text-sm font-medium text-gray-700">Progress</th>
                  <th class="text-left p-4 text-sm font-medium text-gray-700">Created</th>
                  <th class="text-left p-4 text-sm font-medium text-gray-700">Actions</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-200">
                <tr v-for="migration in migrationHistory" :key="migration.id" class="hover:bg-gray-50">
                  <td class="p-4 text-sm font-mono text-gray-700">
                    {{ migration.id.substring(0, 20) }}...
                  </td>
                  <td class="p-4">
                    <span :class="statusBadgeClass(migration.status)" class="px-2 py-1 rounded-full text-xs font-medium">
                      {{ formatStatus(migration.status) }}
                    </span>
                  </td>
                  <td class="p-4 text-sm text-gray-600">
                    <div class="w-full bg-gray-200 rounded-full h-2">
                      <div 
                        :class="progressBarClass(migration.status)"
                        class="h-2 rounded-full transition-all duration-300"
                        :style="{ width: (migration.progress?.percentage || 0) + '%' }"
                      ></div>
                    </div>
                    <div class="text-xs mt-1">
                      {{ migration.progress?.migrated || 0 }} / {{ migration.progress?.total || 0 }}
                    </div>
                  </td>
                  <td class="p-4 text-sm text-gray-600">
                    {{ formatDate(migration.metadata?.createdAt) }}
                  </td>
                  <td class="p-4">
                    <div class="flex gap-2">
                      <button
                        v-if="migration.status === 'completed'"
                        @click="rollbackMigration(migration.id)"
                        class="px-3 py-1 bg-red-100 text-red-700 rounded text-xs hover:bg-red-200 transition-colors"
                      >
                        Rollback
                      </button>
                      <button
                        @click="viewMigrationDetails(migration)"
                        class="px-3 py-1 bg-blue-100 text-blue-700 rounded text-xs hover:bg-blue-200 transition-colors"
                      >
                        Details
                      </button>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </main>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted, computed } from 'vue';
import AppHeader from '../components/AppHeader.vue';
import api from '@/services/api';

// Reactive data
const isLoading = ref(false);
const isAnalyzing = ref(false);
const showMigrationHistory = ref(false);

// Migration data
const migrationStats = ref({
  total: 0,
  completed: 0,
  running: 0,
  failed: 0,
  successRate: 0
});

const activeMigration = ref(null);
const migrationHistory = ref([]);
const tagAnalysis = ref(null);
const validationResult = ref(null);

// Configuration
const tagMappings = ref({});
const migrationConfig = ref({
  batchSize: 100,
  limit: 0,
  updateAll: false
});

const availableInterests = ref([]);

// Fetch available interests from API
async function fetchAvailableInterests() {
  try {
    const response = await api.get('/api/admin/interests');
    if (response.data.success) {
      // Extract interest names from the response
      availableInterests.value = response.data.interests.map(interest => interest.name || interest);
    }
  } catch (error) {
    console.error('Error fetching interests:', error);
    showAlert('error', 'Failed to load interests', error.message);
  }
}

// UI state
const newTagInput = ref('');
const newInterestInput = ref('');
const alert = ref({
  show: false,
  type: 'info',
  title: '',
  message: '',
  icon: ''
});

// Auto-refresh interval
let refreshInterval = null;

// Computed properties
const alertClasses = computed(() => {
  const baseClasses = 'border rounded-lg';
  switch (alert.value.type) {
    case 'success':
      return `${baseClasses} bg-green-50 border-green-200 text-green-800`;
    case 'error':
      return `${baseClasses} bg-red-50 border-red-200 text-red-800`;
    case 'warning':
      return `${baseClasses} bg-yellow-50 border-yellow-200 text-yellow-800`;
    default:
      return `${baseClasses} bg-blue-50 border-blue-200 text-blue-800`;
  }
});

// Lifecycle hooks
onMounted(() => {
  fetchAvailableInterests();
  refreshAllData();
  startAutoRefresh();
});

onUnmounted(() => {
  stopAutoRefresh();
});

// Auto-refresh functions
function startAutoRefresh() {
  refreshInterval = setInterval(() => {
    if (activeMigration.value && ['running', 'paused'].includes(activeMigration.value.status)) {
      refreshMigrationStatus(activeMigration.value.id);
    }
  }, 2000); // Refresh every 2 seconds for active migrations
}

function stopAutoRefresh() {
  if (refreshInterval) {
    clearInterval(refreshInterval);
    refreshInterval = null;
  }
}

// Alert functions
function showAlert(type, title, message = '') {
  alert.value = {
    show: true,
    type,
    title,
    message,
    icon: type === 'success' ? '✅' : type === 'error' ? '❌' : type === 'warning' ? '⚠️' : 'ℹ️'
  };
  
  // Auto-hide success alerts
  if (type === 'success') {
    setTimeout(() => {
      alert.value.show = false;
    }, 5000);
  }
}

// Data fetching functions
async function refreshAllData() {
  isLoading.value = true;
  try {
    await Promise.all([
      refreshMigrationStats(),
      refreshMigrationHistory(),
      findActiveMigration()
    ]);
  } catch (error) {
    showAlert('error', 'Failed to refresh data', error.message);
  } finally {
    isLoading.value = false;
  }
}

async function refreshMigrationStats() {
  try {
    const response = await api.get('/api/migrations/stats');
    if (response.data.success) {
      migrationStats.value = response.data.stats;
    }
  } catch (error) {
    console.error('Error fetching migration stats:', error);
  }
}

async function refreshMigrationHistory() {
  try {
    const response = await api.get('/api/migrations?limit=20');
    if (response.data.success) {
      migrationHistory.value = response.data.migrations;
    }
  } catch (error) {
    console.error('Error fetching migration history:', error);
  }
}

async function findActiveMigration() {
  const runningMigrations = migrationHistory.value.filter(m => 
    ['running', 'paused', 'created'].includes(m.status)
  );
  
  if (runningMigrations.length > 0) {
    activeMigration.value = runningMigrations[0];
  } else {
    activeMigration.value = null;
  }
}

async function refreshMigrationStatus(migrationId) {
  try {
    const response = await api.get(`/api/migrations/${migrationId}/status`);
    if (response.data.success) {
      activeMigration.value = response.data.migration;
    }
  } catch (error) {
    console.error('Error refreshing migration status:', error);
  }
}

// Tag analysis functions
async function analyzeTagsForMappings() {
  isAnalyzing.value = true;
  try {
    const response = await api.get('/api/migrations/analyze-tags?limit=1000&excludeExisting=true');
    if (response.data.success) {
      tagAnalysis.value = response.data.data;
      showAlert('success', 'Tag analysis completed', `Found ${response.data.data.totalTags} unique tags`);
    }
  } catch (error) {
    showAlert('error', 'Tag analysis failed', error.message);
  } finally {
    isAnalyzing.value = false;
  }
}

function confidenceBarClass(confidence) {
  if (confidence >= 0.8) return 'bg-green-500';
  if (confidence >= 0.6) return 'bg-yellow-500';
  if (confidence >= 0.4) return 'bg-orange-500';
  return 'bg-red-500';
}

// Mapping functions
function updateMapping(tag, interest) {
  if (interest) {
    tagMappings.value[tag] = interest;
  } else {
    delete tagMappings.value[tag];
  }
  tagMappings.value = { ...tagMappings.value };
  
  // Clear validation when mappings change
  validationResult.value = null;
}

function applyMapping(tag, interest) {
  updateMapping(tag, interest);
  showAlert('success', 'Mapping applied', `${tag} → ${formatInterestName(interest)}`);
}

function removeMapping(tag) {
  delete tagMappings.value[tag];
  tagMappings.value = { ...tagMappings.value };
  validationResult.value = null;
}

function addNewMapping() {
  if (newTagInput.value && newInterestInput.value) {
    tagMappings.value[newTagInput.value.toLowerCase()] = newInterestInput.value;
    tagMappings.value = { ...tagMappings.value };
    newTagInput.value = '';
    newInterestInput.value = '';
    validationResult.value = null;
  }
}

// Migration control functions
async function validateConfiguration() {
  isLoading.value = true;
  try {
    const response = await api.post('/api/migrations/validate', {
      tagMappings: tagMappings.value,
      batchSize: migrationConfig.value.batchSize,
      limit: migrationConfig.value.limit,
      updateAll: migrationConfig.value.updateAll
    });
    
    if (response.data.success) {
      validationResult.value = response.data.validation;
      if (response.data.validation.valid) {
        showAlert('success', 'Configuration is valid', 'Ready to start migration');
      } else {
        showAlert('error', 'Configuration errors found', 'Please fix the errors before proceeding');
      }
    }
  } catch (error) {
    showAlert('error', 'Validation failed', error.message);
  } finally {
    isLoading.value = false;
  }
}

async function runDryRun() {
  isLoading.value = true;
  try {
    const response = await api.post('/api/migrations/dry-run', {
      tagMappings: tagMappings.value,
      batchSize: migrationConfig.value.batchSize,
      limit: migrationConfig.value.limit,
      updateAll: migrationConfig.value.updateAll
    });
    
    if (response.data.success) {
      showAlert('success', 'Dry run started', 'Check migration history for results');
      await refreshAllData();
    }
  } catch (error) {
    showAlert('error', 'Dry run failed', error.message);
  } finally {
    isLoading.value = false;
  }
}

async function createAndStartMigration() {
  if (!confirm('Start migration with current configuration? This will modify your posts.')) {
    return;
  }
  
  isLoading.value = true;
  try {
    // Create migration
    const createResponse = await api.post('/api/migrations/create', {
      tagMappings: tagMappings.value,
      batchSize: migrationConfig.value.batchSize,
      limit: migrationConfig.value.limit,
      updateAll: migrationConfig.value.updateAll
    });
    
    if (createResponse.data.success) {
      const migrationId = createResponse.data.migrationId;
      
      // Start migration
      const startResponse = await api.post(`/api/migrations/${migrationId}/start`);
      
      if (startResponse.data.success) {
        showAlert('success', 'Migration started successfully', `Migration ID: ${migrationId}`);
        await refreshAllData();
      }
    }
  } catch (error) {
    showAlert('error', 'Failed to start migration', error.message);
  } finally {
    isLoading.value = false;
  }
}

async function pauseMigration(migrationId) {
  try {
    const response = await api.post(`/api/migrations/${migrationId}/pause`);
    if (response.data.success) {
      showAlert('success', 'Migration pause requested');
      await refreshMigrationStatus(migrationId);
    }
  } catch (error) {
    showAlert('error', 'Failed to pause migration', error.message);
  }
}

async function startMigration(migrationId) {
  try {
    const response = await api.post(`/api/migrations/${migrationId}/start`);
    if (response.data.success) {
      showAlert('success', 'Migration resumed');
      await refreshMigrationStatus(migrationId);
    }
  } catch (error) {
    showAlert('error', 'Failed to resume migration', error.message);
  }
}

async function stopMigration(migrationId) {
  if (!confirm('Stop this migration? Progress will be saved but migration will not continue.')) {
    return;
  }
  
  try {
    const response = await api.post(`/api/migrations/${migrationId}/stop`);
    if (response.data.success) {
      showAlert('success', 'Migration stopped');
      await refreshAllData();
    }
  } catch (error) {
    showAlert('error', 'Failed to stop migration', error.message);
  }
}

async function rollbackMigration(migrationId) {
  if (!confirm('Rollback this migration? This will remove interests from all migrated posts. This cannot be undone.')) {
    return;
  }
  
  try {
    const response = await api.post(`/api/migrations/${migrationId}/rollback`);
    if (response.data.success) {
      showAlert('success', 'Migration rollback completed', `${response.data.postsRolledBack} posts rolled back`);
      await refreshAllData();
    }
  } catch (error) {
    showAlert('error', 'Rollback failed', error.message);
  }
}

function resetConfiguration() {
  if (confirm('Reset configuration? This will clear all mappings and settings.')) {
    tagMappings.value = {};
    migrationConfig.value = {
      batchSize: 100,
      limit: 0,
      updateAll: false
    };
    validationResult.value = null;
    newTagInput.value = '';
    newInterestInput.value = '';
  }
}

// Helper functions
function formatInterestName(interest) {
  return interest
    .split('-')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
}

function formatStatus(status) {
  return status.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase());
}

function formatDate(timestamp) {
  if (!timestamp) return '-';
  
  let date;
  if (timestamp.toDate) {
    date = timestamp.toDate();
  } else if (typeof timestamp === 'number') {
    date = new Date(timestamp);
  } else {
    date = new Date(timestamp);
  }
  
  return date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
}

function statusBadgeClass(status) {
  const baseClasses = 'px-2 py-1 rounded-full text-xs font-medium';
  switch (status) {
    case 'completed':
      return `${baseClasses} bg-green-100 text-green-800`;
    case 'running':
      return `${baseClasses} bg-blue-100 text-blue-800`;
    case 'paused':
      return `${baseClasses} bg-yellow-100 text-yellow-800`;
    case 'failed':
      return `${baseClasses} bg-red-100 text-red-800`;
    case 'stopped':
      return `${baseClasses} bg-gray-100 text-gray-800`;
    case 'rolled_back':
      return `${baseClasses} bg-purple-100 text-purple-800`;
    default:
      return `${baseClasses} bg-gray-100 text-gray-800`;
  }
}

function progressBarClass(status) {
  switch (status) {
    case 'completed':
      return 'bg-green-500';
    case 'running':
      return 'bg-blue-500';
    case 'paused':
      return 'bg-yellow-500';
    case 'failed':
      return 'bg-red-500';
    default:
      return 'bg-gray-500';
  }
}

function viewMigrationDetails(migration) {
  // For now, just show an alert with details
  const details = `
Status: ${formatStatus(migration.status)}
Progress: ${migration.progress?.migrated || 0}/${migration.progress?.total || 0} (${migration.progress?.percentage || 0}%)
Created: ${formatDate(migration.metadata?.createdAt)}
Errors: ${migration.errors?.length || 0}
  `.trim();
  
  alert(details);
}
</script>