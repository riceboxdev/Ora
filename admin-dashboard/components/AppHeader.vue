<template>
  <header class="border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
      <div class="flex h-16 items-center justify-between">
        <div class="flex items-center space-x-4">
          <img src="/logo-black.svg" alt="ORA Logo" class="h-8 w-auto" />
          <Menubar class="hidden md:flex border-none bg-transparent">
            <MenubarMenu>
              <router-link
                to="/"
                class="inline-flex h-9 items-center justify-center rounded-md px-3 py-1 text-sm font-medium transition-colors hover:text-foreground/80 focus:outline-none focus:bg-accent focus:text-accent-foreground"
                active-class="text-foreground"
                exact-active-class="text-foreground"
              >
                Dashboard
              </router-link>
            </MenubarMenu>

            <MenubarMenu>
              <MenubarTrigger class="flex items-center gap-1">
                Community
                <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                </svg>
              </MenubarTrigger>
              <MenubarContent>
                <MenubarItem as-child>
                  <router-link to="/users" class="w-full">
                    <div class="flex flex-col">
                      <span>Users</span>
                      <span class="text-xs text-muted-foreground">Manage user accounts and permissions</span>
                    </div>
                  </router-link>
                </MenubarItem>
                <MenubarItem as-child>
                  <router-link to="/announcements" class="w-full">
                    <div class="flex flex-col">
                      <span>Announcements</span>
                      <span class="text-xs text-muted-foreground">Create and manage announcements</span>
                    </div>
                  </router-link>
                </MenubarItem>
                <MenubarItem as-child>
                  <router-link to="/notifications" class="w-full">
                    <div class="flex flex-col">
                      <span>Notifications</span>
                      <span class="text-xs text-muted-foreground">Send notifications to users</span>
                    </div>
                  </router-link>
                </MenubarItem>
              </MenubarContent>
            </MenubarMenu>

            <MenubarMenu>
              <MenubarTrigger class="flex items-center gap-1">
                Content
                <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                </svg>
              </MenubarTrigger>
              <MenubarContent>
                <MenubarItem as-child>
                  <router-link to="/moderation" class="w-full">
                    <div class="flex flex-col">
                      <span>Moderation</span>
                      <span class="text-xs text-muted-foreground">Review and moderate content</span>
                    </div>
                  </router-link>
                </MenubarItem>
                <MenubarItem as-child>
                  <router-link to="/content" class="w-full">
                    <div class="flex flex-col">
                      <span>Manage Content</span>
                      <span class="text-xs text-muted-foreground">Organize and manage content</span>
                    </div>
                  </router-link>
                </MenubarItem>
                <MenubarItem as-child>
                  <router-link to="/interests" class="w-full">
                    <div class="flex flex-col">
                      <span>Interests</span>
                      <span class="text-xs text-muted-foreground">Manage user interests and tags</span>
                    </div>
                  </router-link>
                </MenubarItem>
                <MenubarItem as-child>
                  <router-link to="/posts-migration" class="w-full">
                    <div class="flex flex-col">
                      <span>Migrate Posts (Legacy)</span>
                      <span class="text-xs text-muted-foreground">Legacy post migration tool</span>
                    </div>
                  </router-link>
                </MenubarItem>
                <MenubarItem as-child>
                  <router-link to="/posts-migration-v2" class="w-full">
                    <div class="flex flex-col">
                      <span>Migrate Posts (Enhanced)</span>
                      <span class="text-xs text-muted-foreground">Enhanced post migration tool</span>
                    </div>
                  </router-link>
                </MenubarItem>
              </MenubarContent>
            </MenubarMenu>

            <MenubarMenu>
              <router-link
                to="/analytics"
                class="inline-flex h-9 items-center justify-center rounded-md px-3 py-1 text-sm font-medium transition-colors hover:text-foreground/80 focus:outline-none focus:bg-accent focus:text-accent-foreground"
                active-class="text-foreground"
                exact-active-class="text-foreground"
              >
                Analytics
              </router-link>
            </MenubarMenu>

            <MenubarMenu>
              <router-link
                to="/settings"
                class="inline-flex h-9 items-center justify-center rounded-md px-3 py-1 text-sm font-medium transition-colors hover:text-foreground/80 focus:outline-none focus:bg-accent focus:text-accent-foreground"
                active-class="text-foreground"
                exact-active-class="text-foreground"
              >
                Settings
              </router-link>
            </MenubarMenu>

            <MenubarMenu>
              <router-link
                to="/theme-customizer"
                class="inline-flex h-9 items-center justify-center rounded-md px-3 py-1 text-sm font-medium transition-colors hover:text-foreground/80 focus:outline-none focus:bg-accent focus:text-accent-foreground"
                active-class="text-foreground"
                exact-active-class="text-foreground"
              >
                <svg class="w-4 h-4 mr-1.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 21a4 4 0 01-4-4V5a2 2 0 012-2h4a2 2 0 012 2v12a4 4 0 01-4 4zm0 0h12a2 2 0 002-2v-4a2 2 0 00-2-2h-2.343M11 7.343l1.657-1.657a2 2 0 012.828 0l2.829 2.829a2 2 0 010 2.828l-8.486 8.485M7 17h.01" />
                </svg>
                Theme
              </router-link>
            </MenubarMenu>
          </Menubar>
        </div>

        <div class="flex items-center space-x-4">
          <div class="hidden md:flex items-center space-x-2">
            <span class="text-sm text-muted-foreground">{{ admin?.email }}</span>
          </div>
          <Button @click="handleLogout" variant="default" size="sm">
            Logout
          </Button>
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
import Menubar from '@/components/ui/Menubar.vue';
import MenubarMenu from '@/components/ui/MenubarMenu.vue';
import MenubarTrigger from '@/components/ui/MenubarTrigger.vue';
import MenubarContent from '@/components/ui/MenubarContent.vue';
import MenubarItem from '@/components/ui/MenubarItem.vue';

const router = useRouter();
const authStore = useAuthStore();

const admin = computed(() => authStore.admin);

const handleLogout = async () => {
  await authStore.logout();
  router.push('/login');
};
</script>
