<template>
  <div class="interests-sync-page">
    <div class="header">
      <h1>Interest Post Count Synchronization</h1>
      <p>Recalculate post counts for all interests based on actual post data</p>
    </div>

    <div class="sync-controls">
      <button 
        @click="runSync" 
        :disabled="syncing"
        class="sync-button"
      >
        <span v-if="!syncing">🔄 Recalculate All Interest Counts</span>
        <span v-else>⏳ Syncing...</span>
      </button>
    </div>

    <div v-if="syncing" class="progress-section">
      <div class="progress-bar">
        <div 
          class="progress-fill" 
          :style="{ width: progressPercent + '%' }"
        ></div>
      </div>
      <p class="progress-text">
        Processed {{ results.processed }} of {{ totalInterests }} interests...
      </p>
    </div>

    <div v-if="results.processed > 0 &&!syncing" class="results-section">
      <div class="results-summary">
        <h2>Sync Results</h2>
        <div class="summary-stats">
          <div class="stat">
            <span class="stat-label">Processed:</span>
            <span class="stat-value">{{ results.processed }}</span>
          </div>
          <div class="stat">
            <span class="stat-label">Updated:</span>
            <span class="stat-value success">{{ results.updated }}</span>
          </div>
          <div class="stat">
            <span class="stat-label">Unchanged:</span>
            <span class="stat-value">{{ results.processed - results.updated }}</span>
          </div>
          <div class="stat" v-if="results.errors.length > 0">
            <span class="stat-label">Errors:</span>
            <span class="stat-value error">{{ results.errors.length }}</span>
          </div>
        </div>
      </div>

      <div class="results-table">
        <h3>Detailed Results</h3>
        <table>
          <thead>
            <tr>
              <th>Interest</th>
              <th>Old Count</th>
              <th>New Count</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            <tr 
              v-for="detail in sortedDetails" 
              :key="detail.id"
              :class="{ updated: detail.updated }"
            >
              <td>{{ detail.name }}</td>
              <td>{{ detail.oldCount }}</td>
              <td>{{ detail.newCount }}</td>
              <td>
                <span v-if="detail.updated" class="badge success">✓ Updated</span>
                <span v-else class="badge">= Unchanged</span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div v-if="results.errors.length > 0" class="errors-section">
        <h3>Errors</h3>
        <div v-for="(error, index) in results.errors" :key="index" class="error-item">
          <strong>Interest {{ error.interestId }}:</strong> {{ error.error }}
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue';
import { recalculateInterestPostCounts } from '../composables/interestSyncService';

const syncing = ref(false);
const totalInterests = ref(0);
const results = ref({
  processed: 0,
  updated: 0,
  errors: [],
  details: []
});

const progressPercent = computed(() => {
  if (totalInterests.value === 0) return 0;
  return Math.round((results.value.processed / totalInterests.value) * 100);
});

const sortedDetails = computed(() => {
  return [...results.value.details].sort((a, b) => {
    // Show updated interests first
    if (a.updated && !b.updated) return -1;
    if (!a.updated && b.updated) return 1;
    // Then sort by name
    return a.name.localeCompare(b.name);
  });
});

async function runSync() {
  if (syncing.value) return;
  
  syncing.value = true;
  results.value = {
    processed: 0,
    updated: 0,
    errors: [],
    details: []
  };
  
  try {
    const syncResults = await recalculateInterestPostCounts();
    results.value = syncResults;
  } catch (error) {
    console.error('Sync failed:', error);
    alert(`Sync failed: ${error.message}`);
  } finally {
    syncing.value = false;
  }
}
</script>

<style scoped>
.interests-sync-page {
  max-width: 1200px;
  margin: 0 auto;
  padding: 2rem;
}

.header {
  margin-bottom: 2rem;
}

.header h1 {
  font-size: 2rem;
  margin-bottom: 0.5rem;
}

.header p {
  color: #666;
}

.sync-controls {
  margin-bottom: 2rem;
}

.sync-button {
  background: #4CAF50;
  color: white;
  border: none;
  padding: 1rem 2rem;
  font-size: 1rem;
  border-radius: 8px;
  cursor: pointer;
  transition: background 0.3s;
}

.sync-button:hover:not(:disabled) {
  background: #45a049;
}

.sync-button:disabled {
  background: #ccc;
  cursor: not-allowed;
}

.progress-section {
  margin: 2rem 0;
}

.progress-bar {
  width: 100%;
  height: 30px;
  background: #e0e0e0;
  border-radius: 15px;
  overflow: hidden;
  margin-bottom: 1rem;
}

.progress-fill {
  height: 100%;
  background: linear-gradient(90deg, #4CAF50, #8BC34A);
  transition: width 0.3s ease;
}

.progress-text {
  text-align: center;
  color: #666;
}

.results-section {
  margin-top: 2rem;
}

.results-summary {
  background: #f5f5f5;
  padding: 1.5rem;
  border-radius: 8px;
  margin-bottom: 2rem;
}

.results-summary h2 {
  margin-top: 0;
  margin-bottom: 1rem;
}

.summary-stats {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
  gap: 1rem;
}

.stat {
  display: flex;
  justify-content: space-between;
  padding: 0.5rem;
  background: white;
  border-radius: 4px;
}

.stat-label {
  font-weight: 500;
}

.stat-value {
  font-weight: bold;
  font-size: 1.2rem;
}

.stat-value.success {
  color: #4CAF50;
}

.stat-value.error {
  color: #f44336;
}

.results-table {
  margin: 2rem 0;
}

.results-table h3 {
  margin-bottom: 1rem;
}

table {
  width: 100%;
  border-collapse: collapse;
  background: white;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

th, td {
  padding: 0.75rem;
  text-align: left;
  border-bottom: 1px solid #ddd;
}

th {
  background: #f5f5f5;
  font-weight: 600;
}

tr:hover {
  background: #fafafa;
}

tr.updated {
  background: #e8f5e9;
}

tr.updated:hover {
  background: #c8e6c9;
}

.badge {
  padding: 0.25rem 0.75rem;
  border-radius: 12px;
  font-size: 0.875rem;
  font-weight: 500;
  background: #e0e0e0;
  color: #666;
}

.badge.success {
  background: #4CAF50;
  color: white;
}

.errors-section {
  margin-top: 2rem;
  padding: 1rem;
  background: #ffebee;
  border-radius: 8px;
}

.errors-section h3 {
  color: #c62828;
  margin-top: 0;
}

.error-item {
  padding: 0.5rem;
  margin: 0.5rem 0;
  background: white;
  border-left: 4px solid #f44336;
  padding-left: 1rem;
}
</style>
