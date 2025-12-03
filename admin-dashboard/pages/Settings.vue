<template>
  <div class="min-h-screen bg-gray-50">
    <AppHeader />
    
    <main class="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
      <div class="px-4 py-6 sm:px-0">
        <h2 class="text-2xl font-bold text-gray-900 mb-6">System Settings</h2>
        
        <div v-if="loading" class="text-center py-12">
          <p class="text-gray-500">Loading settings...</p>
        </div>
        
        <div v-else class="space-y-6">
          <!-- Feature Flags -->
          <div class="bg-white shadow rounded-lg p-6">
            <div class="flex items-center justify-between mb-4">
              <div>
                <h3 class="text-lg font-medium text-gray-900">Feature Flags</h3>
                <p class="text-xs text-gray-500 mt-1">Flags are automatically synced to Firebase Remote Config for the iOS app</p>
              </div>
              <button
                @click="showAddFeatureFlag = true"
                class="px-3 py-1.5 text-sm bg-indigo-600 text-white rounded-md hover:bg-indigo-700 flex items-center gap-2"
              >
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
                </svg>
                Add Flag
              </button>
            </div>
            
            <div v-if="Object.keys(featureFlags).length === 0" class="text-center py-8 text-gray-500">
              <p>No feature flags configured. Click "Add Flag" to create one.</p>
            </div>
            
            <div v-else class="space-y-3">
              <div
                v-for="(value, key) in featureFlags"
                :key="key"
                class="flex items-center justify-between p-4 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors"
              >
                <div class="flex-1">
                  <div class="flex items-center gap-2 mb-1">
                    <label :for="key" class="text-sm font-medium text-gray-900">
                      {{ formatKey(key) }}
                    </label>
                    <span class="text-xs px-2 py-0.5 bg-gray-100 text-gray-600 rounded font-mono">{{ key }}</span>
                  </div>
                  <p class="text-xs text-gray-500">Toggle this feature on/off</p>
                </div>
                <div class="flex items-center gap-4">
                  <label class="relative inline-flex items-center cursor-pointer">
                    <input
                      :id="key"
                      v-model="featureFlags[key]"
                      type="checkbox"
                      class="sr-only peer"
                    />
                    <div class="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-indigo-300 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-indigo-600"></div>
                  </label>
                  <button
                    @click="deleteFeatureFlag(key)"
                    class="p-2 text-red-600 hover:bg-red-50 rounded-md transition-colors"
                    title="Delete flag"
                  >
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                    </svg>
                  </button>
                </div>
              </div>
            </div>
            
            <div class="mt-6 flex justify-end">
              <button
                @click="saveFeatureFlags"
                :disabled="saving"
                class="px-4 py-2 bg-indigo-600 text-white rounded-md hover:bg-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {{ saving ? 'Saving...' : 'Save Changes' }}
              </button>
            </div>
          </div>
          
          <!-- Remote Config -->
          <div class="bg-white shadow rounded-lg p-6">
            <div class="flex items-center justify-between mb-4">
              <h3 class="text-lg font-medium text-gray-900">Remote Config</h3>
              <button
                @click="showAddRemoteConfig = true"
                class="px-3 py-1.5 text-sm bg-indigo-600 text-white rounded-md hover:bg-indigo-700 flex items-center gap-2"
              >
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
                </svg>
                Add Config
              </button>
            </div>
            
            <div v-if="Object.keys(remoteConfig).length === 0" class="text-center py-8 text-gray-500">
              <p>No remote config values configured. Click "Add Config" to create one.</p>
            </div>
            
            <div v-else class="space-y-4">
              <div
                v-for="(value, key) in remoteConfig"
                :key="key"
                class="p-4 border border-gray-200 rounded-lg hover:bg-gray-50 transition-colors"
              >
                <div class="flex items-start justify-between gap-4 mb-2">
                  <div class="flex-1">
                    <div class="flex items-center gap-2 mb-2">
                      <label :for="`config-${key}`" class="text-sm font-medium text-gray-900">
                        {{ formatKey(key) }}
                      </label>
                      <span class="text-xs px-2 py-0.5 bg-gray-100 text-gray-600 rounded font-mono">{{ key }}</span>
                    </div>
                    <input
                      :id="`config-${key}`"
                      v-model="remoteConfig[key]"
                      type="text"
                      class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                      placeholder="Enter config value"
                    />
                  </div>
                  <button
                    @click="deleteRemoteConfig(key)"
                    class="p-2 text-red-600 hover:bg-red-50 rounded-md transition-colors flex-shrink-0"
                    title="Delete config"
                  >
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                    </svg>
                  </button>
                </div>
              </div>
            </div>
            
            <div class="mt-6 flex justify-end">
              <button
                @click="saveRemoteConfig"
                :disabled="saving"
                class="px-4 py-2 bg-indigo-600 text-white rounded-md hover:bg-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {{ saving ? 'Saving...' : 'Save Changes' }}
              </button>
            </div>
          </div>
          
          <!-- UI Styling Settings -->
          <div class="bg-white shadow rounded-lg p-6">
            <div class="flex items-center justify-between mb-4">
              <h3 class="text-lg font-medium text-gray-900">UI Styling Settings</h3>
            </div>
            <p class="text-sm text-gray-600 mb-6">Customize the appearance of the admin dashboard</p>
            
            <div class="space-y-6">
              <!-- Primary Color -->
              <div>
                <label for="primaryColor" class="block text-sm font-medium text-gray-700 mb-2">
                  Primary Color
                </label>
                <div class="flex items-center gap-4">
                  <input
                    id="primaryColor"
                    v-model="uiSettings.primaryColor"
                    type="color"
                    class="w-16 h-10 border border-gray-300 rounded-md cursor-pointer"
                  />
                  <input
                    v-model="uiSettings.primaryColor"
                    type="text"
                    placeholder="#6366f1"
                    class="flex-1 px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 font-mono text-sm"
                  />
                </div>
                <p class="text-xs text-gray-500 mt-1">Main brand color used for buttons and accents</p>
              </div>

              <!-- Secondary Color -->
              <div>
                <label for="secondaryColor" class="block text-sm font-medium text-gray-700 mb-2">
                  Secondary Color
                </label>
                <div class="flex items-center gap-4">
                  <input
                    id="secondaryColor"
                    v-model="uiSettings.secondaryColor"
                    type="color"
                    class="w-16 h-10 border border-gray-300 rounded-md cursor-pointer"
                  />
                  <input
                    v-model="uiSettings.secondaryColor"
                    type="text"
                    placeholder="#8b5cf6"
                    class="flex-1 px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 font-mono text-sm"
                  />
                </div>
                <p class="text-xs text-gray-500 mt-1">Secondary accent color</p>
              </div>

              <!-- Background Color -->
              <div>
                <label for="backgroundColor" class="block text-sm font-medium text-gray-700 mb-2">
                  Background Color
                </label>
                <div class="flex items-center gap-4">
                  <input
                    id="backgroundColor"
                    v-model="uiSettings.backgroundColor"
                    type="color"
                    class="w-16 h-10 border border-gray-300 rounded-md cursor-pointer"
                  />
                  <input
                    v-model="uiSettings.backgroundColor"
                    type="text"
                    placeholder="#f9fafb"
                    class="flex-1 px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 font-mono text-sm"
                  />
                </div>
                <p class="text-xs text-gray-500 mt-1">Main background color for the dashboard</p>
              </div>

              <!-- Border Radius -->
              <div>
                <label for="borderRadius" class="block text-sm font-medium text-gray-700 mb-2">
                  Border Radius (px)
                </label>
                <input
                  id="borderRadius"
                  v-model.number="uiSettings.borderRadius"
                  type="number"
                  min="0"
                  max="24"
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                />
                <p class="text-xs text-gray-500 mt-1">Controls the roundness of buttons and cards (0-24px)</p>
              </div>

              <!-- Font Family -->
              <div>
                <label for="fontFamily" class="block text-sm font-medium text-gray-700 mb-2">
                  Font Family
                </label>
                <select
                  id="fontFamily"
                  v-model="uiSettings.fontFamily"
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                >
                  <option value="Inter">Inter (Default)</option>
                  <option value="Roboto">Roboto</option>
                  <option value="Open Sans">Open Sans</option>
                  <option value="Lato">Lato</option>
                  <option value="Montserrat">Montserrat</option>
                  <option value="Poppins">Poppins</option>
                  <option value="System">System Default</option>
                </select>
                <p class="text-xs text-gray-500 mt-1">Font family for the entire dashboard</p>
              </div>

              <!-- Header Height -->
              <div>
                <label for="headerHeight" class="block text-sm font-medium text-gray-700 mb-2">
                  Header Height (px)
                </label>
                <input
                  id="headerHeight"
                  v-model.number="uiSettings.headerHeight"
                  type="number"
                  min="48"
                  max="96"
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                />
                <p class="text-xs text-gray-500 mt-1">Height of the top navigation header (48-96px)</p>
              </div>

              <!-- Sidebar Width -->
              <div>
                <label for="sidebarWidth" class="block text-sm font-medium text-gray-700 mb-2">
                  Sidebar Width (px)
                </label>
                <input
                  id="sidebarWidth"
                  v-model.number="uiSettings.sidebarWidth"
                  type="number"
                  min="200"
                  max="400"
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                />
                <p class="text-xs text-gray-500 mt-1">Width of the sidebar navigation (200-400px)</p>
              </div>

              <!-- Dark Mode Toggle -->
              <div class="flex items-center justify-between p-4 border border-gray-200 rounded-lg">
                <div>
                  <p class="text-sm font-medium text-gray-700">Enable Dark Mode</p>
                  <p class="text-xs text-gray-500 mt-1">Allow users to toggle dark mode</p>
                </div>
                <label class="relative inline-flex items-center cursor-pointer">
                  <input
                    v-model="uiSettings.enableDarkMode"
                    type="checkbox"
                    class="sr-only peer"
                  />
                  <div class="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-indigo-300 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-indigo-600"></div>
                </label>
              </div>
            </div>

            <div class="mt-6 flex justify-end gap-3">
              <button
                @click="resetUISettings"
                class="px-4 py-2 text-gray-700 bg-gray-100 rounded-md hover:bg-gray-200"
              >
                Reset to Defaults
              </button>
              <button
                @click="saveUISettings"
                :disabled="saving"
                class="px-4 py-2 bg-indigo-600 text-white rounded-md hover:bg-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {{ saving ? 'Saving...' : 'Save Changes' }}
              </button>
            </div>
          </div>
          
          <!-- Welcome Screen Images -->
          <div class="bg-white shadow rounded-lg p-6">
            <div class="flex items-center justify-between mb-4">
              <div>
                <h3 class="text-lg font-medium text-gray-900">Welcome Screen Images</h3>
                <p class="text-xs text-gray-500 mt-1">Manage images displayed in the animated background on the welcome screen</p>
              </div>
              <label
                for="welcome-image-upload"
                class="px-3 py-1.5 text-sm bg-indigo-600 text-white rounded-md hover:bg-indigo-700 flex items-center gap-2 cursor-pointer"
              >
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
                </svg>
                Upload Image
              </label>
              <input
                id="welcome-image-upload"
                type="file"
                accept="image/*"
                class="hidden"
                @change="handleWelcomeImageUpload"
              />
            </div>
            
            <div v-if="welcomeImagesLoading" class="text-center py-8 text-gray-500">
              <p>Loading images...</p>
            </div>
            
            <div v-else-if="welcomeImages.length === 0" class="text-center py-8 text-gray-500">
              <p>No images uploaded yet. Click "Upload Image" to add your first image.</p>
            </div>
            
            <div v-else class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
              <div
                v-for="(image, index) in welcomeImages"
                :key="image.id"
                class="relative group"
              >
                <div class="aspect-square rounded-lg overflow-hidden bg-gray-100">
                  <img
                    :src="image.url"
                    :alt="`Welcome image ${index + 1}`"
                    class="w-full h-full object-cover"
                  />
                </div>
                <div class="absolute inset-0 bg-black bg-opacity-0 group-hover:bg-opacity-50 transition-all duration-200 flex items-center justify-center gap-2 opacity-0 group-hover:opacity-100">
                  <button
                    @click="moveWelcomeImage(index, 'up')"
                    :disabled="index === 0"
                    class="p-2 bg-white rounded-md hover:bg-gray-100 disabled:opacity-50 disabled:cursor-not-allowed"
                    title="Move up"
                  >
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7" />
                    </svg>
                  </button>
                  <button
                    @click="moveWelcomeImage(index, 'down')"
                    :disabled="index === welcomeImages.length - 1"
                    class="p-2 bg-white rounded-md hover:bg-gray-100 disabled:opacity-50 disabled:cursor-not-allowed"
                    title="Move down"
                  >
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                    </svg>
                  </button>
                  <button
                    @click="deleteWelcomeImage(image.id)"
                    class="p-2 bg-red-600 text-white rounded-md hover:bg-red-700"
                    title="Delete"
                  >
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                    </svg>
                  </button>
                </div>
                <div class="mt-2 text-xs text-center text-gray-500">
                  Order: {{ image.order }}
                </div>
              </div>
            </div>
          </div>
          
          <!-- Maintenance Mode -->
          <div class="bg-white shadow rounded-lg p-6">
            <h3 class="text-lg font-medium text-gray-900 mb-4">Maintenance Mode</h3>
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm text-gray-700">Enable maintenance mode</p>
                <p class="text-xs text-gray-500 mt-1">When enabled, the app will be unavailable to users</p>
              </div>
              <label class="relative inline-flex items-center cursor-pointer">
                <input
                  v-model="maintenanceMode"
                  type="checkbox"
                  class="sr-only peer"
                />
                <div class="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-indigo-300 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-indigo-600"></div>
              </label>
            </div>
            <div class="mt-6 flex justify-end">
              <button
                @click="saveMaintenanceMode"
                :disabled="saving"
                class="px-4 py-2 bg-indigo-600 text-white rounded-md hover:bg-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {{ saving ? 'Saving...' : 'Save Changes' }}
              </button>
            </div>
          </div>
        </div>
      </div>
    </main>

    <!-- Add Feature Flag Modal -->
    <div
      v-if="showAddFeatureFlag"
      class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"
      @click.self="showAddFeatureFlag = false"
    >
      <div class="bg-white rounded-lg shadow-xl max-w-md w-full mx-4">
        <div class="p-6">
          <h3 class="text-lg font-medium text-gray-900 mb-4">Add Feature Flag</h3>
          <div class="space-y-4">
            <div>
              <label for="newFlagKey" class="block text-sm font-medium text-gray-700 mb-1">
                Flag Key
              </label>
              <input
                id="newFlagKey"
                v-model="newFeatureFlagKey"
                type="text"
                placeholder="e.g., enableNewFeature"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                @keyup.enter="addFeatureFlag"
              />
              <p class="text-xs text-gray-500 mt-1">Use camelCase (e.g., enableNewFeature)</p>
            </div>
            <div>
              <label class="flex items-center gap-2">
                <input
                  v-model="newFeatureFlagValue"
                  type="checkbox"
                  class="w-4 h-4 text-indigo-600 border-gray-300 rounded focus:ring-indigo-500"
                />
                <span class="text-sm text-gray-700">Enabled by default</span>
              </label>
            </div>
          </div>
          <div class="mt-6 flex justify-end gap-3">
            <button
              @click="showAddFeatureFlag = false; newFeatureFlagKey = ''; newFeatureFlagValue = false"
              class="px-4 py-2 text-gray-700 bg-gray-100 rounded-md hover:bg-gray-200"
            >
              Cancel
            </button>
            <button
              @click="addFeatureFlag"
              :disabled="!newFeatureFlagKey.trim()"
              class="px-4 py-2 bg-indigo-600 text-white rounded-md hover:bg-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Add Flag
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Add Remote Config Modal -->
    <div
      v-if="showAddRemoteConfig"
      class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"
      @click.self="showAddRemoteConfig = false"
    >
      <div class="bg-white rounded-lg shadow-xl max-w-md w-full mx-4">
        <div class="p-6">
          <h3 class="text-lg font-medium text-gray-900 mb-4">Add Remote Config</h3>
          <div class="space-y-4">
            <div>
              <label for="newConfigKey" class="block text-sm font-medium text-gray-700 mb-1">
                Config Key
              </label>
              <input
                id="newConfigKey"
                v-model="newRemoteConfigKey"
                type="text"
                placeholder="e.g., maxUploadSize"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                @keyup.enter="addRemoteConfig"
              />
              <p class="text-xs text-gray-500 mt-1">Use camelCase (e.g., maxUploadSize)</p>
            </div>
            <div>
              <label for="newConfigValue" class="block text-sm font-medium text-gray-700 mb-1">
                Config Value
              </label>
              <input
                id="newConfigValue"
                v-model="newRemoteConfigValue"
                type="text"
                placeholder="e.g., 10485760"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
                @keyup.enter="addRemoteConfig"
              />
            </div>
          </div>
          <div class="mt-6 flex justify-end gap-3">
            <button
              @click="showAddRemoteConfig = false; newRemoteConfigKey = ''; newRemoteConfigValue = ''"
              class="px-4 py-2 text-gray-700 bg-gray-100 rounded-md hover:bg-gray-200"
            >
              Cancel
            </button>
            <button
              @click="addRemoteConfig"
              :disabled="!newRemoteConfigKey.trim() || !newRemoteConfigValue.trim()"
              class="px-4 py-2 bg-indigo-600 text-white rounded-md hover:bg-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Add Config
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Toast Notification -->
    <div
      v-if="toast.show"
      class="fixed bottom-4 right-4 bg-white shadow-lg rounded-lg p-4 border-l-4 z-50 max-w-sm"
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
        <p class="text-sm text-gray-900">{{ toast.message }}</p>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, nextTick } from 'vue';
