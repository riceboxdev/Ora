const express = require('express');
const { protect, requireRole } = require('../middleware/adminAuth.js');
const classificationController = require('../controllers/classificationController.js');

const router = express.Router();

// All routes require authentication and at least 'viewer' role
router.use(protect);
router.use(requireRole('super_admin', 'moderator', 'viewer'));

// Analytics
router.get('/analytics', classificationController.getAnalytics);
router.get('/quality/low-confidence', classificationController.getLowConfidencePosts);

// Bulk operations (require moderator+)
router.post('/bulk/classify', requireRole('super_admin', 'moderator'), classificationController.bulkClassify);
router.post('/bulk/reclassify', requireRole('super_admin', 'moderator'), classificationController.bulkReclassify);

// Single post operations
router.get('/', classificationController.getClassifications);
router.get('/:postId', classificationController.getClassification);
router.post('/:postId/interests', requireRole('super_admin', 'moderator'), classificationController.addInterest);
router.delete('/:postId/interests/:interestId', requireRole('super_admin', 'moderator'), classificationController.removeInterest);
router.post('/:postId/reclassify', requireRole('super_admin', 'moderator'), classificationController.reclassifyPost);

module.exports = router;
