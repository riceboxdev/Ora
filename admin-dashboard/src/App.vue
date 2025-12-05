<template>
  <router-view />
</template>

<script setup>
import { onMounted } from 'vue';
import { useTheme } from '../composables/useTheme.js';

const { loadAndApplyTheme } = useTheme();

// Load and apply saved theme on app mount
onMounted(async () => {
  await loadAndApplyTheme();
});
</script>
