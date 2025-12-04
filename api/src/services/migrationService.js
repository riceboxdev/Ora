import admin from 'firebase-admin';

class MigrationService {
  constructor() {
    this.activeMigrations = new Map();
  }

  get db() {
    return admin.firestore();
  }

  /**
   * Analyze existing tags to suggest mappings
   */
  async analyzeTagsForMappings(options = {}) {
    const { limit = 1000, excludeExisting = true } = options;
    
    try {
      const tagAnalysis = new Map();
      let query = this.db.collection('posts');
      
      if (limit) {
        query = query.limit(limit);
      }
      
      const postsSnapshot = await query.get();
      
      // Collect all tags and their frequencies
      postsSnapshot.forEach(doc => {
        const data = doc.data();
        const tags = [...(data.tags || []), ...(data.categories || [])];
        
        // Skip posts that already have interests if excludeExisting is true
        if (excludeExisting && data.interests && data.interests.length > 0) {
          return;
        }
        
        tags.forEach(tag => {
          const tagLower = tag.toLowerCase().trim();
          if (tagLower && tagLower.length > 1) {
            const current = tagAnalysis.get(tagLower) || { count: 0, examples: new Set() };
            current.count++;
            current.examples.add(tag);
            tagAnalysis.set(tagLower, current);
          }
        });
      });

      // Convert to sorted array with suggested mappings
      const suggestions = Array.from(tagAnalysis.entries())
        .map(([tag, data]) => ({
          tag,
          count: data.count,
          examples: Array.from(data.examples).slice(0, 3),
          suggestedInterest: this._suggestInterestForTag(tag),
          confidence: this._calculateMappingConfidence(tag, data.count)
        }))
        .sort((a, b) => b.count - a.count);

      return {
        totalTags: tagAnalysis.size,
        suggestions,
        analysisMetadata: {
          postsAnalyzed: postsSnapshot.size,
          timestamp: Date.now(),
          excludeExisting
        }
      };
    } catch (error) {
      throw new Error(`Tag analysis failed: ${error.message}`);
    }
  }

  /**
   * Suggest an interest category for a tag using keyword matching
   */
  _suggestInterestForTag(tag) {
    const interestMappings = {
      fashion: ['fashion', 'style', 'clothing', 'outfit', 'dress', 'shoes', 'accessories', 'model', 'runway'],
      beauty: ['beauty', 'makeup', 'skincare', 'cosmetics', 'hair', 'nails', 'spa', 'wellness'],
      food: ['food', 'recipe', 'cooking', 'baking', 'cuisine', 'restaurant', 'meal', 'dessert', 'drink', 'wine', 'coffee'],
      fitness: ['fitness', 'workout', 'exercise', 'gym', 'health', 'sport', 'running', 'yoga', 'training', 'muscle'],
      home: ['home', 'interior', 'design', 'decor', 'furniture', 'architecture', 'house', 'apartment', 'room', 'garden'],
      travel: ['travel', 'vacation', 'trip', 'destination', 'landscape', 'city', 'beach', 'mountain', 'adventure', 'explore'],
      photography: ['photography', 'photo', 'camera', 'portrait', 'nature', 'abstract', 'art', 'vintage', 'black', 'white'],
      entertainment: ['entertainment', 'movie', 'music', 'concert', 'show', 'celebrity', 'art', 'culture', 'festival'],
      technology: ['technology', 'tech', 'gadget', 'phone', 'computer', 'software', 'digital', 'innovation'],
      pets: ['pet', 'dog', 'cat', 'animal', 'puppy', 'kitten', 'bird', 'fish', 'wildlife']
    };

    const tagLower = tag.toLowerCase();
    
    for (const [interest, keywords] of Object.entries(interestMappings)) {
      if (keywords.some(keyword => 
        tagLower.includes(keyword) || keyword.includes(tagLower)
      )) {
        return interest;
      }
    }
    
    // Default fallback
    return 'photography';
  }

  /**
   * Calculate confidence score for mapping suggestion
   */
  _calculateMappingConfidence(tag, count) {
    const tagLower = tag.toLowerCase();
    let confidence = 0.3; // Base confidence
    
    // Higher confidence for common tags
    if (count >= 100) confidence += 0.4;
    else if (count >= 50) confidence += 0.3;
    else if (count >= 10) confidence += 0.2;
    else confidence += 0.1;
    
    // Higher confidence for exact keyword matches
    const exactMatches = ['fashion', 'food', 'travel', 'fitness', 'beauty', 'home', 'photography', 'pets', 'technology'];
    if (exactMatches.includes(tagLower)) {
      confidence += 0.3;
    }
    
    return Math.min(confidence, 1.0);
  }

