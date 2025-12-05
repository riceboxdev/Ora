<template>
  <div class="min-h-screen bg-background">
    <AppHeader />
    
    <main class="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
      <div class="px-4 py-6 sm:px-0">
        <div class="mb-6">
          <h2 class="text-3xl font-bold text-foreground">Theme Customizer</h2>
          <p class="text-muted-foreground mt-2">Customize the appearance of your admin dashboard with live preview</p>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <!-- Left Column: Theme Controls -->
          <div class="lg:col-span-2 space-y-6">
            
            <!-- Theme Presets -->
            <Card>
              <CardHeader>
                <CardTitle>Theme Presets</CardTitle>
                <p class="text-sm text-muted-foreground">Quick start with pre-designed themes</p>
              </CardHeader>
              <CardContent>
                <div class="grid grid-cols-2 md:grid-cols-3 gap-3">
                  <button
                    v-for="(preset, key) in presets"
                    :key="key"
                    @click="handleApplyPreset(key)"
                    :class="cn(
                      'p-4 rounded-lg border-2 transition-all text-left hover:shadow-md',
                      currentPreset === key ? 'border-primary bg-primary/5' : 'border-border hover:border-primary/50'
                    )"
                  >
                    <div class="flex items-center gap-2 mb-2">
                      <div 
                        class="w-4 h-4 rounded-full" 
                        :style="{ backgroundColor: `hsl(${preset.colors.primary})` }"
                      ></div>
                      <span class="font-medium text-sm">{{ preset.name }}</span>
                    </div>
                    <div class="flex gap-1">
                      <div class="w-3 h-3 rounded" :style="{ backgroundColor: `hsl(${preset.colors.background})` }"></div>
                      <div class="w-3 h-3 rounded" :style="{ backgroundColor: `hsl(${preset.colors.primary})` }"></div>
                      <div class="w-3 h-3 rounded" :style="{ backgroundColor: `hsl(${preset.colors.secondary})` }"></div>
                      <div class="w-3 h-3 rounded" :style="{ backgroundColor: `hsl(${preset.colors.accent})` }"></div>
                    </div>
                  </button>
                </div>
              </CardContent>
            </Card>

            <!-- Color Customization -->
            <Card>
              <CardHeader>
                <CardTitle>Colors</CardTitle>
                <p class="text-sm text-muted-foreground">Customize individual color values (HSL format)</p>
              </CardHeader>
              <CardContent>
                <div class="space-y-4">
                  <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <!-- Primary Color -->
                    <div>
                      <label class="text-sm font-medium block mb-2">Primary</label>
                      <div class="flex items-center gap-2">
                        <div 
                          class="w-10 h-10 rounded border-2 border-border cursor-pointer"
                          :style="{ backgroundColor: `hsl(${customTheme.colors.primary})` }"
                          @click="() => showColorPicker('primary')"
                        ></div>
                        <Input
                          v-model="customTheme.colors.primary"
                          placeholder="221.2 83.2% 53.3%"
                          class="flex-1 font-mono text-xs"
                        />
                      </div>
                    </div>

                    <!-- Secondary Color -->
                    <div>
                      <label class="text-sm font-medium block mb-2">Secondary</label>
                      <div class="flex items-center gap-2">
                        <div 
                          class="w-10 h-10 rounded border-2 border-border"
                          :style="{ backgroundColor: `hsl(${customTheme.colors.secondary})` }"
                        ></div>
                        <Input
                          v-model="customTheme.colors.secondary"
                          placeholder="210 40% 96%"
                          class="flex-1 font-mono text-xs"
                        />
                      </div>
                    </div>

                    <!-- Accent Color -->
                    <div>
                      <label class="text-sm font-medium block mb-2">Accent</label>
                      <div class="flex items-center gap-2">
                        <div 
                          class="w-10 h-10 rounded border-2 border-border"
                          :style="{ backgroundColor: `hsl(${customTheme.colors.accent})` }"
                        ></div>
                        <Input
                          v-model="customTheme.colors.accent"
                          placeholder="210 40% 96%"
                          class="flex-1 font-mono text-xs"
                        />
                      </div>
                    </div>

                    <!-- Destructive Color -->
                    <div>
                      <label class="text-sm font-medium block mb-2">Destructive</label>
                      <div class="flex items-center gap-2">
                        <div 
                          class="w-10 h-10 rounded border-2 border-border"
                          :style="{ backgroundColor: `hsl(${customTheme.colors.destructive})` }"
                        ></div>
                        <Input
                          v-model="customTheme.colors.destructive"
                          placeholder="0 84.2% 60.2%"
                          class="flex-1 font-mono text-xs"
                        />
                      </div>
                    </div>

                    <!-- Background Color -->
                    <div>
                      <label class="text-sm font-medium block mb-2">Background</label>
                      <div class="flex items-center gap-2">
                        <div 
                          class="w-10 h-10 rounded border-2 border-border"
                          :style="{ backgroundColor: `hsl(${customTheme.colors.background})` }"
                        ></div>
                        <Input
                          v-model="customTheme.colors.background"
                          placeholder="0 0% 100%"
                          class="flex-1 font-mono text-xs"
                        />
                      </div>
                    </div>

                    <!-- Foreground Color -->
                    <div>
                      <label class="text-sm font-medium block mb-2">Foreground</label>
                      <div class="flex items-center gap-2">
                        <div 
                          class="w-10 h-10 rounded border-2 border-border"
                          :style="{ backgroundColor: `hsl(${customTheme.colors.foreground})` }"
                        ></div>
                        <Input
                          v-model="customTheme.colors.foreground"
                          placeholder="222.2 84% 4.9%"
                          class="flex-1 font-mono text-xs"
                        />
                      </div>
                    </div>
                  </div>

                  <Separator />

                  <!-- Advanced Colors (Collapsible) -->
                  <div>
                    <button
                      @click="showAdvancedColors = !showAdvancedColors"
                      class="flex items-center gap-2 text-sm font-medium hover:text-primary transition-colors"
                    >
                      <svg
                        class="w-4 h-4 transition-transform"
                        :class="showAdvancedColors ? 'rotate-90' : ''"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
                      </svg>
                      Advanced Colors
                    </button>

                    <div v-if="showAdvancedColors" class="mt-4 grid grid-cols-1 md:grid-cols-2 gap-4">
                      <div v-for="colorKey in advancedColorKeys" :key="colorKey">
                        <label class="text-sm font-medium block mb-2 capitalize">
                          {{ colorKey.replace(/([A-Z])/g, ' $1').trim() }}
                        </label>
                        <div class="flex items-center gap-2">
                          <div 
                            class="w-10 h-10 rounded border-2 border-border"
                            :style="{ backgroundColor: `hsl(${customTheme.colors[colorKey]})` }"
                          ></div>
                          <Input
                            v-model="customTheme.colors[colorKey]"
                            class="flex-1 font-mono text-xs"
                          />
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>

            <!-- Border Radius -->
            <Card>
              <CardHeader>
                <CardTitle>Border Radius</CardTitle>
                <p class="text-sm text-muted-foreground">Adjust the roundness of components</p>
              </CardHeader>
              <CardContent>
                <div class="space-y-4">
                  <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
                    <button
                      v-for="option in radiusOptions"
                      :key="option.value"
                      @click="customTheme.radius = option.value"
                      :class="cn(
                        'p-3 rounded border-2 transition-all text-center',
                        customTheme.radius === option.value ? 'border-primary bg-primary/5' : 'border-border hover:border-primary/50'
                      )"
                    >
                      <div class="text-sm font-medium">{{ option.label }}</div>
                      <div class="text-xs text-muted-foreground mt-1">{{ option.value }}</div>
                    </button>
                  </div>
                </div>
              </CardContent>
            </Card>

            <!-- Dark Mode Toggle -->
            <Card>
              <CardHeader>
                <CardTitle>Appearance Mode</CardTitle>
                <p class="text-sm text-muted-foreground">Switch between light and dark mode</p>
              </CardHeader>
              <CardContent>
                <div class="flex items-center justify-between p-4 border rounded-lg">
                  <div>
                    <p class="text-sm font-medium">Dark Mode</p>
                    <p class="text-xs text-muted-foreground mt-1">Toggle dark mode appearance</p>
                  </div>
                  <label class="relative inline-flex items-center cursor-pointer">
                    <input
                      v-model="isDarkMode"
                      type="checkbox"
                      class="sr-only peer"
                      @change="toggleDarkMode"
                    />
                    <div class="w-11 h-6 bg-input peer-focus:outline-none peer-focus:ring-2 peer-focus:ring-ring peer-focus:ring-offset-2 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-background after:border-input after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-primary"></div>
                  </label>
                </div>
              </CardContent>
            </Card>

            <!-- Actions -->
            <Card>
              <CardContent class="pt-6">
                <div class="flex flex-wrap gap-3">
                  <Button @click="handleApplyTheme" class="flex-1 sm:flex-none">
                    <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                    </svg>
                    Apply Theme
                  </Button>
                  <Button @click="handleSaveTheme" variant="secondary" class="flex-1 sm:flex-none">
                    <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3 3m0 0l-3-3m3 3V4" />
                    </svg>
                    Save Theme
                  </Button>
                  <Button @click="handleExportTheme" variant="outline" class="flex-1 sm:flex-none">
                    <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                    </svg>
                    Export
                  </Button>
                  <Button @click="handleImportTheme" variant="outline" class="flex-1 sm:flex-none">
                    <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" />
                    </svg>
                    Import
                  </Button>
                  <Button @click="handleResetTheme" variant="destructive" class="flex-1 sm:flex-none">
                    <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                    </svg>
                    Reset
                  </Button>
                </div>
              </CardContent>
            </Card>
          </div>

          <!-- Right Column: Live Preview -->
          <div class="lg:col-span-1">
            <div class="sticky top-6 space-y-4">
              <Card>
                <CardHeader>
                  <CardTitle>Live Preview</CardTitle>
                  <p class="text-sm text-muted-foreground">See your changes in real-time</p>
                </CardHeader>
                <CardContent class="space-y-3">
                  <!-- Buttons Preview -->
                  <div>
                    <p class="text-xs font-medium mb-2 text-muted-foreground">Buttons</p>
                    <div class="flex flex-wrap gap-2">
                      <Button size="sm">Primary</Button>
                      <Button size="sm" variant="secondary">Secondary</Button>
                      <Button size="sm" variant="outline">Outline</Button>
                      <Button size="sm" variant="destructive">Destructive</Button>
                    </div>
                  </div>

                  <Separator />

                  <!-- Badges Preview -->
                  <div>
                    <p class="text-xs font-medium mb-2 text-muted-foreground">Badges</p>
                    <div class="flex flex-wrap gap-2">
                      <Badge>Default</Badge>
                      <Badge variant="secondary">Secondary</Badge>
                      <Badge variant="outline">Outline</Badge>
                      <Badge variant="destructive">Error</Badge>
                    </div>
                  </div>

                  <Separator />

                  <!-- Input Preview -->
                  <div>
                    <p class="text-xs font-medium mb-2 text-muted-foreground">Input</p>
                    <Input placeholder="Sample input field" />
                  </div>

                  <Separator />

                  <!-- Card Preview -->
                  <div>
                    <p class="text-xs font-medium mb-2 text-muted-foreground">Card</p>
                    <Card>
                      <CardHeader>
                        <CardTitle class="text-sm">Card Title</CardTitle>
                      </CardHeader>
                      <CardContent>
                        <p class="text-xs text-muted-foreground">This is a sample card with some content inside.</p>
                      </CardContent>
                    </Card>
                  </div>

                  <Separator />

                  <!-- Colors Palette -->
                  <div>
                    <p class="text-xs font-medium mb-2 text-muted-foreground">Color Palette</p>
                    <div class="grid grid-cols-4 gap-2">
                      <div class="space-y-1">
                        <div class="h-8 rounded bg-primary"></div>
                        <p class="text-[10px] text-center text-muted-foreground">Primary</p>
                      </div>
                      <div class="space-y-1">
                        <div class="h-8 rounded bg-secondary"></div>
                        <p class="text-[10px] text-center text-muted-foreground">Secondary</p>
                      </div>
                      <div class="space-y-1">
                        <div class="h-8 rounded bg-accent"></div>
                        <p class="text-[10px] text-center text-muted-foreground">Accent</p>
                      </div>
                      <div class="space-y-1">
                        <div class="h-8 rounded bg-destructive"></div>
                        <p class="text-[10px] text-center text-muted-foreground">Destructive</p>
                      </div>
                    </div>
                  </div>
                </CardContent>
              </Card>

              <!-- Theme Info -->
              <Card>
                <CardHeader>
                  <CardTitle class="text-sm">Current Theme</CardTitle>
                </CardHeader>
                <CardContent>
                  <div class="space-y-2 text-xs">
                    <div class="flex justify-between">
                      <span class="text-muted-foreground">Mode:</span>
                      <Badge variant="outline">{{ customTheme.mode }}</Badge>
                    </div>
                    <div class="flex justify-between">
                      <span class="text-muted-foreground">Radius:</span>
                      <Badge variant="outline">{{ customTheme.radius }}</Badge>
                    </div>
                    <div class="flex justify-between">
                      <span class="text-muted-foreground">Preset:</span>
                      <Badge variant="outline">{{ currentPreset !== 'custom' ? presets[currentPreset]?.name : 'Custom' }}</Badge>
                    </div>
                  </div>
                </CardContent>
              </Card>
            </div>
          </div>
        </div>
      </div>
    </main>

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

    <!-- Import Modal -->
    <div
      v-if="showImportModal"
      class="fixed inset-0 bg-black/50 flex items-center justify-center z-50"
      @click.self="showImportModal = false"
    >
      <Card class="max-w-lg w-full mx-4">
        <CardHeader>
          <CardTitle>Import Theme</CardTitle>
          <p class="text-sm text-muted-foreground">Paste your theme JSON below</p>
        </CardHeader>
        <CardContent>
          <textarea
            v-model="importJson"
            class="w-full h-48 p-3 rounded-md border border-input bg-background font-mono text-xs"
            placeholder='{"name": "My Theme", "colors": {...}, ...}'
          ></textarea>
          <div class="mt-4 flex justify-end gap-3">
            <Button @click="showImportModal = false" variant="outline">Cancel</Button>
            <Button @click="handleImportConfirm">Import</Button>
          </div>
        </CardContent>
      </Card>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, watch, onMounted } from 'vue';
