# Post Migration: Tags → Interests

## Overview

This document outlines the migration strategy for transitioning posts from the old `tags`/`categories` system to the new **interests** taxonomy.

### Old Data Structure
Posts currently have:
- `tags: [String]?` - Arbitrary tags set by users (e.g., "Nature", "Abstract")
- `categories: [String]?` - Pre-defined categories (e.g., business, lifestyle)

### New Data Structure
Posts will have:
- `interests: [String]?` - Interest IDs from the interests taxonomy (e.g., "photography", "nature-photography")

---

## Migration Strategy

### Phase 1: Compatibility Layer (Immediate)
**Goal:** Support both old and new formats simultaneously while migration is in progress

#### Post Model Update
Update the Post struct to support both:
```swift
struct Post: Identifiable, Codable {
    // ... existing fields ...
    
    // Old fields (keep for backward compatibility)
    let tags: [String]?
    let categories: [String]?
    
    // New field (populates during migration)
    let interests: [String]?
    
    // Helper to get interests or fallback to tags
    var effectiveInterests: [String] {
        if let interests = interests, !interests.isEmpty {
            return interests
        }
        // Fallback to tags if interests not yet migrated
        return tags ?? []
    }
}
```

#### Firestore Post Documents
Existing posts keep old fields, new field added:
```json
{
  "id": "post123",
  "userId": "user456",
  "imageUrl": "...",
  "caption": "Beautiful landscape",
  
  // Old fields (will be depreciated)
  "tags": ["landscape", "nature", "mountains"],
  "categories": ["travel"],
  
  // New field (added during migration)
  "interests": ["photography", "travel", "nature"],
  
  // Migration tracking
  "migratedAt": null,
  "migrationStatus": "pending"
}
```

---

### Phase 2: Automated Tagging (Dashboard)

#### Tagging Rules
Create logical mapping from old tags → interests:

| Old Tag | Interest ID | Confidence |
|---------|-------------|------------|
| Nature | photography | High |
| landscape | travel | High |
| animals | pets | High |
| food | food | High |
| architecture | home | Medium |
| abstract | photography | Medium |
| people | photography | Medium |

#### Create Mapping Service

**Backend API Endpoint**
```
POST /api/admin/posts/migrate-interests
Body: {
  "batchSize": 100,
  "tagMappings": {
    "nature": "photography",
    "landscape": "travel",
    ...
  }
}
```

---

### Phase 3: Dashboard UI for Migration

Provide admin dashboard with:
1. **Preview**: Show which posts would be migrated
2. **Mapping Editor**: Adjust tag→interest mappings
3. **Batch Process**: Migrate posts in chunks
4. **Progress Tracking**: Monitor migration status
5. **Rollback**: Ability to revert migrations

---

## Implementation

### 1. Backend: Migration Endpoint

**File:** `api/src/routes/admin.js`

```javascript
/**
 * POST /api/admin/posts/migrate-interests
 * 
 * Migrate posts from tags/categories to interests taxonomy
 * Supports batch processing with progress tracking
 */
router.post('/posts/migrate-interests', requireRole('super_admin'), async (req, res) => {
  try {
    const db = admin.firestore();
    const { batchSize = 100, limit = null, tagMappings = {}, updateAll = false } = req.body;
    
    let query = db.collection('posts');
    
    if (updateAll) {
      // Migrate all posts without interests
      query = query.where('interests', '==', null);
    }
    
    const snapshot = await query.limit(limit || batchSize).get();
    const batch = db.batch();
    let migratedCount = 0;
    let skippedCount = 0;
    const errors = [];
    
    for (const doc of snapshot.docs) {
      try {
        const post = doc.data();
        const tags = post.tags || [];
        const categories = post.categories || [];
        
        // Map old tags to interests
        const interests = new Set();
        
        // Apply tag mappings
        for (const tag of tags) {
          const mappedInterest = tagMappings[tag.toLowerCase()];
          if (mappedInterest) {
            interests.add(mappedInterest);
          }
        }
        
        // Map categories directly (assume they align with interests)
        for (const category of categories) {
          interests.add(category.toLowerCase());
        }
        
        // Skip if no interests found
        if (interests.size === 0) {
          skippedCount++;
          continue;
        }
        
        // Update post with interests
        batch.update(doc.ref, {
          interests: Array.from(interests),
          migratedAt: admin.firestore.FieldValue.serverTimestamp(),
          migrationStatus: 'completed'
        });
        
        migratedCount++;
      } catch (error) {
        errors.push({
          postId: doc.id,
          error: error.message
        });
      }
    }
    
    await batch.commit();
    
    res.json({
      success: true,
      message: `Migration complete`,
      migrated: migratedCount,
      skipped: skippedCount,
      errors: errors,
      totalProcessed: snapshot.docs.length
    });
  } catch (error) {
    console.error('Error migrating interests:', error);
    res.status(500).json({ message: error.message });
  }
});

/**
 * GET /api/admin/posts/migration-stats
 * 
 * Get migration progress and statistics
 */
router.get('/posts/migration-stats', requireRole('super_admin'), async (req, res) => {
  try {
    const db = admin.firestore();
    
    const totalPosts = await db.collection('posts').count().get();
    const migratedPosts = await db.collection('posts')
      .where('migrationStatus', '==', 'completed')
      .count()
      .get();
    const pendingPosts = await db.collection('posts')
      .where('interests', '==', null)
      .count()
      .get();
    
    res.json({
      success: true,
      stats: {
        total: totalPosts.data().count,
        migrated: migratedPosts.data().count,
        pending: pendingPosts.data().count,
        percentage: Math.round((migratedPosts.data().count / totalPosts.data().count) * 100)
      }
    });
  } catch (error) {
    console.error('Error getting migration stats:', error);
    res.status(500).json({ message: error.message });
  }
});
```

