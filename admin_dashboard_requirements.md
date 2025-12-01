# Admin Dashboard Requirements: Interest Taxonomy Management

## Overview

This document outlines the requirements for building admin tools to manage the **Interest Taxonomy** system - a Pinterest-style hierarchical classification system for organizing content.

The Interest Taxonomy is an unlimited-depth hierarchical knowledge graph where:
- Users can follow interests
- Posts are classified into interests
- The feed is personalized based on user interest preferences

---

## Firestore Schema

### Collection: `interests`

Each interest document has the following structure:

```typescript
interface Interest {
  id: string;                    // Unique ID (e.g., "fashion", "fashion_models")
  name: string;                  // Canonical name (lowercase, normalized)
  displayName: string;           // Display name (proper capitalization)
  parentId: string | null;       // Parent interest ID (null for root)
  level: number;                 // Depth in hierarchy (0 = root)
  path: string[];                // Full path from root (e.g., ["fashion", "models", "runway"])
  description?: string;          // Optional description
  coverImageUrl?: string;        // Optional cover image
  isActive: boolean;             // Whether interest is active
  createdAt: Timestamp;          // Creation timestamp
  updatedAt: Timestamp;          // Last update timestamp
  
  // Statistics
  postCount: number;             // Total posts classified to this interest
  followerCount: number;         // Total users following this interest
  weeklyGrowth: number;          // Growth rate (weekly)
  monthlyGrowth: number;         // Growth rate (monthly)
  
  // Taxonomy metadata
  relatedInterestIds: string[];  // IDs of related interests
  keywords: string[];            // Keywords for matching (e.g., ["runway", "catwalk"])
  synonyms: string[];            // Alternative terms (e.g., ["catwalk models"])
}
```

**Example Document:**

```json
{
  "id": "fashion_models_runway",
  "name": "runway models",
  "displayName": "Runway Models",
  "parentId": "fashion_models",
  "level": 2,
  "path": ["fashion", "models", "runway models"],
  "description": "Professional runway and catwalk models",
  "coverImageUrl": null,
  "isActive": true,
  "createdAt": "2024-12-01T10:00:00Z",
  "updatedAt": "2024-12-01T10:00:00Z",
  "postCount": 0,
  "followerCount": 0,
  "weeklyGrowth": 0.0,
  "monthlyGrowth": 0.0,
  "relatedInterestIds": ["fashion_shows"],
  "keywords": ["runway", "catwalk", "fashion week", "haute couture"],
  "synonyms": ["catwalk models", "fashion week models"]
}
```

---

## Required Admin Features

### 1. Interest Taxonomy Browser

**Hierarchical Tree View:**
- Display all interests in a collapsible tree structure
- Show hierarchy with visual indentation (0 = root, 1 = child, etc.)
- Display key metrics inline:
  - Post count
  - Follower count
  - Active/inactive status
- Search/filter functionality
- Sort options (alphabetical, by post count, by followers, by growth)

**UI Elements:**
- Tree view with expand/collapse
- Breadcrumb navigation when drilling down
- Quick stats dashboard at top (total interests, total followers, etc.)

---

### 2. Create New Interest

**Form Fields:**
- **Name*** (required): Canonical name (auto-lowercase, normalized)
- **Display Name*** (required): Properly capitalized display name
- **Parent Interest**: Dropdown to select parent (or "None" for root)
  - Should show hierarchical tree in dropdown
  - Auto-populate `level` and `path` based on selection
- **Description**: Rich text editor
- **Cover Image**: Image upload (optional)
- **Keywords**: Chip input (add/remove multiple)
- **Synonyms**: Chip input (add/remove multiple)
- **Related Interests**: Multi-select dropdown
- **Active**: Checkbox (default: true)

**Validation:**
- Name must be unique
- Display name required
- If parent selected, validate parent exists
- Auto-generate ID from name (replace spaces with underscores, add parent prefix)
  - Example: Parent "fashion", name "runway models" → ID: "fashion_runway_models"

**Auto-populate:**
- `level` = parent.level + 1 (or 0 if no parent)
- `path` = [...parent.path, name] (or [name] if no parent)
- `createdAt` = now
- `updatedAt` = now
- `postCount` = 0
- `followerCount` = 0
- `weeklyGrowth` = 0
- `monthlyGrowth` = 0

---

### 3. Edit Interest

**Editable Fields:**
- Display Name
- Description
- Cover Image
- Keywords (add/remove)
- Synonyms (add/remove)
- Related Interests (add/remove)
- Active status

**Non-editable Fields:**
- ID (immutable)
- Name (immutable - would break references)
- Parent ID (immutable - use move operation instead)
- Level (computed from parent)
- Path (computed from parent)
- Statistics (updated automatically)

