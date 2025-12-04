<template>
  <div class="min-h-screen bg-background">
    <AppHeader />
    
    <main class="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
      <div class="px-4 py-6 sm:px-0">
        <!-- Page Header -->
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-foreground">Post Migration</h1>
          <p class="text-muted-foreground mt-2">Migrate posts from tags/categories to interests taxonomy</p>
        </div>

        <!-- Error Alert -->
        <div v-if="error" class="mb-4 p-4 bg-destructive/10 border border-destructive/20 rounded-lg">
          <p class="text-destructive">{{ error }}</p>
        </div>

        <!-- Migration Statistics -->
        <div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
          <Card>
            <CardContent class="pt-6">
              <div class="text-muted-foreground text-sm font-medium mb-2">Total Posts</div>
              <div class="text-3xl font-bold text-foreground">{{ stats.total }}</div>
            </CardContent>
          </Card>
          <Card class="bg-primary/5">
            <CardContent class="pt-6">
              <div class="text-primary text-sm font-medium mb-2">✓ Migrated</div>
              <div class="text-3xl font-bold text-primary">{{ stats.migrated }}</div>
            </CardContent>
          </Card>
          <Card class="bg-yellow-500/5">
            <CardContent class="pt-6">
              <div class="text-yellow-600 dark:text-yellow-500 text-sm font-medium mb-2">⏳ Pending</div>
              <div class="text-3xl font-bold text-yellow-600 dark:text-yellow-500">{{ stats.pending }}</div>
            </CardContent>
          </Card>
          <Card class="bg-green-500/5">
            <CardContent class="pt-6">
              <div class="text-green-600 dark:text-green-500 text-sm font-medium mb-2">Progress</div>
              <div class="text-3xl font-bold text-green-600 dark:text-green-500">{{ stats.percentage }}%</div>
            </CardContent>
          </Card>
        </div>

        <!-- Migration Progress Bar -->
        <Card class="mb-6">
          <CardHeader>
            <CardTitle>Overall Progress</CardTitle>
          </CardHeader>
          <CardContent>
            <div class="w-full bg-secondary rounded-full h-3 overflow-hidden">
              <div 
                class="bg-gradient-to-r from-primary to-green-500 h-3 rounded-full transition-all duration-500"
                :style="{ width: stats.percentage + '%' }"
              ></div>
            </div>
            <p class="text-sm text-muted-foreground mt-3">
              {{ stats.migrated }} of {{ stats.total }} posts migrated
            </p>
          </CardContent>
        </Card>

        <!-- Tag Mapping Configuration -->
        <Card class="mb-6">
          <CardHeader>
            <div class="flex items-center justify-between">
              <div>
                <CardTitle>Tag → Interest Mappings</CardTitle>
                <p class="text-sm text-muted-foreground mt-1">Map existing tags to interests for migration</p>
              </div>
              <Button @click="loadTagsFromDatabase" variant="outline" size="sm" :disabled="loadingTags">
                <svg v-if="loadingTags" class="w-4 h-4 mr-2 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                </svg>
                <svg v-else class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                </svg>
                {{ loadingTags ? 'Loading...' : 'Refresh Tags' }}
              </Button>
            </div>
          </CardHeader>
          <CardContent>
            <div v-if="loadingTags" class="text-center py-8 text-muted-foreground">
              <p>Loading tags from database...</p>
            </div>

            <div v-else-if="allTags.length === 0" class="text-center py-8 text-muted-foreground">
              <p>No tags found in posts collection. Click "Refresh Tags" to fetch tags.</p>
            </div>

            <div v-else class="space-y-2">
              <!-- Tags List -->
              <div class="max-h-96 overflow-y-auto space-y-2 border rounded-lg p-4">
                <div 
                  v-for="tagItem in allTags"
                  :key="tagItem.tag"
                  class="flex items-center gap-3 p-3 bg-accent/30 rounded-lg hover:bg-accent/50 transition-colors"
                >
                  <!-- Tag Name -->
                  <div class="flex-shrink-0 w-40">
                    <span class="font-medium text-foreground">{{ tagItem.tag }}</span>
                    <Badge variant="secondary" class="ml-2 text-xs">{{ tagItem.count }}</Badge>
                  </div>

                  <!-- Arrow -->
                  <svg class="w-5 h-5 text-muted-foreground flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14 5l7 7m0 0l-7 7m7-7H3" />
                  </svg>

                  <!-- Interest Dropdown -->
                  <Select 
                    :model-value="tagMappings[tagItem.tag] || ''"
                    @update:model-value="updateMapping(tagItem.tag, $event)"
                  >
                    <option value="">-- Select Interest --</option>
                    <SelectItem 
                      v-for="interest in availableInterests" 
                      :key="interest" 
                      :value="interest"
                    >
                      {{ formatInterestName(interest) }}
                    </SelectItem>
                  </Select>

                  <!-- Clear Mapping Button -->
                  <Button 
                    v-if="tagMappings[tagItem.tag]"
                    @click="removeMapping(tagItem.tag)"
                    variant="ghost"
                    size="sm"
                    class="flex-shrink-0 text-muted-foreground hover:text-destructive"
                    title="Clear mapping"
                  >
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  </Button>
                </div>
              </div>

              <!-- Migration Preview -->
              <div class="mt-6">
                <Button 
                  @click="togglePreview"
                  variant="ghost"
                  size="sm"
                  class="mb-4"
                >
                  <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" :d="showPreview ? 'M19 9l-7 7-7-7' : 'M9 5l7 7-7 7'" />
                  </svg>
                  {{ showPreview ? 'Hide' : 'Show' }} Migration Preview
                </Button>

                <Card v-if="showPreview" class="bg-primary/5">
                  <CardContent class="pt-6">
                    <div v-if="previewLoading" class="text-center text-muted-foreground">
                      Loading preview...
                    </div>
                    <div v-else-if="previewData" class="space-y-3">
                      <p class="text-sm text-foreground font-medium">
                        Sample: {{ previewData.wouldMigrate }} of {{ previewData.sampleSize }} posts would migrate
                      </p>
                      <div class="max-h-48 overflow-y-auto space-y-2">
                        <div 
                          v-for="item in previewData.preview.slice(0, 5)"
                          :key="item.postId"
                          class="text-xs p-3 bg-background rounded-lg border"
                        >
                          <div class="font-mono text-muted-foreground mb-1">{{ item.postId.substring(0, 12) }}...</div>
                          <div class="text-muted-foreground">
                            Tags: {{ item.originalTags.join(', ') || 'none' }}
                          </div>
                          <div class="text-primary" v-if="item.willMigrate">
                            → Interests: {{ item.mappedInterests.join(', ') }}
                          </div>
                          <div class="text-muted-foreground" v-else>
                            → No mapped interests
                          </div>
                        </div>
                      </div>
                    </div>
                  </CardContent>
                </Card>
              </div>
            </div>
          </CardContent>
        </Card>

        <!-- Migration Controls -->
        <Card>
          <CardHeader>
            <CardTitle>Start Migration</CardTitle>
          </CardHeader>
          <CardContent>
            <!-- Settings -->
            <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
              <div>
                <label class="block text-sm font-medium text-foreground mb-2">Batch Size</label>
                <Input 
                  v-model.number="batchSize"
                  type="number"
                  min="10"
                  max="1000"
                />
                <p class="text-xs text-muted-foreground mt-1">Posts per request (10-1000)</p>
              </div>
              <div>
                <label class="block text-sm font-medium text-foreground mb-2">Limit</label>
                <Input 
                  v-model.number="limit"
                  type="number"
                  min="0"
                />
                <p class="text-xs text-muted-foreground mt-1">Max posts (0 = unlimited)</p>
              </div>
              <div>
                <label class="block text-sm font-medium text-foreground mb-2">Mode</label>
                <Select v-model="migrateMode">
                  <SelectItem value="unmigrated">Unmigrated Posts Only</SelectItem>
                  <SelectItem value="all">All Posts</SelectItem>
                </Select>
              </div>
            </div>

            <!-- Action Buttons -->
            <div class="flex gap-3">
              <Button
                @click="startMigration"
                :disabled="isProcessing || Object.keys(tagMappings).length === 0"
              >
                <svg v-if="isProcessing" class="w-4 h-4 mr-2 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                </svg>
                <svg v-else class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z" />
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                {{ isProcessing ? 'Processing...' : 'Start Migration' }}
              </Button>
              <Button
                @click="refreshStats"
                :disabled="isProcessing"
                variant="outline"
              >
                <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                </svg>
                Refresh Stats
              </Button>
              <Button
                @click="resetMappings"
                variant="outline"
              >
                Reset
              </Button>
            </div>

            <!-- Result Message -->
            <div v-if="migrationResult" class="mt-6 p-4 bg-green-500/10 border border-green-500/20 rounded-lg">
              <p class="text-green-700 dark:text-green-500 font-medium">✓ Migration completed!</p>
              <p class="text-green-600 dark:text-green-400 text-sm mt-1">
                Migrated: <span class="font-semibold">{{ migrationResult.migrated }}</span> | 
                Skipped: <span class="font-semibold">{{ migrationResult.skipped }}</span>
              </p>
              <div v-if="migrationResult.errors.length > 0" class="mt-3 text-destructive text-sm">
                <p class="font-medium">Errors:</p>
                <ul class="list-disc list-inside mt-1">
                  <li v-for="err in migrationResult.errors.slice(0, 3)" :key="err.postId">
                    {{ err.postId }}: {{ err.error }}
                  </li>
                </ul>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>
    </main>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import AppHeader from '../components/AppHeader.vue';
