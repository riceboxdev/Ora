<template>
  <div class="min-h-screen bg-background">
    <AppHeader />
    
    <main class="container mx-auto py-6">
      <div class="space-y-6">
        <div class="flex items-center justify-between">
          <h1 class="text-3xl font-bold tracking-tight">Dashboard Overview</h1>
        </div>
        
        <div v-if="loading" class="flex items-center justify-center py-12">
          <div class="text-muted-foreground">Loading dashboard...</div>
        </div>
        
        <div v-else class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-4">
          <Card>
            <CardContent class="p-6">
              <div class="flex items-center">
                <div class="p-2 bg-primary/10 rounded-md">
                  <svg class="h-6 w-6 text-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
                  </svg>
                </div>
                <div class="ml-4">
                  <h3 class="text-2xl font-bold">{{ analytics?.users?.total || 0 }}</h3>
                  <p class="text-sm text-muted-foreground">Total Users</p>
                </div>
              </div>
            </CardContent>
          </Card>
          
          <Card>
            <CardContent class="p-6">
              <div class="flex items-center">
                <div class="p-2 bg-primary/10 rounded-md">
                  <svg class="h-6 w-6 text-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
                  </svg>
                </div>
                <div class="ml-4">
                  <h3 class="text-2xl font-bold">{{ analytics?.posts?.total || 0 }}</h3>
                  <p class="text-sm text-muted-foreground">Total Posts</p>
                </div>
              </div>
            </CardContent>
          </Card>
          
          <Card>
            <CardContent class="p-6">
              <div class="flex items-center">
                <div class="p-2 bg-destructive/10 rounded-md">
                  <svg class="h-6 w-6 text-destructive" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                  </svg>
                </div>
                <div class="ml-4">
                  <h3 class="text-2xl font-bold">{{ analytics?.posts?.pending || 0 }}</h3>
                  <p class="text-sm text-muted-foreground">Pending Moderation</p>
                </div>
              </div>
            </CardContent>
          </Card>
          
          <Card>
            <CardContent class="p-6">
              <div class="flex items-center">
                <div class="p-2 bg-primary/10 rounded-md">
                  <svg class="h-6 w-6 text-primary" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
                  </svg>
                </div>
                <div class="ml-4">
                  <h3 class="text-2xl font-bold">{{ analytics?.engagement?.likes || 0 }}</h3>
                  <p class="text-sm text-muted-foreground">Total Likes</p>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>
        
        <Card>
          <CardHeader>
            <CardTitle>Quick Actions</CardTitle>
          </CardHeader>
          <CardContent>
            <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
              <router-link
                to="/moderation"
                class="block p-4 border rounded-lg hover:border-primary hover:bg-accent transition-colors"
              >
                <h4 class="font-semibold text-card-foreground">Review Moderation Queue</h4>
                <p class="text-sm text-muted-foreground mt-1">{{ analytics?.posts?.pending || 0 }} posts pending</p>
              </router-link>
              <router-link
                to="/users"
                class="block p-4 border rounded-lg hover:border-primary hover:bg-accent transition-colors"
              >
                <h4 class="font-semibold text-card-foreground">Manage Users</h4>
                <p class="text-sm text-muted-foreground mt-1">{{ analytics?.users?.total || 0 }} total users</p>
              </router-link>
              <router-link
                to="/analytics"
                class="block p-4 border rounded-lg hover:border-primary hover:bg-accent transition-colors"
              >
                <h4 class="font-semibold text-card-foreground">View Analytics</h4>
                <p class="text-sm text-muted-foreground mt-1">Detailed insights</p>
              </router-link>
            </div>
          </CardContent>
        </Card>
      </div>
    </main>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import api from '@/services/api';
import AppHeader from '../components/AppHeader.vue';
import Card from '@/components/ui/Card.vue';
import CardContent from '@/components/ui/CardContent.vue';
import CardHeader from '@/components/ui/CardHeader.vue';
import CardTitle from '@/components/ui/CardTitle.vue';

const analytics = ref(null);
const loading = ref(true);
const stats = ref(null);

async function fetchDashboardData() {
  loading.value = true;
  try {
    const response = await api.get('/api/admin/analytics');
    const data = response.data;
    stats.value = data;
    analytics.value = data;
  } catch (err) {
    console.error('Error fetching dashboard data:', err);
  } finally {
    loading.value = false;
  }
};

onMounted(() => {
  fetchDashboardData();
});
</script>
