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
          
          <!-- UI Styling Settings -->
          <Card>
            <CardHeader>
              <CardTitle>UI Styling Settings</CardTitle>
              <p class="text-sm text-muted-foreground">Customize the appearance of the admin dashboard</p>
            </CardHeader>
            <CardContent>
              <div class="space-y-6">
                <!-- Primary Color -->
                <div>
                  <label for="primaryColor" class="block text-sm font-medium text-foreground mb-2">
                    Primary Color
                  </label>
                  <div class="flex items-center gap-4">
                    <input
                      id="primaryColor"
                      v-model="uiSettings.primaryColor"
                      type="color"
                      class="w-16 h-10 border rounded-md cursor-pointer"
                    />
                    <Input
                      v-model="uiSettings.primaryColor"
                      placeholder="#6366f1"
                      class="flex-1 font-mono text-sm"
                    />
                  </div>
                  <p class="text-xs text-muted-foreground mt-1">Main brand color used for buttons and accents</p>
                </div>

                <!-- Secondary Color -->
                <div>
                  <label for="secondaryColor" class="block text-sm font-medium text-foreground mb-2">
                    Secondary Color
                  </label>
                  <div class="flex items-center gap-4">
                    <input
                      id="secondaryColor"
                      v-model="uiSettings.secondaryColor"
                      type="color"
                      class="w-16 h-10 border rounded-md cursor-pointer"
                    />
                    <Input
                      v-model="uiSettings.secondaryColor"
                      placeholder="#8b5cf6"
                      class="flex-1 font-mono text-sm"
                    />
                  </div>
                  <p class="text-xs text-muted-foreground mt-1">Secondary accent color</p>
                </div>

                <!-- Background Color -->
                <div>
                  <label for="backgroundColor" class="block text-sm font-medium text-foreground mb-2">
                    Background Color
                  </label>
                  <div class="flex items-center gap-4">
                    <input
                      id="backgroundColor"
                      v-model="uiSettings.backgroundColor"
                      type="color"
                      class="w-16 h-10 border rounded-md cursor-pointer"
                    />
                    <Input
                      v-model="uiSettings.backgroundColor"
                      placeholder="#f9fafb"
                      class="flex-1 font-mono text-sm"
                    />
                  </div>
                  <p class="text-xs text-muted-foreground mt-1">Main background color for the dashboard</p>
                </div>

                <!-- Border Radius -->
                <div>
                  <label for="borderRadius" class="block text-sm font-medium text-foreground mb-2">
                    Border Radius (px)
                  </label>
                  <Input
                    id="borderRadius"
                    v-model.number="uiSettings.borderRadius"
                    type="number"
                    min="0"
                    max="24"
                  />
                  <p class="text-xs text-muted-foreground mt-1">Controls the roundness of buttons and cards (0-24px)</p>
                </div>

                <!-- Font Family -->
                <div>
                  <label for="fontFamily" class="block text-sm font-medium text-foreground mb-2">
                    Font Family
                  </label>
                  <Select v-model="uiSettings.fontFamily">
                    <SelectItem value="Inter">Inter (Default)</SelectItem>
                    <SelectItem value="Roboto">Roboto</SelectItem>
                    <SelectItem value="Open Sans">Open Sans</SelectItem>
                    <SelectItem value="Lato">Lato</SelectItem>
                    <SelectItem value="Montserrat">Montserrat</SelectItem>
                    <SelectItem value="Poppins">Poppins</SelectItem>
                    <SelectItem value="System">System Default</SelectItem>
                  </Select>
                  <p class="text-xs text-muted-foreground mt-1">Font family for the entire dashboard</p>
                </div>

                <!-- Dark Mode Toggle -->
                <div class="flex items-center justify-between p-4 border rounded-lg">
                  <div>
                    <p class="text-sm font-medium text-foreground">Enable Dark Mode</p>
                    <p class="text-xs text-muted-foreground mt-1">Allow users to toggle dark mode</p>
                  </div>
                  <label class="relative inline-flex items-center cursor-pointer">
                    <input
                      v-model="uiSettings.enableDarkMode"
                      type="checkbox"
                      class="sr-only peer"
                    />
                    <div class="w-11 h-6 bg-input peer-focus:outline-none peer-focus:ring-2 peer-focus:ring-ring peer-focus:ring-offset-2 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-background after:border-input after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-primary"></div>
                  </label>
                </div>
              </div>

              <div class="mt-6 flex justify-end gap-3">
                <Button @click="resetUISettings" variant="outline">
                  Reset to Defaults
                </Button>
                <Button @click="saveUISettings" :disabled="saving">
                  {{ saving ? 'Saving...' : 'Save Changes' }}
                </Button>
              </div>
            </CardContent>
          </Card>

          <!-- Preview Section -->
          <Card>
            <CardHeader>
              <CardTitle>Color Preview</CardTitle>
              <p class="text-sm text-muted-foreground">See how your color choices look in practice</p>
            </CardHeader>
            <CardContent>
              <div class="space-y-4">
                <div class="flex gap-4">
                  <div class="flex-1">
                    <p class="text-sm font-medium mb-2">Primary Color Sample</p>
                    <div class="p-4 rounded-lg border-2" :style="{ backgroundColor: uiSettings.primaryColor }">
                      <p class="text-white text-sm">Primary color sample</p>
                      <Button class="mt-2" variant="secondary" size="sm">Sample Button</Button>
                    </div>
                  </div>
                  <div class="flex-1">
                    <p class="text-sm font-medium mb-2">Secondary Color Sample</p>
                    <div class="p-4 rounded-lg border-2" :style="{ backgroundColor: uiSettings.secondaryColor }">
                      <p class="text-white text-sm">Secondary color sample</p>
                      <Button class="mt-2" variant="secondary" size="sm">Sample Button</Button>
                    </div>
                  </div>
                </div>
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
import { ref, onMounted, watch } from 'vue';
import api from '../services/api';
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

