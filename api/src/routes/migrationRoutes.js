import express from 'express';
import { protect, requireRole } from '../middleware/adminAuth.js';
import { apiRateLimiter } from '../middleware/rateLimit.js';
import { logActivity } from '../middleware/activityLogger.js';
import MigrationService from '../services/migrationService.js';

const router = express.Router();
const migrationService = new MigrationService();

// All routes require authentication and rate limiting
router.use(protect);
router.use(apiRateLimiter);

// @route   GET /api/migrations/analyze-tags
// @desc    Analyze existing tags and suggest mappings
// @access  Private (viewer+)
router.get('/analyze-tags', requireRole('super_admin', 'moderator', 'viewer'), async (req, res) => {
  try {
    const { 
      limit = 1000, 
      excludeExisting = true 
    } = req.query;

    const analysis = await migrationService.analyzeTagsForMappings({
      limit: parseInt(limit),
      excludeExisting: excludeExisting === 'true'
    });

    res.json({
      success: true,
      data: analysis
    });
  } catch (error) {
    console.error('Error analyzing tags:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// @route   POST /api/migrations/validate
// @desc    Validate migration configuration
// @access  Private (viewer+)
router.post('/validate', requireRole('super_admin', 'moderator', 'viewer'), async (req, res) => {
  try {
    const validation = await migrationService.validateMigration(req.body);
    
    res.json({
      success: true,
      validation
    });
  } catch (error) {
    console.error('Error validating migration:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// @route   POST /api/migrations/create
// @desc    Create a new migration job
// @access  Private (moderator+)
router.post('/create', logActivity, requireRole('super_admin', 'moderator'), async (req, res) => {
  try {
    const userId = req.user.uid;
    const result = await migrationService.createMigrationJob(req.body, userId);
    
    res.json({
      success: true,
      ...result
    });
  } catch (error) {
    console.error('Error creating migration:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// @route   POST /api/migrations/:id/start
// @desc    Start a migration job
// @access  Private (moderator+)
router.post('/:id/start', logActivity, requireRole('super_admin', 'moderator'), async (req, res) => {
  try {
    const { id } = req.params;
    const result = await migrationService.startMigration(id);
    
    res.json({
      success: true,
      ...result
    });
  } catch (error) {
    console.error('Error starting migration:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// @route   POST /api/migrations/:id/pause
// @desc    Pause a running migration
// @access  Private (moderator+)
router.post('/:id/pause', logActivity, requireRole('super_admin', 'moderator'), async (req, res) => {
  try {
    const { id } = req.params;
    const result = await migrationService.pauseMigration(id);
    
    res.json({
      success: true,
      ...result
    });
  } catch (error) {
    console.error('Error pausing migration:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// @route   POST /api/migrations/:id/stop
// @desc    Stop a migration
// @access  Private (moderator+)
router.post('/:id/stop', logActivity, requireRole('super_admin', 'moderator'), async (req, res) => {
  try {
    const { id } = req.params;
    const result = await migrationService.stopMigration(id);
    
    res.json({
      success: true,
      ...result
    });
  } catch (error) {
    console.error('Error stopping migration:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// @route   GET /api/migrations/:id/status
// @desc    Get migration status and progress
// @access  Private (viewer+)
router.get('/:id/status', requireRole('super_admin', 'moderator', 'viewer'), async (req, res) => {
  try {
    const { id } = req.params;
    const migration = await migrationService.getMigrationStatus(id);
    
    res.json({
      success: true,
      migration
    });
  } catch (error) {
    console.error('Error getting migration status:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// @route   GET /api/migrations
// @desc    List all migrations with filtering
// @access  Private (viewer+)
router.get('/', requireRole('super_admin', 'moderator', 'viewer'), async (req, res) => {
  try {
    const {
      limit = 20,
      status,
      userId
    } = req.query;

    const migrations = await migrationService.listMigrations({
      limit: parseInt(limit),
      status,
      userId
    });
    
    res.json({
      success: true,
      migrations,
      count: migrations.length
    });
  } catch (error) {
    console.error('Error listing migrations:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// @route   POST /api/migrations/:id/rollback
// @desc    Rollback a completed migration
// @access  Private (moderator+)
router.post('/:id/rollback', logActivity, requireRole('super_admin', 'moderator'), async (req, res) => {
  try {
    const { id } = req.params;
    const result = await migrationService.rollbackMigration(id);
    
    res.json({
      success: true,
      ...result
    });
  } catch (error) {
    console.error('Error rolling back migration:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// @route   DELETE /api/migrations/cleanup
// @desc    Clean up old migration records
// @access  Private (super_admin only)
router.delete('/cleanup', logActivity, requireRole('super_admin'), async (req, res) => {
  try {
    const { daysOld = 30 } = req.query;
    const result = await migrationService.cleanupOldMigrations(parseInt(daysOld));
    
    res.json({
      success: true,
      ...result
    });
  } catch (error) {
    console.error('Error cleaning up migrations:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// @route   POST /api/migrations/dry-run
// @desc    Create and immediately start a dry run migration
// @access  Private (viewer+)
router.post('/dry-run', requireRole('super_admin', 'moderator', 'viewer'), async (req, res) => {
  try {
    const userId = req.user.uid;
    const config = { ...req.body, dryRun: true };
    
    // Create the migration
    const createResult = await migrationService.createMigrationJob(config, userId);
    
    // Start it immediately
    await migrationService.startMigration(createResult.migrationId);
    
    res.json({
      success: true,
      migrationId: createResult.migrationId,
      message: 'Dry run started successfully'
    });
  } catch (error) {
    console.error('Error starting dry run:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// @route   GET /api/migrations/stats
// @desc    Get overall migration statistics
// @access  Private (viewer+)
router.get('/stats', requireRole('super_admin', 'moderator', 'viewer'), async (req, res) => {
  try {
    const migrations = await migrationService.listMigrations({ limit: 100 });
    
    const stats = {
      total: migrations.length,
      byStatus: {},
      recentActivity: migrations.slice(0, 5).map(m => ({
        id: m.id,
        status: m.status,
        createdAt: m.metadata?.createdAt,
        progress: m.progress
      }))
    };
    
    // Count by status
    migrations.forEach(m => {
      stats.byStatus[m.status] = (stats.byStatus[m.status] || 0) + 1;
    });
    
    // Get post migration stats
    const completedMigrations = migrations.filter(m => m.status === 'completed');
    const totalMigrated = completedMigrations.reduce((sum, m) => sum + (m.progress?.migrated || 0), 0);
    
    stats.totalPostsMigrated = totalMigrated;
    stats.successRate = migrations.length > 0 ? 
      Math.round((completedMigrations.length / migrations.length) * 100) : 0;
    
    res.json({
      success: true,
      stats
    });
  } catch (error) {
    console.error('Error getting migration stats:', error);
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

export default router;
