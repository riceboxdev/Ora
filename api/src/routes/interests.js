import express from 'express';
import { protect, requireRole } from '../middleware/adminAuth.js';
import { apiRateLimiter } from '../middleware/rateLimit.js';
import admin from 'firebase-admin';

const router = express.Router();

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  try {
    const projectId = process.env.FIREBASE_PROJECT_ID?.trim();
    const rawPrivateKey = process.env.FIREBASE_PRIVATE_KEY;
    const clientEmail = process.env.FIREBASE_CLIENT_EMAIL?.trim();
    
    // Initialize Firebase Admin
    admin.initializeApp({
      credential: admin.credential.cert({
        projectId,
        privateKey: rawPrivateKey?.replace(/\\n/g, '\n'),
        clientEmail,
      }),
    });
    console.log('Firebase Admin initialized in interests.js');
  } catch (error) {
    console.error('Firebase admin initialization error in interests.js', error);
  }
}

const db = admin.firestore();
const interestsRef = db.collection('interests');

// Helper function to process interest data
const processInterestData = (doc) => {
  const data = doc.data();
  return {
    id: doc.id,
    ...data,
    // Convert Firestore timestamps to ISO strings
    createdAt: data.createdAt?.toDate().toISOString(),
    updatedAt: data.updatedAt?.toDate().toISOString(),
  };
};

// @route   GET /api/interests
// @desc    Get all interests with optional filtering and pagination
// @access  Private (moderator+)
router.get('/', requireRole('super_admin', 'moderator', 'viewer'), async (req, res) => {
  try {
    const { 
      parentId, 
      searchTerm, 
      isActive = 'true',
      limit = 20, 
      lastDocId 
    } = req.query;

    let query = interestsRef.limit(parseInt(limit));
    
    // Apply filters
    if (parentId) {
      query = query.where('parentId', '==', parentId);
    } else if (parentId === '') {
      // If parentId is empty string, get root level interests
      query = query.where('level', '==', 0);
    }
    
    if (isActive !== 'all') {
      query = query.where('isActive', '==', isActive === 'true');
    }
    
    if (searchTerm) {
      // Simple search on name and displayName - for more advanced search, consider using Algolia
      query = query.where('keywords', 'array-contains', searchTerm.toLowerCase());
    }
    
    // Apply pagination
    if (lastDocId) {
      const lastDoc = await interestsRef.doc(lastDocId).get();
      if (lastDoc.exists) {
        query = query.startAfter(lastDoc);
      }
    }
    
    const snapshot = await query.get();
    const interests = [];
    let lastVisible = null;
    
    snapshot.forEach((doc) => {
      interests.push(processInterestData(doc));
      lastVisible = doc;
    });
    
    res.json({
      success: true,
      data: interests,
      lastDocId: lastVisible?.id,
      hasMore: interests.length === parseInt(limit)
    });
    
  } catch (error) {
    console.error('Error fetching interests:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Failed to fetch interests',
      error: error.message 
    });
  }
});

// @route   GET /api/interests/:id
// @desc    Get a single interest by ID
// @access  Private (moderator+)
router.get('/:id', requireRole('super_admin', 'moderator', 'viewer'), async (req, res) => {
  try {
    const { id } = req.params;
    const doc = await interestsRef.doc(id).get();
    
    if (!doc.exists) {
      return res.status(404).json({ 
        success: false, 
        message: 'Interest not found' 
      });
    }
    
    res.json({
      success: true,
      data: processInterestData(doc)
    });
    
  } catch (error) {
    console.error('Error fetching interest:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Failed to fetch interest',
      error: error.message 
    });
  }
});

// @route   POST /api/interests
// @desc    Create a new interest
// @access  Private (super_admin+)
router.post('/', requireRole('super_admin'), async (req, res) => {
  try {
    const {
      name,
      displayName,
      parentId,
      description,
      coverImageUrl,
      isActive = true,
      relatedInterestIds = [],
      keywords = [],
      synonyms = []
    } = req.body;
    
    // Basic validation
    if (!name || !displayName) {
      return res.status(400).json({
        success: false,
        message: 'Name and display name are required'
      });
    }
    
    // Check if interest with same name already exists
    const existing = await interestsRef.where('name', '==', name.toLowerCase()).get();
    if (!existing.empty) {
      return res.status(400).json({
        success: false,
        message: 'An interest with this name already exists'
      });
    }
    
    // Determine level and path based on parent
    let level = 0;
    let path = [];
    
    if (parentId) {
      const parentDoc = await interestsRef.doc(parentId).get();
      if (!parentDoc.exists) {
        return res.status(400).json({
          success: false,
          message: 'Parent interest not found'
        });
      }
      const parentData = parentDoc.data();
      level = parentData.level + 1;
      path = [...parentData.path, parentId];
    }
    
    // Create interest data
    const interestData = {
      name: name.toLowerCase(),
      displayName,
      parentId: parentId || null,
      level,
      path,
      description: description || null,
      coverImageUrl: coverImageUrl || null,
      isActive: Boolean(isActive),
      relatedInterestIds: Array.isArray(relatedInterestIds) ? relatedInterestIds : [],
      keywords: Array.isArray(keywords) ? keywords : [],
      synonyms: Array.isArray(synonyms) ? synonyms : [],
      postCount: 0,
      followerCount: 0,
      weeklyGrowth: 0,
      monthlyGrowth: 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };
    
    // Add to Firestore
    const docRef = await interestsRef.add(interestData);
    const newInterest = { id: docRef.id, ...interestData };
    
    res.status(201).json({
      success: true,
      data: newInterest
    });
    
  } catch (error) {
    console.error('Error creating interest:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Failed to create interest',
      error: error.message 
    });
  }
});