const loading = ref(true);
const saving = ref(false);
const featureFlags = ref({});
const uiSettings = ref({
  primaryColor: '#6366f1',
  secondaryColor: '#8b5cf6',
  backgroundColor: '#f9fafb',
  borderRadius: 8,
  fontFamily: 'Inter',
  enableDarkMode: false
});

const showAddFeatureFlag = ref(false);
const newFeatureFlagKey = ref('');
const newFeatureFlagValue = ref(false);

const toast = ref({
  show: false,
  message: '',
  type: 'success'
});

const defaultUISettings = {
  primaryColor: '#6366f1',
  secondaryColor: '#8b5cf6',
  backgroundColor: '#f9fafb',
  borderRadius: 8,
  fontFamily: 'Inter',
  enableDarkMode: false
};

// Apply colors to CSS variables when they change
watch(uiSettings, (newSettings) => {
  applyColorsToCSS(newSettings);
}, { deep: true });

const applyColorsToCSS = (settings) => {
  const root = document.documentElement;
  
  // Apply primary color
  root.style.setProperty('--primary', settings.primaryColor);
  root.style.setProperty('--primary-foreground', getContrastColor(settings.primaryColor));
  
  // Apply secondary color
  root.style.setProperty('--secondary', settings.secondaryColor);
  root.style.setProperty('--secondary-foreground', getContrastColor(settings.secondaryColor));
  
  // Apply background color
  root.style.setProperty('--background', settings.backgroundColor);
  root.style.setProperty('--foreground', getContrastColor(settings.backgroundColor));
  
  // Apply border radius
  root.style.setProperty('--radius', `${settings.borderRadius}px`);
};

const getContrastColor = (hexColor) => {
  // Convert hex to RGB
  const r = parseInt(hexColor.slice(1, 3), 16);
  const g = parseInt(hexColor.slice(3, 5), 16);
  const b = parseInt(hexColor.slice(5, 7), 16);
  
  // Calculate luminance
  const luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
  
  // Return black or white based on luminance
  return luminance > 0.5 ? '#000000' : '#ffffff';
};

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

    // Merge saved UI settings with defaults
    const savedUISettings = settings.uiSettings;
    
    if (savedUISettings && typeof savedUISettings === 'object' && !Array.isArray(savedUISettings)) {
      const mergedSettings = {
        primaryColor: savedUISettings.primaryColor !== undefined ? String(savedUISettings.primaryColor) : defaultUISettings.primaryColor,
        secondaryColor: savedUISettings.secondaryColor !== undefined ? String(savedUISettings.secondaryColor) : defaultUISettings.secondaryColor,
        backgroundColor: savedUISettings.backgroundColor !== undefined ? String(savedUISettings.backgroundColor) : defaultUISettings.backgroundColor,
        borderRadius: savedUISettings.borderRadius !== undefined ? Number(savedUISettings.borderRadius) : defaultUISettings.borderRadius,
        fontFamily: savedUISettings.fontFamily !== undefined ? String(savedUISettings.fontFamily) : defaultUISettings.fontFamily,
        enableDarkMode: savedUISettings.enableDarkMode !== undefined ? Boolean(savedUISettings.enableDarkMode) : defaultUISettings.enableDarkMode
      };
      
      uiSettings.value = mergedSettings;
    } else {
      uiSettings.value = { ...defaultUISettings };
    }
  } catch (error) {
    console.error('Error fetching settings:', error);
    featureFlags.value = {};
    uiSettings.value = { ...defaultUISettings };
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

const saveUISettings = async () => {
  saving.value = true;
  try {
    await api.post('/api/admin/settings', {
      uiSettings: uiSettings.value
    });
    showToast('UI settings saved successfully');
  } catch (error) {
    console.error('Error saving UI settings:', error);
    showToast('Failed to save UI settings', 'error');
  } finally {
    saving.value = false;
  }
};

const resetUISettings = () => {
  if (confirm('Are you sure you want to reset all UI settings to defaults?')) {
    uiSettings.value = { ...defaultUISettings };
    showToast('UI settings reset to defaults');
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