**UI:**
- Same form as "Create" but pre-populated
- Show "Last Updated" timestamp
- Confirmation before saving changes

---

### 4. Move Interest (Change Parent)

**Separate Operation:**
- Select interest to move
- Select new parent (or "Root")
- Preview impact:
  - Show old path → new path
  - Show affected child interests
  - Warn if this creates deep nesting (>7 levels)
- Confirm and execute

**Backend Logic:**
- Update `parentId`
- Recalculate `level`
- Recalculate `path`
- Update `updatedAt`
- **Recursively update all descendants:**
  - Update their `path` arrays
  - Update their `level` values

---

### 5. Delete Interest

**Safeguards:**
- Check if interest has children → Block deletion, show error
- Check if `postCount > 0` → Warn, require confirmation
- Check if `followerCount > 0` → Warn, require confirmation
- If no children and counts are 0 → Allow deletion
- Option to "Deactivate" instead (set `isActive = false`)

**Soft Delete Option:**
- Set `isActive = false`
- Keep in database but hidden from users
- Can be reactivated later

---

### 6. Bulk Operations

**Batch Create:**
- CSV/JSON import
- Format:
  ```csv
  name,displayName,parentId,description,keywords,synonyms
  "runway models","Runway Models","fashion_models","Professional runway models","runway,catwalk","catwalk models"
  ```
- Validate all rows before importing
- Show preview with validation errors
- Confirm and execute

**Batch Edit:**
- Multi-select interests
- Bulk update fields:
  - Add keywords
  - Add synonyms
  - Add related interests
  - Change active status
- Preview changes
- Confirm and execute

**Batch Move:**
- Multi-select interests (must share same parent)
- Move all to new parent
- Preview impact
- Confirm and execute

---

### 7. Analytics Dashboard

**Key Metrics:**
- Total interests
- Active interests
- Interests by level (bar chart: level 0, 1, 2, 3+)
- Top interests by followers
- Top interests by posts
- Fastest growing interests (weekly/monthly)
- Inactive interests

**Visualizations:**
- Sunburst chart of entire taxonomy
- Growth trends over time (line chart)
- Distribution chart (interests per parent)

---

### 8. Interest Mining (Future)

**Automated Interest Discovery:**
- Analyze trending tags from posts
- Extract from board names
- Mine from search queries
- Use NLP to identify emerging concepts

**UI:**
- Show interest candidates with:
  - Suggested name
  - Occurrence count
  - Proposed parent
  - Proposed keywords
- Approve/reject/edit before creating
- Bulk approve

---

## Firebase Admin SDK Examples

### Initialize Admin SDK

```typescript
import * as admin from 'firebase-admin';

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://your-project.firebaseio.com'
});

const db = admin.firestore();
const interestsRef = db.collection('interests');
```

### Create Interest

```typescript
async function createInterest(data: {
  name: string;
  displayName: string;
  parentId?: string;
  description?: string;
  keywords?: string[];
  synonyms?: string[];
}) {
  // Calculate level and path
  let level = 0;
  let path = [data.name];
  
  if (data.parentId) {
    const parent = await interestsRef.doc(data.parentId).get();
    if (!parent.exists) {
      throw new Error('Parent interest not found');
    }
    const parentData = parent.data();
    level = parentData.level + 1;
    path = [...parentData.path, data.name];
  }
  
  // Generate ID
  const id = data.parentId 
    ? `${data.parentId}_${data.name.replace(/\s+/g, '_')}` 
    : data.name.replace(/\s+/g, '_');
  
  // Create document
  await interestsRef.doc(id).set({
    id,
    name: data.name.toLowerCase().trim(),
    displayName: data.displayName,
    parentId: data.parentId || null,
    level,
    path,
    description: data.description || null,
    coverImageUrl: null,
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    postCount: 0,
    followerCount: 0,
    weeklyGrowth: 0,
    monthlyGrowth: 0,
    relatedInterestIds: [],
    keywords: data.keywords || [],
    synonyms: data.synonyms || []
  });
  
  return id;
}
```

### Update Interest

```typescript
async function updateInterest(id: string, updates: Partial<Interest>) {
  await interestsRef.doc(id).update({
    ...updates,
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });
}
```

### Move Interest (Change Parent)