// @route   PUT /api/interests/:id
// @desc    Update an existing interest
// @access  Private (super_admin+)
router.put('/:id', requireRole('super_admin'), async (req, res) => {
  try {
    const { id } = req.params;
    const {
      name,
      displayName,
      description,
      coverImageUrl,
      isActive,
      relatedInterestIds,
      keywords,
      synonyms
    } = req.body;
    
    const docRef = interestsRef.doc(id);
    const doc = await docRef.get();
    
    if (!doc.exists) {
      return res.status(404).json({
        success: false,
        message: 'Interest not found'
      });
    }
    
    // Build update data
    const updateData = {
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };
    
    // Only update fields that were provided
    if (name !== undefined) updateData.name = name.toLowerCase();
    if (displayName !== undefined) updateData.displayName = displayName;
    if (description !== undefined) updateData.description = description || null;
    if (coverImageUrl !== undefined) updateData.coverImageUrl = coverImageUrl || null;
    if (isActive !== undefined) updateData.isActive = Boolean(isActive);
    if (relatedInterestIds !== undefined) {
      updateData.relatedInterestIds = Array.isArray(relatedInterestIds) ? relatedInterestIds : [];
    }
    if (keywords !== undefined) {
      updateData.keywords = Array.isArray(keywords) ? keywords : [];
    }
    if (synonyms !== undefined) {
      updateData.synonyms = Array.isArray(synonyms) ? synonyms : [];
    }
    
    // Check for duplicate name if name is being updated
    if (name !== undefined) {
      const existing = await interestsRef
        .where('name', '==', name.toLowerCase())
        .where(admin.firestore.FieldPath.documentId(), '!=', id)
        .get();
        
      if (!existing.empty) {
        return res.status(400).json({
          success: false,
          message: 'An interest with this name already exists'
        });
      }
    }
    
    await docRef.update(updateData);
    
    // Get updated document
    const updatedDoc = await docRef.get();
    
    res.json({
      success: true,
      data: processInterestData(updatedDoc)
    });
    
  } catch (error) {
    console.error('Error updating interest:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Failed to update interest',
      error: error.message 
    });
  }
});