import { useTheme } from '../composables/useTheme.js';
import api from '../services/api';
import AppHeader from '../components/AppHeader.vue';
import Button from '@/components/ui/Button.vue';
import Input from '@/components/ui/Input.vue';
import Card from '@/components/ui/Card.vue';
import CardContent from '@/components/ui/CardContent.vue';
import CardHeader from '@/components/ui/CardHeader.vue';
import CardTitle from '@/components/ui/CardTitle.vue';
import Badge from '@/components/ui/Badge.vue';
import Separator from '@/components/ui/Separator.vue';
import { cn } from '@/lib/utils';

const { theme, setTheme, applyPreset, presets, saveThemeToBackend } = useTheme();

const customTheme = reactive({
  name: 'Custom Theme',
  colors: {
    background: '0 0% 100%',
    foreground: '222.2 84% 4.9%',
    card: '0 0% 100%',
    cardForeground: '222.2 84% 4.9%',
    popover: '0 0% 100%',
    popoverForeground: '222.2 84% 4.9%',
    primary: '221.2 83.2% 53.3%',
    primaryForeground: '210 40% 98%',
    secondary: '210 40% 96%',
    secondaryForeground: '222.2 84% 4.9%',
    muted: '210 40% 96%',
    mutedForeground: '215.4 16.3% 46.9%',
    accent: '210 40% 96%',
    accentForeground: '222.2 84% 4.9%',
    destructive: '0 84.2% 60.2%',
    destructiveForeground: '210 40% 98%',
    border: '214.3 31.8% 91.4%',
    input: '214.3 31.8% 91.4%',
    ring: '221.2 83.2% 53.3%',
  },
  radius: '0.5rem',
  mode: 'light'
});