```typescript
async function moveInterest(interestId: string, newParentId: string | null) {
  const interest = await interestsRef.doc(interestId).get();
  if (!interest.exists) {
    throw new Error('Interest not found');
  }
  
  let newLevel = 0;
  let newPath = [interest.data().name];
  
  if (newParentId) {
    const parent = await interestsRef.doc(newParentId).get();
    if (!parent.exists) {
      throw new Error('Parent interest not found');
    }
    newLevel = parent.data().level + 1;
    newPath = [...parent.data().path, interest.data().name];
  }
  
  // Update this interest
  await interestsRef.doc(interestId).update({
    parentId: newParentId,
    level: newLevel,
    path: newPath,
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });
  
  // Update all descendants recursively
  await updateDescendants(interestId, newPath, newLevel);
}

async function updateDescendants(parentId: string, parentPath: string[], parentLevel: number) {
  const children = await interestsRef.where('parentId', '==', parentId).get();
  
  const batch = db.batch();
  for (const child of children.docs) {
    const childData = child.data();
    const newPath = [...parentPath, childData.name];
    const newLevel = parentLevel + 1;
    
    batch.update(child.ref, {
      level: newLevel,
      path: newPath,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    // Recursively update grandchildren
    await updateDescendants(child.id, newPath, newLevel);
  }
  
  await batch.commit();
}
```

### Delete Interest

```typescript
async function deleteInterest(id: string, force: boolean = false) {
  // Check for children
  const children = await interestsRef.where('parentId', '==', id).get();
  if (!children.empty) {
    throw new Error('Cannot delete interest with children. Move or delete children first.');
  }
  
  const interest = await interestsRef.doc(id).get();
  const data = interest.data();
  
  // Warn if has posts or followers
  if (!force && (data.postCount > 0 || data.followerCount > 0)) {
    throw new Error('Interest has posts or followers. Use force=true to delete anyway.');
  }
  
  await interestsRef.doc(id).delete();
}

async function deactivateInterest(id: string) {
  await interestsRef.doc(id).update({
    isActive: false,
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });
}
```

### Fetch Hierarchy

```typescript
async function getInterestTree(maxDepth?: number) {
  let query = interestsRef.where('isActive', '==', true);
  
  if (maxDepth !== undefined) {
    query = query.where('level', '<=', maxDepth);
  }
  
  const snapshot = await query.get();
  return snapshot.docs.map(doc => doc.data());
}

async function getChildren(parentId: string | null) {
  const query = parentId 
    ? interestsRef.where('parentId', '==', parentId)
    : interestsRef.where('level', '==', 0);
  
  const snapshot = await query.where('isActive', '==', true).get();
  return snapshot.docs.map(doc => doc.data());
}
```

---

## API Endpoints to Build

If you're building a REST API for the dashboard:

### `GET /api/admin/interests`
- Query params: `?maxDepth=2&active=true&sort=followers`
- Returns: Array of interests

### `GET /api/admin/interests/:id`
- Returns: Single interest with full details

### `GET /api/admin/interests/:id/children`
- Returns: Direct children of interest

### `GET /api/admin/interests/:id/path`
- Returns: Breadcrumb path from root to interest

### `POST /api/admin/interests`
- Body: Interest creation data
- Returns: Created interest

### `PUT /api/admin/interests/:id`
- Body: Partial interest update
- Returns: Updated interest

### `POST /api/admin/interests/:id/move`
- Body: `{ newParentId: string | null }`
- Returns: Updated interest + affected descendants

### `DELETE /api/admin/interests/:id`
- Query: `?force=true`
- Returns: Success message

### `POST /api/admin/interests/:id/deactivate`
- Returns: Updated interest

### `POST /api/admin/interests/batch`
- Body: Array of interests or CSV
- Returns: Created interests + errors

### `GET /api/admin/interests/analytics`
- Returns: Analytics dashboard data

---

## Security Rules

Ensure only admins can access these endpoints:

```typescript
// Firestore Security Rules
match /interests/{interestId} {
  // Allow read for authenticated users (app needs to read)
  allow read: if request.auth != null;
  
  // Only admins can write
  allow write: if request.auth != null && 
    get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
}
```

---

## Testing Checklist

- [ ] Create root interest
- [ ] Create child interest (level 1)
- [ ] Create grandchild interest (level 2)
- [ ] Verify path and level auto-calculation
- [ ] Edit interest fields
- [ ] Move interest to new parent
- [ ] Verify descendants updated after move
- [ ] Delete interest with children (should fail)
- [ ] Delete interest without children (should succeed)
- [ ] Deactivate interest
- [ ] Batch import from CSV
- [ ] Search/filter interests
- [ ] View analytics dashboard

---

## Initial Seed Data

18 interests have been created in the iOS app covering:
- 10 root-level interests (Fashion, Photography, Design, Art, Beauty, Travel, Food, Architecture, Lifestyle, Creative)
- Fashion sub-tree (Models, Streetwear, Haute Couture, Fashion Shows)
- Models sub-tree (Runway, Editorial, Commercial, Diverse)
- Photography sub-tree (Portrait, Landscape, Street, Fashion)

You can view the seed data structure in the iOS codebase at:
`OraBeta/Models/InterestTaxonomySeed.swift`

---

## Questions?

Contact the iOS development team for:
- Schema clarifications
- Additional fields needed
- Integration questions
- Testing data access
