import api from './api';

/**
 * Enhanced Migration API Service
 * Provides methods for interacting with the new migration system
 */
class MigrationAPI {
  /**
   * Analyze existing tags and get mapping suggestions
   */
  async analyzeTags(options = {}) {
    const params = new URLSearchParams();
    if (options.limit) params.append('limit', options.limit);
    if (options.excludeExisting !== undefined) params.append('excludeExisting', options.excludeExisting);
    
    const response = await api.get(`/api/migrations/analyze-tags?${params.toString()}`);
    return response.data;
  }

  /**
   * Validate migration configuration
   */
  async validateConfiguration(config) {
    const response = await api.post('/api/migrations/validate', config);
    return response.data;
  }

  /**
   * Create a new migration job
   */
  async createMigration(config) {
    const response = await api.post('/api/migrations/create', config);
    return response.data;
  }

  /**
   * Start a migration job
   */
  async startMigration(migrationId) {
    const response = await api.post(`/api/migrations/${migrationId}/start`);
    return response.data;
  }

  /**
   * Pause a running migration
   */
  async pauseMigration(migrationId) {
    const response = await api.post(`/api/migrations/${migrationId}/pause`);
    return response.data;
  }

  /**
   * Stop a migration
   */
  async stopMigration(migrationId) {
    const response = await api.post(`/api/migrations/${migrationId}/stop`);
    return response.data;
  }

  /**
   * Get migration status and progress
   */
  async getMigrationStatus(migrationId) {
    const response = await api.get(`/api/migrations/${migrationId}/status`);
    return response.data;
  }

  /**
   * List all migrations with optional filtering
   */
  async listMigrations(options = {}) {
    const params = new URLSearchParams();
    if (options.limit) params.append('limit', options.limit);
    if (options.status) params.append('status', options.status);
    if (options.userId) params.append('userId', options.userId);
    
    const response = await api.get(`/api/migrations?${params.toString()}`);
    return response.data;
  }

  /**
   * Rollback a completed migration
   */
  async rollbackMigration(migrationId) {
    const response = await api.post(`/api/migrations/${migrationId}/rollback`);
    return response.data;
  }

  /**
   * Run a dry-run migration (create and start with dryRun=true)
   */
  async runDryRun(config) {
    const response = await api.post('/api/migrations/dry-run', config);
    return response.data;
  }

  /**
   * Get overall migration statistics
   */
  async getStats() {
    const response = await api.get('/api/migrations/stats');
    return response.data;
  }

  /**
   * Clean up old migration records (super admin only)
   */
  async cleanup(daysOld = 30) {
    const params = new URLSearchParams();
    params.append('daysOld', daysOld);
    
    const response = await api.delete(`/api/migrations/cleanup?${params.toString()}`);
    return response.data;
  }

  /**
   * Create and immediately start a migration
   */
  async createAndStartMigration(config) {
    const createResult = await this.createMigration(config);
    if (createResult.success) {
      const startResult = await this.startMigration(createResult.migrationId);
      return {
        success: startResult.success,
        migrationId: createResult.migrationId,
        validation: createResult.validation,
        startStatus: startResult.status
      };
    }
    return createResult;
  }

  /**
   * Wait for migration completion (polling)
   */
  async waitForCompletion(migrationId, options = {}) {
    const { 
      pollInterval = 2000, 
      timeout = 300000, // 5 minutes default
      onProgress = null 
    } = options;

    const startTime = Date.now();
    
    return new Promise((resolve, reject) => {
      const poll = async () => {
        try {
          const result = await this.getMigrationStatus(migrationId);
          
          if (result.success) {
            const migration = result.migration;
            
            // Call progress callback if provided
            if (onProgress && typeof onProgress === 'function') {
              onProgress(migration);
            }
            
            // Check if migration is complete
            if (['completed', 'failed', 'stopped', 'rolled_back'].includes(migration.status)) {
              resolve(migration);
              return;
            }
            
            // Check timeout
            if (Date.now() - startTime > timeout) {
              reject(new Error('Migration polling timeout'));
              return;
            }
            
            // Continue polling
            setTimeout(poll, pollInterval);
          } else {
            reject(new Error(result.message || 'Failed to get migration status'));
          }
        } catch (error) {
          reject(error);
        }
      };
      
      // Start polling
      poll();
    });
  }

  /**
   * Get migration progress as a percentage
   */
  getProgressPercentage(migration) {
    if (!migration || !migration.progress) return 0;
    
    const { total, processed } = migration.progress;
    if (!total || total === 0) return 0;
    
    return Math.round((processed / total) * 100);
  }

  /**
   * Check if migration is active (running or paused)
   */
  isMigrationActive(migration) {
    if (!migration) return false;
    return ['running', 'paused'].includes(migration.status);
  }

  /**
   * Check if migration can be started
   */
  canStartMigration(migration) {
    if (!migration) return false;
    return ['created', 'paused'].includes(migration.status);
  }

  /**
   * Check if migration can be paused
   */
  canPauseMigration(migration) {
    if (!migration) return false;
    return migration.status === 'running';
  }

  /**
   * Check if migration can be stopped
   */
  canStopMigration(migration) {
    if (!migration) return false;
    return ['running', 'paused'].includes(migration.status);
  }

  /**
   * Check if migration can be rolled back
   */
  canRollbackMigration(migration) {
    if (!migration) return false;
    return migration.status === 'completed' && !migration.config?.dryRun;
  }

  /**
   * Format migration status for display
   */
  formatStatus(status) {
    if (!status) return 'Unknown';
    
    const statusMap = {
      'created': 'Created',
      'running': 'Running',
      'paused': 'Paused',
      'completed': 'Completed',
      'failed': 'Failed',
      'stopped': 'Stopped',
      'rolled_back': 'Rolled Back'
    };
    
    return statusMap[status] || status.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase());
  }

  /**
   * Get status color class for badges
   */
  getStatusColor(status) {
    const colorMap = {
      'created': 'gray',
      'running': 'blue',
      'paused': 'yellow',
      'completed': 'green',
      'failed': 'red',
      'stopped': 'gray',
      'rolled_back': 'purple'
    };
    
    return colorMap[status] || 'gray';
  }

  /**
   * Estimate remaining time for migration
   */
  estimateRemainingTime(migration) {
    if (!migration || !this.isMigrationActive(migration)) return null;
    
    const { progress, metadata } = migration;
    if (!progress || !metadata?.startedAt) return null;
    
    const { total, processed } = progress;
    if (!total || processed === 0) return null;
    
    const startTime = metadata.startedAt.toDate ? metadata.startedAt.toDate() : new Date(metadata.startedAt);
    const elapsedMs = Date.now() - startTime.getTime();
    const rate = processed / elapsedMs; // posts per ms
    const remaining = total - processed;
    
    if (rate <= 0) return null;
    
    const remainingMs = remaining / rate;
    return Math.round(remainingMs / 1000); // return seconds
  }

  /**
   * Format time duration in human readable format
   */
  formatDuration(seconds) {
    if (!seconds || seconds < 0) return 'Unknown';
    
    if (seconds < 60) return `${seconds}s`;
    if (seconds < 3600) return `${Math.floor(seconds / 60)}m ${seconds % 60}s`;
    
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    return `${hours}h ${minutes}m`;
  }
}

// Export singleton instance
export default new MigrationAPI();