### 2. Frontend: Migration Dashboard Component

**File:** `admin-dashboard/pages/PostsMigration.vue`

```vue
<template>
  <div class="min-h-screen bg-gray-50">
    <AppHeader />
    
    <main class="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
      <div class="px-4 py-6 sm:px-0">
        <h2 class="text-2xl font-bold text-gray-900 mb-6">Post Migration: Tags → Interests</h2>
        
        <!-- Migration Statistics -->
        <div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
          <div class="bg-white p-4 rounded-lg shadow">
            <p class="text-gray-600 text-sm">Total Posts</p>
            <p class="text-2xl font-bold">{{ stats.total }}</p>
          </div>
          <div class="bg-blue-50 p-4 rounded-lg shadow">
            <p class="text-gray-600 text-sm">Migrated</p>
            <p class="text-2xl font-bold text-blue-600">{{ stats.migrated }}</p>
          </div>
          <div class="bg-yellow-50 p-4 rounded-lg shadow">
            <p class="text-gray-600 text-sm">Pending</p>
            <p class="text-2xl font-bold text-yellow-600">{{ stats.pending }}</p>
          </div>
          <div class="bg-green-50 p-4 rounded-lg shadow">
            <p class="text-gray-600 text-sm">Progress</p>
            <p class="text-2xl font-bold text-green-600">{{ stats.percentage }}%</p>
          </div>
        </div>
        
        <!-- Migration Progress Bar -->
        <div class="bg-white p-6 rounded-lg shadow mb-6">
          <h3 class="text-lg font-semibold mb-4">Migration Progress</h3>
          <div class="w-full bg-gray-200 rounded-full h-4">
            <div 
              class="bg-green-600 h-4 rounded-full transition-all duration-300"
              :style="{ width: stats.percentage + '%' }"
            ></div>
          </div>
          <p class="text-sm text-gray-600 mt-2">
            {{ stats.migrated }} of {{ stats.total }} posts migrated
          </p>
        </div>
        
        <!-- Tag to Interest Mapping Editor -->
        <div class="bg-white p-6 rounded-lg shadow mb-6">
          <h3 class="text-lg font-semibold mb-4">Tag → Interest Mappings</h3>
          
          <div class="space-y-3 max-h-96 overflow-y-auto">
            <div 
              v-for="(interest, tag) in tagMappings"
              :key="tag"
              class="flex items-center gap-3 p-3 bg-gray-50 rounded"
            >
              <span class="font-mono text-sm flex-shrink-0 w-32">{{ tag }}</span>
              <span class="text-gray-400">→</span>
              <select 
                :value="interest"
                @change="updateMapping(tag, $event.target.value)"
                class="flex-1 px-3 py-1 border border-gray-300 rounded text-sm"
              >
                <option value="">-- Remove Mapping --</option>
                <option v-for="interest in availableInterests" :key="interest" :value="interest">
                  {{ interest }}
                </option>
              </select>
              <button 
                @click="removeMapping(tag)"
                class="text-red-600 hover:text-red-800"
              >
                ✕
              </button>
            </div>
          </div>
        </div>
        
        <!-- Migration Controls -->
        <div class="bg-white p-6 rounded-lg shadow">
          <h3 class="text-lg font-semibold mb-4">Start Migration</h3>
          
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Batch Size</label>
              <input 
                v-model.number="batchSize"
                type="number"
                min="10"
                max="1000"
                class="w-full px-3 py-2 border border-gray-300 rounded"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Limit (0 = unlimited)</label>
              <input 
                v-model.number="limit"
                type="number"
                min="0"
                class="w-full px-3 py-2 border border-gray-300 rounded"
              />
            </div>
          </div>
          
          <div class="flex gap-3">
            <button
              @click="startMigration"
              :disabled="isProcessing"
              class="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 disabled:opacity-50"
            >
              {{ isProcessing ? 'Migrating...' : 'Start Migration' }}
            </button>
            <button
              @click="refreshStats"
              :disabled="isProcessing"
              class="px-4 py-2 bg-gray-300 text-gray-700 rounded hover:bg-gray-400 disabled:opacity-50"
            >
              Refresh Stats
            </button>
          </div>
          
          <div v-if="migrationResult" class="mt-4 p-4 bg-green-50 border border-green-200 rounded">
            <p class="text-green-800">
              ✓ Migrated: {{ migrationResult.migrated }} | Skipped: {{ migrationResult.skipped }}
            </p>
          </div>
        </div>
      </div>
    </main>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import AppHeader from '../components/AppHeader.vue';

const stats = ref({
  total: 0,
  migrated: 0,
  pending: 0,
  percentage: 0
});

const tagMappings = ref({
  nature: 'photography',
  landscape: 'travel',
  animals: 'pets',
  food: 'food',
  architecture: 'home',
  people: 'photography',
  art: 'entertainment'
});

const availableInterests = ref([
  'fashion', 'beauty', 'food', 'fitness', 'home', 
  'travel', 'photography', 'entertainment', 'technology', 'pets'
]);

const batchSize = ref(100);
const limit = ref(0);
const isProcessing = ref(false);
const migrationResult = ref(null);

onMounted(() => {
  refreshStats();
});

async function refreshStats() {
  try {
    const response = await fetch('/api/admin/posts/migration-stats');
    const data = await response.json();
    stats.value = data.stats;
  } catch (error) {
    console.error('Error fetching stats:', error);
  }
}

async function startMigration() {
  if (!confirm('Start migration with current mappings?')) return;
  
  isProcessing.value = true;
  migrationResult.value = null;
  
  try {
    const response = await fetch('/api/admin/posts/migrate-interests', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        batchSize: batchSize.value,
        limit: limit.value || null,
        tagMappings: tagMappings.value
      })
    });
    
    const data = await response.json();
    migrationResult.value = data;
    
    setTimeout(() => {
      refreshStats();
    }, 1000);
  } catch (error) {
    console.error('Migration error:', error);
  } finally {
    isProcessing.value = false;
  }
}

function updateMapping(tag, interest) {
  if (interest) {
    tagMappings.value[tag] = interest;
  }
}

function removeMapping(tag) {
  delete tagMappings.value[tag];
}
</script>
```