import api from '../services/api';
import AppHeader from '../components/AppHeader.vue';

const loading = ref(true);
const saving = ref(false);
const featureFlags = ref({});
const remoteConfig = ref({});
const maintenanceMode = ref(false);
const welcomeImages = ref([]);
const welcomeImagesLoading = ref(false);
const uiSettings = ref({
  primaryColor: '#6366f1',
  secondaryColor: '#8b5cf6',
  backgroundColor: '#f9fafb',
  borderRadius: 8,
  fontFamily: 'Inter',
  headerHeight: 64,
  sidebarWidth: 256,
  enableDarkMode: false
});

const showAddFeatureFlag = ref(false);
const newFeatureFlagKey = ref('');
const newFeatureFlagValue = ref(false);

const showAddRemoteConfig = ref(false);
const newRemoteConfigKey = ref('');
const newRemoteConfigValue = ref('');

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
  headerHeight: 64,
  sidebarWidth: 256,
  enableDarkMode: false
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
    remoteConfig.value = settings.remoteConfig || {};
    maintenanceMode.value = settings.maintenanceMode || false;

    // Fetch welcome images
    await fetchWelcomeImages();

    // Merge saved UI settings with defaults, ensuring proper types
    const savedUISettings = settings.uiSettings;
    console.log('Fetched settings from server:', settings);
    console.log('Fetched UI settings from server:', savedUISettings);
    console.log('Type of uiSettings:', typeof savedUISettings, Array.isArray(savedUISettings));

    // Always update uiSettings, merging with defaults
    // Use nullish coalescing to preserve falsy values (0, false, empty string)
    if (savedUISettings && typeof savedUISettings === 'object' && !Array.isArray(savedUISettings)) {
      // Create a new object to ensure reactivity
      const mergedSettings = {
        primaryColor: savedUISettings.primaryColor !== undefined ? String(savedUISettings.primaryColor) : defaultUISettings.primaryColor,
        secondaryColor: savedUISettings.secondaryColor !== undefined ? String(savedUISettings.secondaryColor) : defaultUISettings.secondaryColor,
        backgroundColor: savedUISettings.backgroundColor !== undefined ? String(savedUISettings.backgroundColor) : defaultUISettings.backgroundColor,
        borderRadius: savedUISettings.borderRadius !== undefined ? Number(savedUISettings.borderRadius) : defaultUISettings.borderRadius,
        fontFamily: savedUISettings.fontFamily !== undefined ? String(savedUISettings.fontFamily) : defaultUISettings.fontFamily,
        headerHeight: savedUISettings.headerHeight !== undefined ? Number(savedUISettings.headerHeight) : defaultUISettings.headerHeight,
        sidebarWidth: savedUISettings.sidebarWidth !== undefined ? Number(savedUISettings.sidebarWidth) : defaultUISettings.sidebarWidth,
        enableDarkMode: savedUISettings.enableDarkMode !== undefined ? Boolean(savedUISettings.enableDarkMode) : defaultUISettings.enableDarkMode
      };
      
      // Replace the entire object to trigger reactivity
      uiSettings.value = mergedSettings;
      console.log('Updated uiSettings.value to:', uiSettings.value);
    } else {
      console.log('No valid saved UI settings found, keeping current values or defaults');
      // If no saved settings, ensure we at least have defaults
      if (!uiSettings.value || Object.keys(uiSettings.value).length === 0) {
        uiSettings.value = { ...defaultUISettings };
      }
    }
  } catch (error) {
    console.error('Error fetching settings:', error);
    // Initialize with defaults
    featureFlags.value = {};
    remoteConfig.value = {};
    maintenanceMode.value = false;
    uiSettings.value = { ...defaultUISettings };
  } finally {
    loading.value = false;
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

const addRemoteConfig = () => {
  if (!newRemoteConfigKey.value.trim() || !newRemoteConfigValue.value.trim()) {
    showToast('Please enter both key and value', 'error');
    return;
  }
  
  const key = newRemoteConfigKey.value.trim();
  if (remoteConfig.value[key] !== undefined) {
    showToast('Remote config key already exists', 'error');
    return;
  }
  
  remoteConfig.value[key] = newRemoteConfigValue.value.trim();
  newRemoteConfigKey.value = '';
  newRemoteConfigValue.value = '';
  showAddRemoteConfig.value = false;
  showToast('Remote config added. Don\'t forget to save!', 'success');
};

const deleteRemoteConfig = (key) => {
  if (confirm(`Are you sure you want to delete the remote config "${key}"?`)) {
    delete remoteConfig.value[key];
    showToast('Remote config deleted. Don\'t forget to save!', 'success');
  }
};

const saveFeatureFlags = async () => {
  try {
    saving.value = true;
    const response = await api.post('/api/admin/settings', {
      featureFlags: featureFlags.value
    });
    
    // Check for Remote Config sync errors
    if (response.data?.remoteConfigError) {
      showToast(`Feature flags saved, but Remote Config sync failed: ${response.data.remoteConfigError.message}`, 'error');
    } else {
      showToast('Feature flags saved and synced to Firebase Remote Config', 'success');
    }
  } catch (error) {
    console.error('Error saving feature flags:', error);
    const errorMsg = error.response?.data?.message || error.message || 'Failed to save feature flags';
    showToast(errorMsg, 'error');
  } finally {
    saving.value = false;
  }
};

const saveRemoteConfig = async () => {
  try {
    saving.value = true;
    const response = await api.post('/api/admin/settings', {
      remoteConfig: remoteConfig.value
    });
    
    // Check for Remote Config sync errors
    if (response.data?.remoteConfigError) {
      showToast(`Remote config saved, but Remote Config sync failed: ${response.data.remoteConfigError.message}`, 'error');
    } else {
      showToast('Remote config saved successfully', 'success');
    }
  } catch (error) {
    console.error('Error saving remote config:', error);
    const errorMsg = error.response?.data?.message || error.message || 'Failed to save remote config';
    showToast(errorMsg, 'error');
  } finally {
    saving.value = false;
  }
};

const saveUISettings = async () => {
  try {
    saving.value = true;
    // Validate color formats
    const colorRegex = /^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$/;
    if (!colorRegex.test(uiSettings.value.primaryColor)) {
      showToast('Invalid primary color format. Use hex format (e.g., #6366f1)', 'error');
      saving.value = false;
      return;
    }
    if (!colorRegex.test(uiSettings.value.secondaryColor)) {
      showToast('Invalid secondary color format. Use hex format (e.g., #8b5cf6)', 'error');
      saving.value = false;
      return;
    }
    if (!colorRegex.test(uiSettings.value.backgroundColor)) {
      showToast('Invalid background color format. Use hex format (e.g., #f9fafb)', 'error');
      saving.value = false;
      return;
    }
    
    // Ensure numeric values are properly formatted
    const settingsToSave = {
      primaryColor: uiSettings.value.primaryColor,
      secondaryColor: uiSettings.value.secondaryColor,
      backgroundColor: uiSettings.value.backgroundColor,
      borderRadius: Number(uiSettings.value.borderRadius),
      fontFamily: uiSettings.value.fontFamily,
      headerHeight: Number(uiSettings.value.headerHeight),
      sidebarWidth: Number(uiSettings.value.sidebarWidth),
      enableDarkMode: Boolean(uiSettings.value.enableDarkMode)
    };
    
    console.log('Saving UI settings:', settingsToSave);
    
    const response = await api.post('/api/admin/settings', {
      uiSettings: settingsToSave
    });
    
    console.log('Save response:', response.data);
    console.log('UI Settings in response:', response.data?.settings?.uiSettings);
    
    // Check if the response contains the saved uiSettings
    if (response.data?.settings?.uiSettings) {
      // Update local state with the saved values from server immediately
      const savedUISettings = response.data.settings.uiSettings;
      console.log('Updating uiSettings from response:', savedUISettings);
      
      // Create a new object to ensure reactivity
      const updatedSettings = {
        primaryColor: savedUISettings.primaryColor ?? defaultUISettings.primaryColor,
        secondaryColor: savedUISettings.secondaryColor ?? defaultUISettings.secondaryColor,
        backgroundColor: savedUISettings.backgroundColor ?? defaultUISettings.backgroundColor,
        borderRadius: savedUISettings.borderRadius !== undefined ? Number(savedUISettings.borderRadius) : defaultUISettings.borderRadius,
        fontFamily: savedUISettings.fontFamily ?? defaultUISettings.fontFamily,
        headerHeight: savedUISettings.headerHeight !== undefined ? Number(savedUISettings.headerHeight) : defaultUISettings.headerHeight,
        sidebarWidth: savedUISettings.sidebarWidth !== undefined ? Number(savedUISettings.sidebarWidth) : defaultUISettings.sidebarWidth,
        enableDarkMode: savedUISettings.enableDarkMode !== undefined ? Boolean(savedUISettings.enableDarkMode) : defaultUISettings.enableDarkMode
      };
      
      // Replace the entire object to trigger reactivity
      uiSettings.value = updatedSettings;
      console.log('Updated uiSettings.value:', uiSettings.value);
    }
    
    // Refetch settings to ensure we have the latest data from Firestore
    await fetchSettings();
    
    // Wait for Vue to process the reactive update
    await nextTick();
    
    // Verify the fetch got the right data
    console.log('UI Settings after fetch and nextTick:', uiSettings.value);
    
    showToast('UI settings saved successfully', 'success');
    
    // Apply settings to the current page
    applyUISettings();
  } catch (error) {
    console.error('Error saving UI settings:', error);
    console.error('Error response:', error.response);
    
    let errorMessage = 'Failed to save UI settings';
    if (error.response) {
      if (error.response.status === 403) {
        errorMessage = 'Permission denied: You need super_admin role to save settings';
      } else if (error.response.status === 401) {
        errorMessage = 'Authentication failed. Please log in again.';
      } else if (error.response.data?.message) {
        errorMessage = error.response.data.message;
      } else {
        errorMessage = `Error ${error.response.status}: ${error.response.statusText}`;
      }
    } else if (error.message) {
      errorMessage = error.message;
    }
    
    showToast(errorMessage, 'error');
  } finally {
    saving.value = false;
  }
};

const resetUISettings = () => {
  if (confirm('Are you sure you want to reset UI settings to defaults?')) {
    uiSettings.value = { ...defaultUISettings };
    showToast('UI settings reset to defaults. Don\'t forget to save!', 'success');
  }
};

const applyUISettings = () => {
  const root = document.documentElement;
  root.style.setProperty('--primary-color', uiSettings.value.primaryColor);
  root.style.setProperty('--secondary-color', uiSettings.value.secondaryColor);
  root.style.setProperty('--background-color', uiSettings.value.backgroundColor);
  root.style.setProperty('--border-radius', `${uiSettings.value.borderRadius}px`);
  root.style.setProperty('--font-family', uiSettings.value.fontFamily);
  root.style.setProperty('--header-height', `${uiSettings.value.headerHeight}px`);
  root.style.setProperty('--sidebar-width', `${uiSettings.value.sidebarWidth}px`);
};

const saveMaintenanceMode = async () => {
  try {
    saving.value = true;
    const response = await api.post('/api/admin/settings', {
      maintenanceMode: maintenanceMode.value
    });
    
    // Check for Remote Config sync errors
    if (response.data?.remoteConfigError) {
      showToast(`Maintenance mode saved, but Remote Config sync failed: ${response.data.remoteConfigError.message}`, 'error');
    } else {
      showToast('Maintenance mode updated successfully', 'success');
    }
  } catch (error) {
    console.error('Error saving maintenance mode:', error);
    const errorMsg = error.response?.data?.message || error.message || 'Failed to update maintenance mode';
    showToast(errorMsg, 'error');
  } finally {
    saving.value = false;
  }
};

const fetchWelcomeImages = async () => {
  try {
    welcomeImagesLoading.value = true;
    const response = await api.get('/api/admin/welcome-images');
    if (response.data.success) {
      welcomeImages.value = response.data.images || [];
    }
  } catch (error) {
    console.error('Error fetching welcome images:', error);
    showToast('Failed to fetch welcome images', 'error');
  } finally {
    welcomeImagesLoading.value = false;
  }
};

const handleWelcomeImageUpload = async (event) => {
  const file = event.target.files?.[0];
  if (!file) return;
  
  try {
    saving.value = true;
    const formData = new FormData();
    formData.append('image', file);
    
    const response = await api.post('/api/admin/welcome-images', formData, {
      headers: {
        'Content-Type': 'multipart/form-data'
      }
    });
    
    if (response.data.success) {
      showToast('Image uploaded successfully', 'success');
      await fetchWelcomeImages();
    }
  } catch (error) {
    console.error('Error uploading welcome image:', error);
    const errorMsg = error.response?.data?.message || error.message || 'Failed to upload image';
    showToast(errorMsg, 'error');
  } finally {
    saving.value = false;
    // Reset file input
    event.target.value = '';
  }
};

const deleteWelcomeImage = async (imageId) => {
  if (!confirm('Are you sure you want to delete this image?')) {
    return;
  }
  
  try {
    saving.value = true;
    const response = await api.delete(`/api/admin/welcome-images/${imageId}`);
    
    if (response.data.success) {
      showToast('Image deleted successfully', 'success');
      await fetchWelcomeImages();
    }
  } catch (error) {
    console.error('Error deleting welcome image:', error);
    const errorMsg = error.response?.data?.message || error.message || 'Failed to delete image';
    showToast(errorMsg, 'error');
  } finally {
    saving.value = false;
  }
};

const moveWelcomeImage = async (index, direction) => {
  if (direction === 'up' && index === 0) return;
  if (direction === 'down' && index === welcomeImages.value.length - 1) return;
  
  const newIndex = direction === 'up' ? index - 1 : index + 1;
  const images = [...welcomeImages.value];
  [images[index], images[newIndex]] = [images[newIndex], images[index]];
  
  try {
    saving.value = true;
    const imageIds = images.map(img => img.id);
    const response = await api.put('/api/admin/welcome-images/reorder', { imageIds });
    
    if (response.data.success) {
      welcomeImages.value = response.data.images;
      showToast('Image order updated', 'success');
    }
  } catch (error) {
    console.error('Error reordering welcome images:', error);
    const errorMsg = error.response?.data?.message || error.message || 'Failed to reorder images';
    showToast(errorMsg, 'error');
    // Revert on error
    await fetchWelcomeImages();
  } finally {
    saving.value = false;
  }
};

onMounted(() => {
  fetchSettings().then(() => {
    applyUISettings();
  });
});
</script>

