<template>
  <header class="bg-background border-b">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="flex justify-between h-16">
        <div class="flex">
          <div class="flex-shrink-0 flex items-center">
            <img src="/logo-black.svg" alt="ORA Logo" class="h-8 w-auto" />
          </div>
          <nav class="hidden sm:ml-6 sm:flex sm:space-x-1">
            <router-link
              to="/"
              class="border-transparent text-muted-foreground hover:border-border hover:text-foreground inline-flex items-center px-3 pt-1 border-b-2 text-sm font-medium transition-colors"
              active-class="border-primary text-foreground"
            >
              Dashboard
            </router-link>

            <div class="relative group">
              <button class="border-transparent text-muted-foreground hover:border-border hover:text-foreground inline-flex items-center px-3 pt-1 border-b-2 text-sm font-medium group-hover:border-border group-hover:text-foreground transition-colors">
                Community
                <svg class="ml-1 h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 14l-7 7m0 0l-7-7m7 7V3" />
                </svg>
              </button>
              <div class="absolute left-0 mt-0 w-48 bg-popover shadow-lg rounded-md py-2 opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-all duration-200 z-50 border">
                <router-link to="/users" class="block px-4 py-2 text-sm text-popover-foreground hover:bg-accent hover:text-accent-foreground">Users</router-link>
                <router-link to="/announcements" class="block px-4 py-2 text-sm text-popover-foreground hover:bg-accent hover:text-accent-foreground">Announcements</router-link>
                <router-link to="/notifications" class="block px-4 py-2 text-sm text-popover-foreground hover:bg-accent hover:text-accent-foreground">Notifications</router-link>
              </div>
            </div>

            <div class="relative group">
              <button class="border-transparent text-muted-foreground hover:border-border hover:text-foreground inline-flex items-center px-3 pt-1 border-b-2 text-sm font-medium group-hover:border-border group-hover:text-foreground transition-colors">
                Content
                <svg class="ml-1 h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 14l-7 7m0 0l-7-7m7 7V3" />
                </svg>
              </button>
              <div class="absolute left-0 mt-0 w-48 bg-popover shadow-lg rounded-md py-2 opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-all duration-200 z-50 border">
                <router-link to="/moderation" class="block px-4 py-2 text-sm text-popover-foreground hover:bg-accent hover:text-accent-foreground">Moderation</router-link>
                <router-link to="/content" class="block px-4 py-2 text-sm text-popover-foreground hover:bg-accent hover:text-accent-foreground">Manage Content</router-link>
                <router-link to="/interests" class="block px-4 py-2 text-sm text-popover-foreground hover:bg-accent hover:text-accent-foreground">Interests</router-link>
                <router-link to="/posts-migration" class="block px-4 py-2 text-sm text-popover-foreground hover:bg-accent hover:text-accent-foreground">Migrate Posts (Legacy)</router-link>
                <router-link to="/posts-migration-v2" class="block px-4 py-2 text-sm text-popover-foreground hover:bg-accent hover:text-accent-foreground">Migrate Posts (Enhanced)</router-link>
              </div>
            </div>

            <router-link
              to="/analytics"
              class="border-transparent text-muted-foreground hover:border-border hover:text-foreground inline-flex items-center px-3 pt-1 border-b-2 text-sm font-medium transition-colors"
              active-class="border-primary text-foreground"
            >
              Analytics
            </router-link>

            <router-link
              to="/settings"
              class="border-transparent text-muted-foreground hover:border-border hover:text-foreground inline-flex items-center px-3 pt-1 border-b-2 text-sm font-medium transition-colors"
              active-class="border-primary text-foreground"
            >
              Settings
            </router-link>
          </nav>
        </div>
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class="relative ml-3">
              <div class="flex items-center space-x-4">
                <span class="text-sm text-foreground">{{ admin?.email }}</span>
                <Button
                  @click="handleLogout"
                  variant="default"
                >
                  Logout
                </Button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </header>
</template>

<script setup>
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '../stores/auth';
import Button from '@/components/ui/Button.vue';

const router = useRouter();
const authStore = useAuthStore();

const admin = computed(() => authStore.admin);

const handleLogout = async () => {
  await authStore.logout();
  router.push('/login');
};
</script>