  /**
   * Validate migration configuration
   */
  async validateMigration(config) {
    const errors = [];
    const warnings = [];
    
    // Validate tag mappings
    if (!config.tagMappings || typeof config.tagMappings !== 'object') {
      errors.push('tagMappings is required and must be an object');
      return { valid: false, errors, warnings };
    }

    const validInterests = ['fashion', 'beauty', 'food', 'fitness', 'home', 'travel', 'photography', 'entertainment', 'technology', 'pets'];
    
    for (const [tag, interest] of Object.entries(config.tagMappings)) {
      if (!validInterests.includes(interest)) {
        errors.push(`Invalid interest "${interest}" for tag "${tag}". Valid interests: ${validInterests.join(', ')}`);
      }
    }

    // Validate batch size
    if (config.batchSize && (config.batchSize < 10 || config.batchSize > 500)) {
      warnings.push('Batch size should be between 10 and 500 for optimal performance');
    }

    // Check for common tags without mappings
    try {
      const analysis = await this.analyzeTagsForMappings({ limit: 500 });
      const commonUnmappedTags = analysis.suggestions
        .filter(s => s.count >= 10 && !config.tagMappings[s.tag])
        .slice(0, 5);
      
      if (commonUnmappedTags.length > 0) {
        warnings.push(`Common tags without mappings: ${commonUnmappedTags.map(t => t.tag).join(', ')}`);
      }
    } catch (error) {
      warnings.push('Could not analyze existing tags for validation');
    }

    return {
      valid: errors.length === 0,
      errors,
      warnings
    };
  }