// @route   POST /api/interests/:id/move
// @desc    Move an interest to a new parent
// @access  Private (super_admin+)
router.post('/:id/move', requireRole('super_admin'), async (req, res) => {
  const session = db.batch();
  
  try {
    const { id } = req.params;
    const { newParentId } = req.body;
    
    if (id === newParentId) {
      return res.status(400).json({
        success: false,
        message: 'Cannot move an interest to be a child of itself'
      });
    }
    
    // Get the interest to move
    const interestRef = interestsRef.doc(id);
    const interestDoc = await interestRef.get();
    
    if (!interestDoc.exists) {
      return res.status(404).json({
        success: false,
        message: 'Interest not found'
      });
    }
    
    const interestData = interestDoc.data();
    
    // If moving to root
    if (!newParentId) {
      // Update the interest
      session.update(interestRef, {
        parentId: null,
        level: 0,
        path: [],
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      // Update all descendants
      await updateDescendantsPath(session, id, [], 1);
    } 
    // Moving to a new parent
    else {
      // Get the new parent
      const newParentDoc = await interestsRef.doc(newParentId).get();
      
      if (!newParentDoc.exists) {
        return res.status(404).json({
          success: false,
          message: 'Parent interest not found'
        });
      }
      
      const newParentData = newParentDoc.data();
      
      // Check for cycles (new parent is a descendant of this interest)
      if (newParentData.path.includes(id)) {
        return res.status(400).json({
          success: false,
          message: 'Cannot create a cycle in the interest hierarchy'
        });
      }
      
      // Calculate new path and level
      const newPath = [...newParentData.path, newParentId];
      const newLevel = newParentData.level + 1;
      
      // Update the interest
      session.update(interestRef, {
        parentId: newParentId,
        level: newLevel,
        path: newPath,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      // Update all descendants
      await updateDescendantsPath(session, id, newPath, newLevel + 1);
    }
    
    // Commit all updates in a single transaction
    await session.commit();
    
    // Get updated interest
    const updatedDoc = await interestRef.get();
    
    res.json({
      success: true,
      data: processInterestData(updatedDoc)
    });
    
  } catch (error) {
    console.error('Error moving interest:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Failed to move interest',
      error: error.message 
    });
  }
});

// Helper function to update paths of all descendants
async function updateDescendantsPath(session, parentId, parentPath, level) {
  // Get all direct children
  const childrenSnapshot = await interestsRef
    .where('parentId', '==', parentId)
    .get();
  
  // Update each child
  for (const doc of childrenSnapshot.docs) {
    const childPath = [...parentPath, parentId];
    
    session.update(doc.ref, {
      path: childPath,
      level: level,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    // Recursively update all descendants
    await updateDescendantsPath(session, doc.id, childPath, level + 1);
  }
}

// @route   DELETE /api/interests/:id
// @desc    Delete an interest
// @access  Private (super_admin+)
router.delete('/:id', requireRole('super_admin'), async (req, res) => {
  const session = db.batch();
  
  try {
    const { id } = req.params;
    const { deleteChildren = false } = req.query;
    
    // Check if interest exists
    const interestRef = interestsRef.doc(id);
    const interestDoc = await interestRef.get();
    
    if (!interestDoc.exists) {
      return res.status(404).json({
        success: false,
        message: 'Interest not found'
      });
    }
    
    // Check if interest has children
    const childrenSnapshot = await interestsRef
      .where('parentId', '==', id)
      .limit(1)
      .get();
    
    if (!childrenSnapshot.empty && !deleteChildren) {
      return res.status(400).json({
        success: false,
        message: 'Cannot delete interest with children. Set deleteChildren=true to delete with children.'
      });
    }
    
    // If deleting children, recursively delete all descendants
    if (deleteChildren) {
      await deleteInterestAndDescendants(session, id);
    } else {
      // Just delete this interest
      session.delete(interestRef);
    }
    
    await session.commit();
    
    res.json({
      success: true,
      message: 'Interest deleted successfully'
    });
    
  } catch (error) {
    console.error('Error deleting interest:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Failed to delete interest',
      error: error.message 
    });
  }
});

// Helper function to delete an interest and all its descendants
async function deleteInterestAndDescendants(session, interestId) {
  // Get all children
  const childrenSnapshot = await interestsRef
    .where('parentId', '==', interestId)
    .get();
  
  // Recursively delete all descendants
  for (const doc of childrenSnapshot.docs) {
    await deleteInterestAndDescendants(session, doc.id);
  }
  
  // Delete this interest
  const interestRef = interestsRef.doc(interestId);
  session.delete(interestRef);
}

// @route   POST /api/interests/import
// @desc    Import interests from CSV
// @access  Private (super_admin+)
router.post('/import', requireRole('super_admin'), async (req, res) => {
  try {
    // This is a simplified example - in a real implementation, you'd want to:
    // 1. Accept a file upload
    // 2. Parse the CSV
    // 3. Validate the data
    // 4. Import the interests
    
    // For now, we'll just return a not implemented response
    res.status(501).json({
      success: false,
      message: 'Import functionality is not yet implemented'
    });
    
  } catch (error) {
    console.error('Error importing interests:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Failed to import interests',
      error: error.message 
    });
  }
});

// @route   GET /api/interests/export
// @desc    Export interests to CSV
// @access  Private (super_admin+)
router.get('/export', requireRole('super_admin'), async (req, res) => {
  try {
    // Get all interests
    const snapshot = await interestsRef.get();
    const interests = [];
    
    snapshot.forEach(doc => {
      interests.push(processInterestData(doc));
    });
    
    // Convert to CSV (simplified example)
    let csv = 'id,name,displayName,parentId,level,path,description,isActive\n';
    
    for (const interest of interests) {
      const row = [
        `"${interest.id}"`,
        `"${interest.name}"`,
        `"${interest.displayName}"`,
        `"${interest.parentId || ''}"`,
        interest.level,
        `"${interest.path.join('>')}"`,
        `"${(interest.description || '').replace(/"/g, '""')}"`,
        interest.isActive ? 'true' : 'false'
      ];
      
      csv += row.join(',') + '\n';
    }
    
    // Set headers for file download
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', 'attachment; filename=interests-export.csv');
    
    // Send the CSV data
    res.send(csv);
    
  } catch (error) {
    console.error('Error exporting interests:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Failed to export interests',
      error: error.message 
    });
  }
});

export default router;
