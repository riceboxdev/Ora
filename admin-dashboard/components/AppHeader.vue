<template>
  <header class="bg-white shadow">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="flex justify-between h-16">
        <div class="flex">
          <div class="flex-shrink-0 flex items-center">
            <img src="/logo-black.svg" alt="ORA Logo" class="h-8 w-auto" />
          </div>
          <nav class="hidden sm:ml-6 sm:flex sm:space-x-2">
            <router-link
              to="/"
              class="border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700 inline-flex items-center px-3 py-2 text-sm font-medium rounded-md"
              active-class="bg-gray-100 text-gray-900"
            >
              Dashboard
            </router-link>
            <router-link
              to="/users"
              class="border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700 inline-flex items-center px-3 py-2 text-sm font-medium rounded-md"
              active-class="bg-gray-100 text-gray-900"
            >
              Users
            </router-link>
            <div class="relative group">
              <button class="inline-flex items-center px-3 py-2 text-sm font-medium text-gray-500 hover:text-gray-700 hover:bg-gray-100 rounded-md">
                Content
                <svg class="ml-1 h-4 w-4" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" clip-rule="evenodd" />
                </svg>
              </button>
              <div class="absolute left-0 mt-1 w-56 rounded-md shadow-lg bg-white ring-1 ring-black ring-opacity-5 opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-all duration-200 z-10">
                <div class="py-1">
                  <router-link
                    to="/content"
                    class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"
                    active-class="bg-gray-100 text-gray-900"
                  >
                    All Content
                  </router-link>
                  <router-link
                    to="/content/posts"
                    class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"
                    active-class="bg-gray-100 text-gray-900"
                  >
                    Posts
                  </router-link>
                  <router-link
                    to="/content/comments"
                    class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"
                    active-class="bg-gray-100 text-gray-900"
                  >
                    Comments
                  </router-link>
                </div>
              </div>
            </div>
            <div class="relative group">
              <button class="inline-flex items-center px-3 py-2 text-sm font-medium text-gray-500 hover:text-gray-700 hover:bg-gray-100 rounded-md">
                Analytics
                <svg class="ml-1 h-4 w-4" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M5.293 7.293a1 1 0 011.414 0L10 10.586l3.293-3.293a1 1 0 111.414 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 010-1.414z" clip-rule="evenodd" />
                </svg>
              </button>
              <div class="absolute left-0 mt-1 w-56 rounded-md shadow-lg bg-white ring-1 ring-black ring-opacity-5 opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-all duration-200 z-10">
                <div class="py-1">
                  <router-link
                    to="/analytics/overview"
                    class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"
                    active-class="bg-gray-100 text-gray-900"
                  >
                    Overview
                  </router-link>
                  <router-link
                    to="/analytics/users"
                    class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"
                    active-class="bg-gray-100 text-gray-900"
                  >
                    User Analytics
                  </router-link>
                  <router-link
                    to="/analytics/content"
                    class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"
                    active-class="bg-gray-100 text-gray-900"
                  >
                    Content Analytics
                  </router-link>
                </div>
              </div>
            </div>
            <router-link
              to="/moderation"
              class="border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700 inline-flex items-center px-3 py-2 text-sm font-medium rounded-md"
              active-class="bg-gray-100 text-gray-900"
            >
              Moderation
            </router-link>
            <router-link
              to="/notifications"
              class="border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700 inline-flex items-center px-3 py-2 text-sm font-medium rounded-md"
              active-class="bg-gray-100 text-gray-900"
            >
              Notifications
            </router-link>
            <router-link
              to="/settings"
              class="border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700 inline-flex items-center px-3 py-2 text-sm font-medium rounded-md"
              active-class="bg-gray-100 text-gray-900"
            >
              Settings
            </router-link>
          </nav>
        </div>
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class="relative ml-3">
              <div class="flex items-center space-x-4">
                <span class="text-sm text-gray-700">{{ admin?.email }}</span>
                <button
                  @click="handleLogout"
                  class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-indigo-600 hover:bg-indigo-700"
                >
                  Logout
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </header>
</template>

<script setup>
import { useRouter } from 'vue-router';
import { useAuthStore } from '../stores/auth';

const router = useRouter();
const authStore = useAuthStore();

const admin = computed(() => authStore.admin);

const handleLogout = async () => {
  await authStore.logout();
  router.push('/login');
};
</script>
