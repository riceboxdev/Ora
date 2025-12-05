<template>
  <div class="min-h-screen bg-background">
    <AppHeader />
    
    <main class="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
      <div class="px-4 py-6 sm:px-0">
        <h2 class="text-2xl font-bold text-foreground mb-6">System Settings</h2>
        
        <div v-if="loading" class="text-center py-12">
          <p class="text-muted-foreground">Loading settings...</p>
        </div>
        
        <div v-else class="space-y-6">
          <!-- Feature Flags -->
          <Card>
            <CardHeader>
              <div class="flex items-center justify-between">
                <div>
                  <CardTitle>Feature Flags</CardTitle>
                  <p class="text-sm text-muted-foreground mt-1">Flags are automatically synced to Firebase Remote Config for the iOS app</p>
                </div>
                <Button @click="showAddFeatureFlag = true" size="sm">
                  <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
                  </svg>
                  Add Flag
                </Button>
              </div>
            </CardHeader>
            <CardContent>
              <div v-if="Object.keys(featureFlags).length === 0" class="text-center py-8 text-muted-foreground">
                <p>No feature flags configured. Click "Add Flag" to create one.</p>
              </div>
              
              <div v-else class="space-y-3">
                <div
                  v-for="(value, key) in featureFlags"
                  :key="key"
                  class="flex items-center justify-between p-4 border rounded-lg hover:bg-accent/50 transition-colors"
                >
                  <div class="flex-1">
                    <div class="flex items-center gap-2 mb-1">
                      <label :for="key" class="text-sm font-medium text-foreground">
                        {{ formatKey(key) }}
                      </label>
                      <Badge variant="secondary" class="font-mono text-xs">{{ key }}</Badge>
                    </div>
                    <p class="text-xs text-muted-foreground">Toggle this feature on/off</p>
                  </div>
                  <div class="flex items-center gap-4">
                    <label class="relative inline-flex items-center cursor-pointer">
                      <input
                        :id="key"
                        v-model="featureFlags[key]"
                        type="checkbox"
                        class="sr-only peer"
                      />
                      <div class="w-11 h-6 bg-input peer-focus:outline-none peer-focus:ring-2 peer-focus:ring-ring peer-focus:ring-offset-2 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-background after:border-input after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-primary"></div>
                    </label>
                    <Button
                      @click="deleteFeatureFlag(key)"
                      variant="ghost"
                      size="sm"
                      class="text-destructive hover:text-destructive hover:bg-destructive/10"
                      title="Delete flag"
                    >
                      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                      </svg>
                    </Button>
                  </div>
                </div>
              </div>
              
              <div class="mt-6 flex justify-end">
                <Button @click="saveFeatureFlags" :disabled="saving">
                  {{ saving ? 'Saving...' : 'Save Changes' }}
                </Button>
              </div>
            </CardContent>
          </Card>
        </div>
      </div>
    </main>

    <!-- Add Feature Flag Modal -->
    <div
      v-if="showAddFeatureFlag"
      class="fixed inset-0 bg-black/50 flex items-center justify-center z-50"
      @click.self="showAddFeatureFlag = false"
    >
      <Card class="max-w-md w-full mx-4">
        <CardHeader>
          <CardTitle>Add Feature Flag</CardTitle>
        </CardHeader>
        <CardContent>
          <div class="space-y-4">
            <div>
              <label for="newFlagKey" class="block text-sm font-medium text-foreground mb-1">
                Flag Key
              </label>
              <Input
                id="newFlagKey"
                v-model="newFeatureFlagKey"
                placeholder="e.g., enableNewFeature"
                @keyup.enter="addFeatureFlag"
              />
              <p class="text-xs text-muted-foreground mt-1">Use camelCase (e.g., enableNewFeature)</p>
            </div>
            <div>
              <label class="flex items-center gap-2">
                <input
                  v-model="newFeatureFlagValue"
                  type="checkbox"
                  class="w-4 h-4 text-primary border-input rounded focus:ring-primary"
                />
                <span class="text-sm text-foreground">Enabled by default</span>
              </label>
            </div>
          </div>
          <div class="mt-6 flex justify-end gap-3">
            <Button
              @click="showAddFeatureFlag = false; newFeatureFlagKey = ''; newFeatureFlagValue = false"
              variant="outline"
            >
              Cancel
            </Button>
            <Button
              @click="addFeatureFlag"
              :disabled="!newFeatureFlagKey.trim()"
            >
              Add Flag
            </Button>
          </div>
        </CardContent>
      </Card>
    </div>

    <!-- Toast Notification -->
    <div
      v-if="toast.show"
      class="fixed bottom-4 right-4 bg-background shadow-lg rounded-lg p-4 border-l-4 z-50 max-w-sm"
      :class="toast.type === 'success' ? 'border-green-500' : 'border-red-500'"
    >
      <div class="flex items-center gap-3">
        <div v-if="toast.type === 'success'" class="text-green-500">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
          </svg>
        </div>
        <div v-else class="text-red-500">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </div>
        <p class="text-sm text-foreground">{{ toast.message }}</p>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import api from '../services/api';