import Button from '@/components/ui/Button.vue';
import Card from '@/components/ui/Card.vue';
import CardContent from '@/components/ui/CardContent.vue';
import CardHeader from '@/components/ui/CardHeader.vue';
import CardTitle from '@/components/ui/CardTitle.vue';
import Input from '@/components/ui/Input.vue';
import Select from '@/components/ui/Select.vue';
import SelectItem from '@/components/ui/SelectItem.vue';
import Badge from '@/components/ui/Badge.vue';
import api from '../services/api';

const stats = ref({
  total: 0,
  migrated: 0,
  pending: 0,
  percentage: 0
});

const allTags = ref([]);
const loadingTags = ref(false);
const tagMappings = ref({});

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

onMounted(() => {
  refreshStats();
  loadTagsFromDatabase();
});

function formatInterestName(interest) {
  return interest
    .split('-')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
}

async function loadTagsFromDatabase() {
  loadingTags.value = true;
  error.value = null;
  try {
    const response = await api.get('/api/admin/posts/all-tags');
    const data = response.data;
    if (data.success) {
      allTags.value = data.tags;
      
      // Auto-populate some default mappings based on tag names
      const defaultMappings = {
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
      
      // Only set if not already set
      allTags.value.forEach(tagItem => {
        if (!tagMappings.value[tagItem.tag] && defaultMappings[tagItem.tag]) {
          tagMappings.value[tagItem.tag] = defaultMappings[tagItem.tag];
        }
      });
    }
  } catch (err) {
    error.value = 'Failed to load tags from database';
    console.error('Error fetching tags:', err);
  } finally {
    loadingTags.value = false;
  }
}

async function refreshStats() {
  try {
    error.value = null;
    const response = await api.get('/api/admin/posts/migration-stats');
    const data = response.data;
    if (data.success) {
      stats.value = data.stats;
    }
  } catch (err) {
    error.value = 'Failed to load statistics';
    console.error('Error fetching stats:', err);
  }
}

async function togglePreview() {
  showPreview.value = !showPreview.value;
  if (showPreview.value && !previewData.value) {
    await loadPreview();
  }
}

async function loadPreview() {
  if (Object.keys(tagMappings.value).length === 0) {
    return;
  }

  previewLoading.value = true;
  try {
    const mappingsJson = JSON.stringify(tagMappings.value);
    const response = await api.get(
      `/api/admin/posts/migration-preview?tagMappings=${encodeURIComponent(mappingsJson)}`
    );
    const data = response.data;
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
    const response = await api.post('/api/admin/posts/migrate-interests', {
      batchSize: batchSize.value,
      limit: limit.value || null,
      tagMappings: tagMappings.value,
      updateAll: migrateMode.value === 'all'
    });
    
    const data = response.data;
    if (data.success) {
      migrationResult.value = data;
      setTimeout(() => {
        refreshStats();
      }, 1000);
    } else {
      error.value = data.message || 'Migration failed';
    }
  } catch (err) {
    error.value = err.response?.data?.message || err.message || 'Migration error';
    console.error('Migration error:', err);
  } finally {
    isProcessing.value = false;
  }
}

function updateMapping(tag, interest) {
  if (interest) {
    tagMappings.value[tag] = interest;
  }
  // Reload preview if visible
  if (showPreview.value) {
    loadPreview();
  }
}

function removeMapping(tag) {
  delete tagMappings.value[tag];
  tagMappings.value = { ...tagMappings.value };
  // Reload preview if visible
  if (showPreview.value) {
    loadPreview();
  }
}

function resetMappings() {
  if (confirm('Reset all mappings?')) {
    tagMappings.value = {};
    migrationResult.value = null;
    previewData.value = null;
  }
}
</script>
