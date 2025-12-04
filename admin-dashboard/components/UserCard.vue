<template>
  <Card class="hover:shadow-md transition-shadow">
    <CardContent class="p-6">
      <div class="flex items-center justify-between">
        <div class="flex items-center space-x-4 flex-1">
          <img
            v-if="user.photoURL"
            :src="user.photoURL"
            :alt="user.displayName || user.email"
            class="h-12 w-12 rounded-full"
          />
          <div v-else class="h-12 w-12 rounded-full bg-muted flex items-center justify-center">
            <span class="text-muted-foreground font-medium">{{ (user.displayName || user.email || 'U')[0].toUpperCase() }}</span>
          </div>
          <div class="flex-1">
            <h3 class="text-lg font-medium text-foreground">
              {{ user.displayName || user.email || 'Unknown User' }}
            </h3>
            <p class="text-sm text-muted-foreground">{{ user.email }}</p>
            <p v-if="user.username" class="text-xs text-muted-foreground">@{{ user.username }}</p>
            <div class="flex items-center space-x-4 mt-2 text-xs text-muted-foreground">
              <span>Joined: {{ formatDate(user.createdAt) }}</span>
              <span v-if="user.stats?.lastActivityAt">Last active: {{ formatDate(user.stats.lastActivityAt) }}</span>
              <span v-else class="text-muted-foreground">Never active</span>
            </div>
          </div>
        </div>
        <div class="flex items-center space-x-2">
          <span
            v-if="user.isBanned"
            class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-destructive/10 text-destructive"
          >
            Banned
          </span>
          <span
            v-if="user.isAdmin"
            class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-primary/10 text-primary"
          >
            Admin
          </span>
        </div>
      </div>
      
      <!-- Stats Row -->
      <div class="mt-4 grid grid-cols-4 gap-4 pt-4 border-t">
        <div class="text-center">
          <div class="text-lg font-semibold text-foreground">{{ user.stats?.postCount || 0 }}</div>
          <div class="text-xs text-muted-foreground">Posts</div>
        </div>
        <div class="text-center">
          <div class="text-lg font-semibold text-foreground">{{ user.stats?.followerCount || 0 }}</div>
          <div class="text-xs text-muted-foreground">Followers</div>
        </div>
        <div class="text-center">
          <div class="text-lg font-semibold text-foreground">{{ user.stats?.followingCount || 0 }}</div>
          <div class="text-xs text-muted-foreground">Following</div>
        </div>
        <div class="text-center">
          <div class="text-lg font-semibold text-foreground">{{ user.stats?.totalEngagements || 0 }}</div>
          <div class="text-xs text-muted-foreground">Engagements</div>
        </div>
      </div>

      <!-- Actions -->
      <div class="mt-4 flex items-center justify-end space-x-2">
        <Button
          @click="$emit('view', user.id)"
          variant="ghost"
          size="sm"
        >
          View Details
        </Button>
        <Button
          @click="$emit('ban', user.id)"
          :disabled="user.isBanned"
          variant="ghost"
          size="sm"
          class="text-destructive hover:text-destructive"
        >
          {{ user.isBanned ? 'Banned' : 'Ban' }}
        </Button>
        <Button
          @click="$emit('unban', user.id)"
          :disabled="!user.isBanned"
          variant="ghost"
          size="sm"
          class="text-green-600 hover:text-green-700"
        >
          Unban
        </Button>
        <Button
          @click="$emit('delete', user.id)"
          variant="destructive"
          size="sm"
        >
          Delete
        </Button>
      </div>
    </CardContent>
  </Card>
</template>

<script setup>
import Card from '@/components/ui/Card.vue';
import CardContent from '@/components/ui/CardContent.vue';
import Button from '@/components/ui/Button.vue';

defineProps({
  user: {
    type: Object,
    required: true
  }
});

defineEmits(['ban', 'unban', 'delete', 'view']);

const formatDate = (timestamp) => {
  if (!timestamp) return 'Unknown';
  const date = new Date(timestamp);
  return date.toLocaleDateString();
};
</script>