  /**
   * Create a new migration job
   */
  async createMigrationJob(config, userId) {
    const migrationId = `migration_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    
    // Validate configuration
    const validation = await this.validateMigration(config);
    if (!validation.valid) {
      throw new Error(`Invalid migration config: ${validation.errors.join(', ')}`);
    }

    const migrationDoc = {
      id: migrationId,
      status: 'created',
      config: {
        tagMappings: config.tagMappings,
        batchSize: config.batchSize || 100,
        limit: config.limit || null,
        updateAll: config.updateAll || false,
        dryRun: config.dryRun || false
      },
      progress: {
        total: 0,
        processed: 0,
        migrated: 0,
        skipped: 0,
        failed: 0,
        percentage: 0
      },
      metadata: {
        createdBy: userId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        startedAt: null,
        completedAt: null,
        lastBatch: null
      },
      errors: [],
      validation: validation
    };

    // Save migration job to Firestore
    await this.db.collection('migrations').doc(migrationId).set(migrationDoc);
    
    return { migrationId, validation };
  }

  /**
   * Start a migration job
   */
  async startMigration(migrationId) {
    const migrationRef = this.db.collection('migrations').doc(migrationId);
    const migrationDoc = await migrationRef.get();
    
    if (!migrationDoc.exists) {
      throw new Error('Migration not found');
    }
    
    const migration = migrationDoc.data();
    
    if (migration.status !== 'created' && migration.status !== 'paused') {
      throw new Error(`Cannot start migration with status: ${migration.status}`);
    }

    // Mark as started
    await migrationRef.update({
      status: 'running',
      'metadata.startedAt': admin.firestore.FieldValue.serverTimestamp()
    });

    // Store active migration
    this.activeMigrations.set(migrationId, {
      shouldStop: false,
      pauseRequested: false
    });

    // Start processing in background
    this._processMigrationQueue(migrationId).catch(error => {
      console.error(`Migration ${migrationId} failed:`, error);
      migrationRef.update({
        status: 'failed',
        'metadata.completedAt': admin.firestore.FieldValue.serverTimestamp(),
        errors: admin.firestore.FieldValue.arrayUnion({
          message: error.message,
          timestamp: Date.now(),
          type: 'system_error'
        })
      });
    });

    return { status: 'started', migrationId };
  }

  /**
   * Process migration queue
   */
  async _processMigrationQueue(migrationId) {
    const migrationRef = this.db.collection('migrations').doc(migrationId);
    let migration = (await migrationRef.get()).data();
    const config = migration.config;
    
    try {
      // Get total count first
      let query = this.db.collection('posts');
      if (config.limit && config.limit > 0) {
        query = query.limit(config.limit);
      }
      
      const totalSnapshot = await query.get();
      let posts = [];
      
      // Filter posts that need migration
      totalSnapshot.forEach(doc => {
        const data = doc.data();
        const needsMigration = config.updateAll || 
          !data.interests || 
          !Array.isArray(data.interests) || 
          data.interests.length === 0;
          
        if (needsMigration) {
          posts.push({ id: doc.id, ...data });
        }
      });

      await migrationRef.update({
        'progress.total': posts.length
      });

      // Process in batches
      const batchSize = config.batchSize;
      for (let i = 0; i < posts.length; i += batchSize) {
        // Check if migration should stop
        const activeStatus = this.activeMigrations.get(migrationId);
        if (activeStatus?.shouldStop) {
          await migrationRef.update({ status: 'stopped' });
          break;
        }
        if (activeStatus?.pauseRequested) {
          await migrationRef.update({ status: 'paused' });
          break;
        }

        const batch = posts.slice(i, i + batchSize);
        await this._processBatch(migrationId, batch, config);
        
        // Update progress
        await migrationRef.update({
          'progress.processed': i + batch.length,
          'progress.percentage': Math.round(((i + batch.length) / posts.length) * 100),
          'metadata.lastBatch': admin.firestore.FieldValue.serverTimestamp()
        });

        // Small delay to prevent overwhelming Firestore
        await new Promise(resolve => setTimeout(resolve, 100));
      }

      // Mark as completed if not stopped
      migration = (await migrationRef.get()).data();
      if (migration.status === 'running') {
        await migrationRef.update({
          status: 'completed',
          'metadata.completedAt': admin.firestore.FieldValue.serverTimestamp()
        });
      }

    } finally {
      this.activeMigrations.delete(migrationId);
    }
  }

  /**
   * Process a batch of posts
   */
  async _processBatch(migrationId, posts, config) {
    const migrationRef = this.db.collection('migrations').doc(migrationId);
    const batch = this.db.batch();
    let migrated = 0;
    let skipped = 0;
    let failed = 0;

    for (const post of posts) {
      try {
        // Get tags and categories
        const originalTags = post.tags || [];
        const originalCategories = post.categories || [];
        const allTags = [...originalTags, ...originalCategories];
        
        // Find mapped interests
        const mappedInterests = [];
        for (const tag of allTags) {
          const tagLower = tag.toLowerCase().trim();
          if (config.tagMappings[tagLower]) {
            const interest = config.tagMappings[tagLower];
            if (!mappedInterests.includes(interest)) {
              mappedInterests.push(interest);
            }
          }
        }
        
        // Skip if no mapped interests found
        if (mappedInterests.length === 0) {
          skipped++;
          continue;
        }

        // Skip if dry run
        if (config.dryRun) {
          migrated++;
          continue;
        }

        // Add to batch update
        const postRef = this.db.collection('posts').doc(post.id);
        batch.update(postRef, {
          interests: mappedInterests,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          migratedAt: admin.firestore.FieldValue.serverTimestamp(),
          migrationId: migrationId
        });
        
        migrated++;
        
      } catch (error) {
        failed++;
        await migrationRef.update({
          errors: admin.firestore.FieldValue.arrayUnion({
            postId: post.id,
            message: error.message,
            timestamp: Date.now(),
            type: 'processing_error'
          })
        });
      }
    }

    // Commit batch if not dry run
    if (!config.dryRun && migrated > 0) {
      await batch.commit();
    }

    // Update progress counters
    await migrationRef.update({
      'progress.migrated': admin.firestore.FieldValue.increment(migrated),
      'progress.skipped': admin.firestore.FieldValue.increment(skipped),
      'progress.failed': admin.firestore.FieldValue.increment(failed)
    });
  }

  /**
   * Pause a migration
   */
  async pauseMigration(migrationId) {
    const activeStatus = this.activeMigrations.get(migrationId);
    if (activeStatus) {
      activeStatus.pauseRequested = true;
    }
    
    return { status: 'pause_requested' };
  }

  /**
   * Stop a migration
   */
  async stopMigration(migrationId) {
    const activeStatus = this.activeMigrations.get(migrationId);
    if (activeStatus) {
      activeStatus.shouldStop = true;
    }
    
    await this.db.collection('migrations').doc(migrationId).update({
      status: 'stopped',
      'metadata.completedAt': admin.firestore.FieldValue.serverTimestamp()
    });
    
    return { status: 'stopped' };
  }

  /**
   * Get migration status
   */
  async getMigrationStatus(migrationId) {
    const migrationDoc = await this.db.collection('migrations').doc(migrationId).get();
    
    if (!migrationDoc.exists) {
      throw new Error('Migration not found');
    }
    
    return migrationDoc.data();
  }

  /**
   * List all migrations
   */
  async listMigrations(options = {}) {
    const { limit = 20, status = null, userId = null } = options;
    
    let query = this.db.collection('migrations')
      .orderBy('metadata.createdAt', 'desc');
    
    if (status) {
      query = query.where('status', '==', status);
    }
    
    if (userId) {
      query = query.where('metadata.createdBy', '==', userId);
    }
    
    if (limit) {
      query = query.limit(limit);
    }
    
    const snapshot = await query.get();
    const migrations = [];
    
    snapshot.forEach(doc => {
      migrations.push({
        id: doc.id,
        ...doc.data()
      });
    });
    
    return migrations;
  }

  /**
   * Rollback a migration
   */
  async rollbackMigration(migrationId) {
    const migrationDoc = await this.db.collection('migrations').doc(migrationId).get();
    
    if (!migrationDoc.exists) {
      throw new Error('Migration not found');
    }
    
    const migration = migrationDoc.data();
    
    if (migration.config.dryRun) {
      throw new Error('Cannot rollback a dry run migration');
    }
    
    if (migration.status === 'running') {
      throw new Error('Cannot rollback a running migration');
    }

    // Create rollback job
    const rollbackId = `rollback_${migrationId}_${Date.now()}`;
    
    // Find all posts that were migrated by this migration
    const postsQuery = this.db.collection('posts')
      .where('migrationId', '==', migrationId);
    
    const postsSnapshot = await postsQuery.get();
    
    if (postsSnapshot.empty) {
      throw new Error('No posts found to rollback');
    }

    // Create rollback document
    const rollbackDoc = {
      id: rollbackId,
      type: 'rollback',
      originalMigrationId: migrationId,
      status: 'running',
      progress: {
        total: postsSnapshot.size,
        processed: 0
      },
      metadata: {
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        startedAt: admin.firestore.FieldValue.serverTimestamp()
      }
    };

    await this.db.collection('migrations').doc(rollbackId).set(rollbackDoc);

    // Remove interests field from migrated posts
    const batch = this.db.batch();
    let batchCount = 0;
    let processed = 0;

    for (const doc of postsSnapshot.docs) {
      const postRef = this.db.collection('posts').doc(doc.id);
      batch.update(postRef, {
        interests: admin.firestore.FieldValue.delete(),
        migratedAt: admin.firestore.FieldValue.delete(),
        migrationId: admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        rolledBackAt: admin.firestore.FieldValue.serverTimestamp(),
        rolledBackBy: rollbackId
      });
      
      batchCount++;
      processed++;
      
      // Commit in batches of 500 (Firestore limit)
      if (batchCount >= 500) {
        await batch.commit();
        batchCount = 0;
        
        // Update progress
        await this.db.collection('migrations').doc(rollbackId).update({
          'progress.processed': processed
        });
      }
    }

    // Commit remaining updates
    if (batchCount > 0) {
      await batch.commit();
    }

    // Mark rollback as completed
    await this.db.collection('migrations').doc(rollbackId).update({
      status: 'completed',
      'progress.processed': processed,
      'metadata.completedAt': admin.firestore.FieldValue.serverTimestamp()
    });

    // Mark original migration as rolled back
    await this.db.collection('migrations').doc(migrationId).update({
      status: 'rolled_back',
      rollbackId: rollbackId,
      'metadata.rolledBackAt': admin.firestore.FieldValue.serverTimestamp()
    });

    return {
      rollbackId,
      postsRolledBack: processed,
      status: 'completed'
    };
  }

  /**
   * Clean up old migration records
   */
  async cleanupOldMigrations(daysOld = 30) {
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - daysOld);
    const cutoffTimestamp = admin.firestore.Timestamp.fromDate(cutoffDate);
    
    const query = this.db.collection('migrations')
      .where('metadata.createdAt', '<', cutoffTimestamp)
      .where('status', 'in', ['completed', 'failed', 'stopped', 'rolled_back']);
    
    const snapshot = await query.get();
    const batch = this.db.batch();
    
    snapshot.forEach(doc => {
      batch.delete(doc.ref);
    });
    
    if (!snapshot.empty) {
      await batch.commit();
    }
    
    return { deleted: snapshot.size };
  }
}

export default MigrationService;
