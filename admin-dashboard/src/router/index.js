import { createRouter, createWebHistory } from 'vue-router';
import { useAuthStore } from '../../stores/auth';

const routes = [
  {
    path: '/login',
    name: 'Login',
    component: () => import('../../pages/login.vue'),
    meta: { requiresAuth: false }
  },
  {
    path: '/',
    name: 'Dashboard',
    component: () => import('../../pages/index.vue'),
    meta: { requiresAuth: true }
  },
  {
    path: '/moderation',
    name: 'Moderation',
    component: () => import('../../pages/Moderation.vue'),
    meta: { requiresAuth: true }
  },
  {
    path: '/content',
    name: 'Content',
    component: () => import('../../pages/Content.vue'),
    meta: { requiresAuth: true }
  },
  {
    path: '/users',
    name: 'Users',
    component: () => import('../../pages/Users.vue'),
    meta: { requiresAuth: true }
  },
  {
    path: '/analytics',
    name: 'Analytics',
    component: () => import('../../pages/Analytics.vue'),
    meta: { requiresAuth: true }
  },
  {
    path: '/notifications',
    name: 'Notifications',
    component: () => import('../../pages/Notifications.vue'),
    meta: { requiresAuth: true }
  },
  {
    path: '/announcements',
    name: 'Announcements',
    component: () => import('../../pages/Announcements.vue'),
    meta: { requiresAuth: true }
  },
  {
    path: '/settings',
    name: 'Settings',
    component: () => import('../../pages/Settings.vue'),
    meta: { requiresAuth: true }
  }
];

const router = createRouter({
  history: createWebHistory(),
  routes
});

// Navigation guard for authentication
router.beforeEach((to, from, next) => {
  const authStore = useAuthStore();
  
  // Initialize auth from localStorage on first load
  if (!authStore.admin && localStorage.getItem('admin')) {
    authStore.initializeFromStorage();
  }
  
  if (to.meta.requiresAuth && !authStore.isAuthenticated) {
    next('/login');
  } else if (to.path === '/login' && authStore.isAuthenticated) {
    next('/');
  } else {
    next();
  }
});

export default router;
