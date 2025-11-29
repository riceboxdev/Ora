# Dashboard Pattern Template

This document outlines the standard pattern for creating web dashboards that interact with API services, based on the Waitlist dashboard architecture.

## Directory Structure

```
dashboard/
├── src/
│   ├── services/
│   │   └── api.js               # Axios client with interceptors
│   ├── stores/
│   │   └── auth.js              # Auth state management (Pinia/Vuex)
│   ├── views/                   # Dashboard pages
│   │   ├── Login.vue
│   │   ├── Dashboard.vue
│   │   └── [Resource].vue
│   ├── components/              # Reusable UI components
│   │   ├── AppHeader.vue
│   │   └── [Resource]Card.vue
│   ├── router/
│   │   └── index.js             # Vue Router configuration
│   └── App.vue
├── package.json
└── vite.config.js
```

## API Service Pattern

```javascript
import axios from 'axios';

// Use relative URLs since backend and dashboard are on the same domain
const API_URL = import.meta.env.VITE_API_URL || '';

const api = axios.create({
  baseURL: API_URL,
  headers: {
    'Content-Type': 'application/json'
  }
});

// Add token to requests
api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Handle auth errors
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401 && 
        !window.location.pathname.includes('/login') && 
        !window.location.pathname.includes('/register')) {
      localStorage.removeItem('token');
      localStorage.removeItem('user');
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

export default api;
```

## Auth Store Pattern (Pinia)

```javascript
import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import api from '../services/api';

export const useAuthStore = defineStore('auth', () => {
  const user = ref(null);
  const token = ref(localStorage.getItem('token') || null);
  const loading = ref(false);
  const error = ref(null);

  const isAuthenticated = computed(() => !!token.value);

  async function login(email, password) {
    try {
      loading.value = true;
      error.value = null;
      
      const response = await api.post('/api/auth/login', { email, password });
      
      token.value = response.data.token;
      user.value = response.data.user;
      localStorage.setItem('token', token.value);
      localStorage.setItem('user', JSON.stringify(user.value));
      
      return response.data;
    } catch (err) {
      error.value = err.response?.data?.message || 'Login failed';
      throw err;
    } finally {
      loading.value = false;
    }
  }

  function logout() {
    token.value = null;
    user.value = null;
    localStorage.removeItem('token');
    localStorage.removeItem('user');
  }

  async function fetchUser() {
    try {
      const response = await api.get('/api/auth/me');
      user.value = response.data;
      return response.data;
    } catch (err) {
      logout();
      throw err;
    }
  }

  return {
    user,
    token,
    loading,
    error,
    isAuthenticated,
    login,
    logout,
    fetchUser
  };
});
```

## Router Pattern

```javascript
import { createRouter, createWebHistory } from 'vue-router';
import { useAuthStore } from '../stores/auth';

const routes = [
  {
    path: '/login',
    name: 'Login',
    component: () => import('../views/Login.vue'),
    meta: { requiresAuth: false }
  },
  {
    path: '/',
    name: 'Dashboard',
    component: () => import('../views/Dashboard.vue'),
    meta: { requiresAuth: true }
  }
];

const router = createRouter({
  history: createWebHistory(),
  routes
});

// Auth guard
router.beforeEach((to, from, next) => {
  const authStore = useAuthStore();
  
  if (to.meta.requiresAuth && !authStore.isAuthenticated) {
    next('/login');
  } else if (to.path === '/login' && authStore.isAuthenticated) {
    next('/');
  } else {
    next();
  }
});

export default router;
```

## View Pattern

```vue
<template>
  <div class="min-h-screen bg-gray-50">
    <AppHeader />
    
    <main class="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
      <div class="px-4 py-6 sm:px-0">
        <h2 class="text-2xl font-bold text-gray-900 mb-4">Resource List</h2>
        
        <div v-if="loading" class="text-center py-12">
          <p class="text-gray-500">Loading...</p>
        </div>
        
        <div v-else-if="resources.length === 0" class="text-center py-12">
          <p class="text-gray-500 mb-4">No resources found.</p>
        </div>
        
        <div v-else class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
          <ResourceCard
            v-for="resource in resources"
            :key="resource.id"
            :resource="resource"
            @delete="handleDelete"
          />
        </div>
      </div>
    </main>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import api from '../services/api';
import AppHeader from '../components/AppHeader.vue';
import ResourceCard from '../components/ResourceCard.vue';

const resources = ref([]);
const loading = ref(true);

const fetchResources = async () => {
  try {
    loading.value = true;
    const response = await api.get('/api/resources');
    resources.value = response.data;
  } catch (error) {
    console.error('Error fetching resources:', error);
  } finally {
    loading.value = false;
  }
};

const handleDelete = async (id) => {
  if (confirm('Are you sure you want to delete this resource?')) {
    try {
      await api.delete(`/api/resources/${id}`);
      resources.value = resources.value.filter(r => r.id !== id);
    } catch (error) {
      console.error('Error deleting resource:', error);
      alert('Failed to delete resource');
    }
  }
};

onMounted(() => {
  fetchResources();
});
</script>
```

## Component Pattern

```vue
<template>
  <div class="bg-white border border-gray-200 rounded-lg p-6">
    <h3 class="text-lg font-semibold text-gray-900 mb-2">{{ resource.name }}</h3>
    <p class="text-sm text-gray-600 mb-4">{{ resource.description }}</p>
    
    <div class="flex justify-end gap-2">
      <button
        @click="$emit('delete', resource.id)"
        class="px-4 py-2 text-sm font-medium text-red-600 hover:text-red-700"
      >
        Delete
      </button>
    </div>
  </div>
</template>

<script setup>
defineProps({
  resource: {
    type: Object,
    required: true
  }
});

defineEmits(['delete']);
</script>
```

## Best Practices

1. **State Management**: Use Pinia (or Vuex) for global state
2. **API Calls**: Centralize in service files, use interceptors for auth
3. **Error Handling**: Show user-friendly error messages
4. **Loading States**: Always show loading indicators
5. **Responsive Design**: Use Tailwind CSS for responsive layouts
6. **Environment Variables**: Use Vite env variables for API URLs
7. **Routing**: Protect routes with auth guards
8. **Token Storage**: Store tokens in localStorage, clear on logout