### 3. Update Post Model

**File:** `OraBeta/Models/Post.swift`

Add interests support while keeping backward compatibility:

```swift
struct Post: Identifiable, Codable, Equatable, Hashable {
    // ... existing fields ...
    let tags: [String]?
    let categories: [String]?
    
    // New field
    let interests: [String]?
    
    // Migration tracking
    let migratedAt: Date?
    let migrationStatus: String? // pending, completed
    
    enum CodingKeys: String, CodingKey {
        case id, userId, username, imageUrl, thumbnailUrl
        case tags, categories
        case interests
        case migratedAt, migrationStatus
        // ... other fields ...
    }
    
    // Helper: Get effective interests (fallback to tags if not migrated)
    var effectiveInterests: [String] {
        if let interests = interests, !interests.isEmpty {
            return interests
        }
        return tags ?? []
    }
}
```

---

## Migration Phases

### ✅ Phase 1: Deploy (Now)
- Add `interests`, `migratedAt`, `migrationStatus` fields to Post model
- Update Firestore schema to include new fields
- Deploy Post model changes to iOS app
- Deploy migration API endpoints

### 🔄 Phase 2: Batch Migration (This Week)
- Admin runs dashboard migration tool
- All posts get mapped to interests
- Monitor migration progress

### 📋 Phase 3: Deprecation (Next Release)
- Remove `tags` and `categories` from iOS code (after migration complete)
- Update CreatePostView to use interests only
- Archive old data for auditing

---

## Rollback Plan

If issues occur during migration:

1. **Revert Post Records:** Firestore backups available
2. **Revert App Code:** Deploy previous version
3. **Investigate Mappings:** Review tag→interest mappings
4. **Retry:** Re-run migration with corrected mappings

---

## Validation Checklist

- [ ] All posts have interests field populated
- [ ] No data loss in migration
- [ ] Interest IDs are valid (exist in interests collection)
- [ ] Tags/categories still readable (for auditing)
- [ ] CreatePostView uses interests API
- [ ] Content discovery uses interests instead of tags

---

## Future Enhancements

1. **ML-based Tagging:** Auto-map tags using similarity matching
2. **Manual Override UI:** Allow admins to manually remap specific posts
3. **A/B Testing:** Test different mappings on post discovery
4. **Analytics:** Track which interests are most used
5. **User Preferences:** Let users follow interests for personalized feed