import AppHeader from '../components/AppHeader.vue';
import Button from '@/components/ui/Button.vue';
import Card from '@/components/ui/Card.vue';
import CardContent from '@/components/ui/CardContent.vue';
import CardHeader from '@/components/ui/CardHeader.vue';
import CardTitle from '@/components/ui/CardTitle.vue';
import Input from '@/components/ui/Input.vue';
import Badge from '@/components/ui/Badge.vue';

const loading = ref(true);
const saving = ref(false);
const featureFlags = ref({});

const showAddFeatureFlag = ref(false);
const newFeatureFlagKey = ref('');
const newFeatureFlagValue = ref(false);

const toast = ref({
  show: false,
  message: '',
  type: 'success'
});

const formatKey = (key) => {
  return key.replace(/([A-Z])/g, ' $1').replace(/^./, str => str.toUpperCase());
};

const showToast = (message, type = 'success') => {
  toast.value = { show: true, message, type };
  setTimeout(() => {
    toast.value.show = false;
  }, 3000);
};

async function fetchSettings() {
  loading.value = true;
  try {
    const response = await api.get('/api/admin/settings');
    const settings = response.data.settings || {};
    featureFlags.value = settings.featureFlags || {};
  } catch (error) {
    console.error('Error fetching settings:', error);
    featureFlags.value = {};
  } finally {
    loading.value = false;
  }
}

const saveFeatureFlags = async () => {
  saving.value = true;
  try {
    await api.post('/api/admin/settings', {
      featureFlags: featureFlags.value
    });
    showToast('Feature flags saved successfully');
  } catch (error) {
    console.error('Error saving feature flags:', error);
    showToast('Failed to save feature flags', 'error');
  } finally {
    saving.value = false;
  }
};

const addFeatureFlag = () => {
  if (!newFeatureFlagKey.value.trim()) {
    showToast('Please enter a flag key', 'error');
    return;
  }
  
  const key = newFeatureFlagKey.value.trim();
  if (featureFlags.value[key] !== undefined) {
    showToast('Feature flag already exists', 'error');
    return;
  }
  
  featureFlags.value[key] = newFeatureFlagValue.value;
  newFeatureFlagKey.value = '';
  newFeatureFlagValue.value = false;
  showAddFeatureFlag.value = false;
  showToast('Feature flag added. Don\'t forget to save!', 'success');
};

const deleteFeatureFlag = (key) => {
  if (confirm(`Are you sure you want to delete the feature flag "${key}"?`)) {
    delete featureFlags.value[key];
    showToast('Feature flag deleted. Don\'t forget to save!', 'success');
  }
};

onMounted(() => {
  fetchSettings();
});
</script>