const currentPreset = ref('default-light');
const showAdvancedColors = ref(false);
const isDarkMode = ref(false);
const showImportModal = ref(false);
const importJson = ref('');

const toast = ref({
  show: false,
  message: '',
  type: 'success'
});

const radiusOptions = [
  { label: 'None', value: '0rem' },
  { label: 'Small', value: '0.25rem' },
  { label: 'Medium', value: '0.5rem' },
  { label: 'Large', value: '0.75rem' },
];

const advancedColorKeys = [
  'card', 'cardForeground', 'popover', 'popoverForeground',
  'primaryForeground', 'secondaryForeground', 'mutedForeground',
  'accentForeground', 'destructiveForeground', 'border', 'input', 'ring'
];

// Watch for theme changes and apply them live
watch(customTheme, () => {
  setTheme({ ...customTheme });
  currentPreset.value = 'custom';
}, { deep: true });

const handleApplyPreset = (presetKey) => {
  const preset = presets[presetKey];
  if (preset) {
    Object.assign(customTheme, preset);
    currentPreset.value = presetKey;
    isDarkMode.value = preset.mode === 'dark';
    showToast('Preset applied successfully');
  }
};

const toggleDarkMode = () => {
  customTheme.mode = isDarkMode.value ? 'dark' : 'light';
  
  // Auto-adjust colors for dark mode if using a light preset
  if (isDarkMode.value && currentPreset.value.includes('light')) {
    const darkPreset = presets['default-dark'];
    if (darkPreset) {
      Object.assign(customTheme.colors, darkPreset.colors);
    }
  } else if (!isDarkMode.value && currentPreset.value.includes('dark')) {
    const lightPreset = presets['default-light'];
    if (lightPreset) {
      Object.assign(customTheme.colors, lightPreset.colors);
    }
  }
};

const handleApplyTheme = () => {
  setTheme({ ...customTheme });
  showToast('Theme applied successfully');
};

const handleSaveTheme = async () => {
  try {
    const success = await saveThemeToBackend({ ...customTheme }, api);
    if (success) {
      showToast('Theme saved successfully');
    } else {
      showToast('Failed to save theme', 'error');
    }
  } catch (error) {
    console.error('Error saving theme:', error);
    showToast('Failed to save theme', 'error');
  }
};

const handleExportTheme = () => {
  const themeJson = JSON.stringify(customTheme, null, 2);
  const blob = new Blob([themeJson], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = 'ora-theme.json';
  a.click();
  URL.revokeObjectURL(url);
  showToast('Theme exported successfully');
};

const handleImportTheme = () => {
  showImportModal.value = true;
  importJson.value = '';
};

const handleImportConfirm = () => {
  try {
    const imported = JSON.parse(importJson.value);
    if (imported.colors && imported.radius) {
      Object.assign(customTheme, imported);
      showImportModal.value = false;
      showToast('Theme imported successfully');
      currentPreset.value = 'custom';
    } else {
      showToast('Invalid theme format', 'error');
    }
  } catch (error) {
    showToast('Failed to parse JSON', 'error');
  }
};

const handleResetTheme = () => {
  if (confirm('Are you sure you want to reset to the default theme?')) {
    handleApplyPreset('default-light');
    showToast('Theme reset to default');
  }
};

const showToast = (message, type = 'success') => {
  toast.value = { show: true, message, type };
  setTimeout(() => {
    toast.value.show = false;
  }, 3000);
};

// Initialize with current theme
onMounted(() => {
  if (theme.value) {
    Object.assign(customTheme, theme.value);
    isDarkMode.value = theme.value.mode === 'dark';
  }
});
</script>
