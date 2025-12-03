# Interests System Architecture & Design

## Overview

The Interests System is a hierarchical taxonomy management solution that enables users to express their interests through a tree-structured categorization system. It supports creating, managing, and browsing interest categories with keywords, synonyms, and metadata tracking.

**Key Goals:**
- Provide a flexible, scalable taxonomy for user interests
- Enable admin management of the interest hierarchy
- Track interest metrics (followers, posts, growth)
- Support content discovery and personalization
- Maintain data consistency across iOS app, admin dashboard, and backend

---

## System Architecture

### Component Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     iOS Application                          │
│                   (Future Integration)                       │
└────────────────────┬────────────────────────────────────────┘
                     │
                     │ Uses
                     ▼
┌──────────────────────────────────────────────────────────────┐
│            Express.js Backend API (Node.js)                  │
│  /api/admin/interests/* (CRUD Operations)                    │
└────────────┬─────────────────────────────┬──────────────────┘
             │                             │
             ▼                             ▼
  ┌──────────────────────┐      ┌─────────────────────┐
  │   Firestore         │      │  Firebase Admin SDK  │
  │  (interests         │      │  (Authentication)    │
  │   collection)       │      │                     │
  └──────────────────────┘      └─────────────────────┘
             ▲
             │ Displays/Manages
             │
┌────────────┴────────────────────────────────────────────────┐
│              Vue.js Admin Dashboard                          │
│         /admin/interests (Management UI)                     │
└──────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **Admin Creates/Updates Interest** → Dashboard (Vue) → API Endpoint → Firestore
2. **Dashboard Displays Interests** → API Endpoint → Firestore → Dashboard (Vue)
3. **iOS App Fetches Interests** → API Endpoint → Firestore → iOS App
4. **Hierarchy Management** → Parent-child relationships maintained via `parentId` and `path`

---

## Database Schema

### Firestore Collection: `interests`

**Document ID:** `{interest-name}` (lowercase, hyphenated, e.g., `fashion-basics`)

#### Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `id` | string | Unique identifier (same as doc ID) | `fashion-basics` |
| `name` | string | Internal name | `fashion-basics` |
| `displayName` | string | User-facing name | `Fashion Basics` |
| `parentId` | string or null | Parent interest ID (null for root) | `fashion` or `null` |
| `level` | number | Depth in hierarchy (0 = root) | `0`, `1`, `2` |
| `path` | array[string] | Full path from root to this interest | `["fashion", "fashion-basics"]` |
| `description` | string or null | Detailed description | `Basic fashion and style essentials` |
| `coverImageUrl` | string or null | Cover image URL | `https://...` |
| `isActive` | boolean | Active/inactive status | `true` or `false` |
| `createdAt` | Timestamp | Creation timestamp | Auto-set by server |
| `updatedAt` | Timestamp | Last update timestamp | Auto-set by server |
| `keywords` | array[string] | Searchable keywords | `["fashion", "style", "clothing"]` |
| `synonyms` | array[string] | Alternative names | `["apparel", "dress code"]` |
| `postCount` | number | Total posts in this interest | `0` |
| `followerCount` | number | Total followers | `0` |
| `weeklyGrowth` | number | Weekly growth percentage | `0.0` |
| `monthlyGrowth` | number | Monthly growth percentage | `0.0` |
| `relatedInterestIds` | array[string] | Related interest IDs for recommendations | `["travel", "photography"]` |

#### Example Document

```json
{
  "id": "fashion-basics",
  "name": "fashion-basics",
  "displayName": "Fashion Basics",
  "parentId": "fashion",
  "level": 1,
  "path": ["fashion", "fashion-basics"],
  "description": "Essential fashion items and basic style tips",
  "coverImageUrl": null,
  "isActive": true,
  "createdAt": 1701637421000,
  "updatedAt": 1701637421000,
  "keywords": ["fashion", "basics", "style", "clothing"],
  "synonyms": ["basic fashion", "essential wear"],
  "postCount": 0,
  "followerCount": 0,
  "weeklyGrowth": 0.0,
  "monthlyGrowth": 0.0,
  "relatedInterestIds": ["fashion-accessories", "style-tips"]
}
```

### Hierarchy Rules

- **Root Interests:** `parentId = null`, `level = 0`
- **Sub-interests:** `parentId` references parent document ID, `level = parent.level + 1`
- **Path Tracking:** Always contains full hierarchy path (e.g., `["fashion", "fashion-basics", "casual"]`)
- **Max Depth:** No hard limit (recommend keeping to 3-4 levels for UX)

---

## API Endpoints

### Base URL
```
/api/admin/interests
```

### Authentication
All endpoints require:
- Valid Firebase authentication token
- `super_admin` role
- Rate limiting applied

### Endpoints

#### 1. **GET /api/admin/interests**
Retrieve interests with optional filtering

**Query Parameters:**
| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `parentId` | string | No | Filter by parent interest ID |
| `level` | number | No | Filter by hierarchy level |

**Response:**
```json
{
  "success": true,
  "interests": [
    {
      "id": "fashion",
      "name": "fashion",
      "displayName": "Fashion",
      "parentId": null,
      "level": 0,
      "path": ["fashion"],
      "keywords": ["fashion", "style"],
      "isActive": true,
      "createdAt": 1701637421000,
      "updatedAt": 1701637421000
    }
  ],
  "count": 10
}
```

**Example Requests:**
```bash
# Get all root interests
GET /api/admin/interests

# Get sub-interests of 'fashion'
GET /api/admin/interests?parentId=fashion

# Get level 1 interests
GET /api/admin/interests?level=1
```

---

#### 2. **GET /api/admin/interests/tree**
Retrieve complete interest taxonomy as a hierarchical tree

**Query Parameters:**
| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `maxDepth` | number | No | Limit tree depth (null = no limit) |

**Response:**
```json
{
  "success": true,
  "tree": [
    {
      "id": "fashion",
      "displayName": "Fashion",
      "level": 0,
      "children": [
        {
          "id": "fashion-basics",
          "displayName": "Fashion Basics",
          "level": 1,
          "children": []
        }
      ]
    }
  ]
}
```

**Example Request:**
```bash
# Get full tree
GET /api/admin/interests/tree

# Get tree limited to 2 levels
GET /api/admin/interests/tree?maxDepth=2
```

---

#### 3. **POST /api/admin/interests**
Create a new interest

**Request Body:**
```json
{
  "name": "fashion-basics",
  "displayName": "Fashion Basics",
  "parentId": "fashion",
  "description": "Basic fashion essentials",
  "keywords": ["fashion", "basics", "style"],
  "synonyms": ["basic wear"]
}
```

**Validation:**
- `name` (required): unique, lowercase, hyphens only
- `displayName` (required): user-friendly name
- `parentId` (optional): must reference existing interest
- `description`, `keywords`, `synonyms` (optional)

**Response:**
```json
{
  "success": true,
  "message": "Interest created successfully",
  "interest": {
    "id": "fashion-basics",
    "name": "fashion-basics",
    "displayName": "Fashion Basics",
    "level": 1,
    "path": ["fashion", "fashion-basics"]
  }
}
```

**Logic:**
- Auto-calculates `level` and `path` based on parent
- Sets `isActive = true` by default
- Initializes metrics (`postCount`, `followerCount`, etc.) to 0
- Document ID is auto-generated from `name`

---

#### 4. **PUT /api/admin/interests/:id**
Update an existing interest

**URL Parameter:**
| Param | Type | Description |
|-------|------|-------------|
| `id` | string | Interest ID to update |

**Request Body (all optional):**
```json
{
  "displayName": "Updated Display Name",
  "description": "Updated description",
  "keywords": ["updated", "keywords"],
  "synonyms": ["updated", "synonym"],
  "isActive": true
}
```

**Response:**
```json
{
  "success": true,
  "message": "Interest updated successfully"
}
```

**Notes:**
- Cannot change `name`, `parentId`, `level`, or `path` (structural integrity)
- `updatedAt` timestamp auto-updated
- Partial updates allowed

---

#### 5. **DELETE /api/admin/interests/:id**
Soft delete an interest (deactivate)

**URL Parameter:**
| Param | Type | Description |
|-------|------|-------------|
| `id` | string | Interest ID to deactivate |

**Response:**
```json
{
  "success": true,
  "message": "Interest deactivated successfully"
}
```

**Behavior:**
- Sets `isActive = false`
- Preserves data (soft delete)
- Interest won't appear in active queries
- Can be reactivated via PUT endpoint

---

#### 6. **POST /api/admin/interests/seed**
Initialize taxonomy with base interests

**Request Body:** None

**Response:**
```json
{
  "success": true,
  "message": "Seeded 10 base interests",
  "count": 10
}
```

**Base Interests Seeded:**
1. Fashion
2. Beauty
3. Food & Dining
4. Fitness
5. Home & Decor
6. Travel
7. Photography
8. Entertainment
9. Technology
10. Pets

**Notes:**
- Only runs if collection is empty
- Returns error if interests already exist
- Super admin only
- Sets all to `level: 0` and `parentId: null`

---

## Frontend Implementation

### Admin Dashboard (`admin-dashboard/pages/Interests.vue`)

#### Features
- **Browse Taxonomy:** Tree view of all interests
- **Create Interests:** Modal form for new interests
- **Edit Interests:** Inline editing of display name, description, keywords
- **Delete Interests:** Soft delete with confirmation
- **Add Sub-interests:** Create child interests under parent
- **Seed Base:** Initialize with default taxonomy
- **Search/Filter:** Filter by parent or level

#### Component Structure
```
Interests.vue (Main Page)
├── AppHeader (Navigation)
├── InterestItem (Recursive, displays tree)
│   └── Children InterestItems (nested)
├── Create Modal (Form)
├── Edit Modal (Form)
└── Success/Error Alerts
```

#### Key Methods

| Method | Purpose |
|--------|---------|
| `loadInterests()` | Fetch root interests from API |
| `submitCreateInterest()` | Validate and POST new interest |
| `submitEditInterest()` | PUT updates to existing interest |
| `deleteInterestItem()` | Soft delete via DELETE endpoint |
| `seedInterests()` | POST to seed base interests |
| `showCreateChildModal()` | Pre-populate parent for sub-interest |

#### Form Handling
- Keywords/synonyms parsed from comma-separated text
- Auto-generates lowercase hyphenated ID from name
- Parent selection implicit via "Add Child" action
- Confirmation dialogs for destructive actions

---

### Frontend Service Layer (`admin-dashboard/composables/interestService.js`)

#### Composable Functions

```javascript
// Get interests with optional filters
getInterests(parentId = null, level = null)

// Get complete taxonomy tree
getInterestTree(maxDepth = null)

// Create new interest
createInterest(data)

// Update existing interest
updateInterest(id, data)

// Delete/deactivate interest
deleteInterest(id)

// Seed base interests
seedInterests()
```

#### Error Handling
- API errors caught and displayed as user messages
- Network timeouts handled gracefully
- Validation errors shown in-form
- Success messages auto-dismiss after 3 seconds

---

## Backend Implementation

### API Routes (`server/src/routes/admin.js`)

#### Route Structure
```
POST   /api/admin/interests/seed      → seedInterests()
GET    /api/admin/interests/tree      → getInterestTree()
GET    /api/admin/interests           → getInterests()
POST   /api/admin/interests           → createInterest()
PUT    /api/admin/interests/:id       → updateInterest()
DELETE /api/admin/interests/:id       → deleteInterest()
```

#### Middleware
- `protect`: Firebase auth required
- `requireRole('super_admin')`: Authorization check
- `apiRateLimiter`: Rate limiting

#### Firestore Integration
- Direct Firestore SDK (`admin.firestore()`)
- Batch writes for seeding
- Server-side timestamps
- Soft delete pattern (sets `isActive: false`)

---

## Data Consistency & Validation

### Creation Constraints
1. **Unique Names:** Interest IDs must be unique
2. **Parent Exists:** Referenced parent must exist in Firestore
3. **Hierarchy Level:** Calculated from parent, never set directly
4. **Path Integrity:** Always reflects parent chain

### Update Constraints
1. **Structural Fields Immutable:** Cannot change `name`, `parentId`, `level`, `path`
2. **Active Status:** Can only deactivate via DELETE or PUT update
3. **Timestamps:** Always updated server-side

### Validation Rules
| Field | Rules |
|-------|-------|
| `name` | Required, unique, lowercase, hyphens only |
| `displayName` | Required, 1-255 chars |
| `parentId` | Optional, must exist if provided |
| `description` | Optional, 0-1000 chars |
| `keywords` | Optional array, strings only |
| `synonyms` | Optional array, strings only |

---

## Usage Examples

### Create Root Interest
```bash
curl -X POST http://localhost:3000/api/admin/interests \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "travel",
    "displayName": "Travel",
    "keywords": ["travel", "destination", "adventure"],
    "description": "Travel and adventure content"
  }'
```

### Create Sub-interest
```bash
curl -X POST http://localhost:3000/api/admin/interests \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "beach-destinations",
    "displayName": "Beach Destinations",
    "parentId": "travel",
    "keywords": ["beach", "tropical", "ocean"],
    "description": "Beautiful beach travel destinations"
  }'
```

### Get Complete Taxonomy Tree
```bash
curl -X GET "http://localhost:3000/api/admin/interests/tree" \
  -H "Authorization: Bearer {token}"
```

### Update Interest
```bash
curl -X PUT http://localhost:3000/api/admin/interests/travel \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{
    "displayName": "Travel & Adventure",
    "keywords": ["travel", "destination", "adventure", "explore"]
  }'
```

### Deactivate Interest
```bash
curl -X DELETE http://localhost:3000/api/admin/interests/travel \
  -H "Authorization: Bearer {token}"
```

---

## iOS Integration (Future)

### Planned Integration Points

1. **Interest Discovery**
   - User sees interest taxonomy on onboarding
   - Can select multiple interests during signup

2. **User Interests Storage**
   - Store user's selected interests in Firestore
   - `users/{userId}/interests` subcollection

3. **Content Discovery**
   - Filter posts by user's selected interests
   - Recommend content based on interests

4. **Profile Display**
   - Show user's interests on profile
   - Allow users to update interests

### API Usage on iOS
- Fetch interests tree on app launch
- Cache locally with periodic refresh
- Use for UI population and content filtering

---

## Performance Considerations

### Current Optimization

| Strategy | Implementation |
|----------|-----------------|
| Tree Building | In-memory object references |
| Filtering | Firestore where clauses |
| Batch Operations | Firestore batch writes |
| Caching | Client-side Vue/Firebase cache |
| Ordering | `orderBy('name')` for predictable results |

### Scalability

- **Expected Scale:** 100-1000 interests initially
- **Sub-interests:** 5-10 levels deep (recommend 3-4)
- **Growth Metric:** Root interests to subcategories ratio of 1:5

### Recommended Indices

Currently auto-managed by Firestore, but manually create if needed:
```
Collection: interests
  - (parentId, name)
  - (level, isActive)
  - (isActive, name)
```

---

## Security & Access Control

### Role-Based Access

| Action | Required Role |
|--------|---------------|
| View interests | Any authenticated user (future) |
| Create/Edit/Delete | `super_admin` only |
| Seed interests | `super_admin` only |

### Current Implementation

All endpoints guarded by:
```javascript
router.use(protect);              // Firebase auth required
router.use(apiRateLimiter);       // Rate limited
requireRole('super_admin')        // Super admin only
```

### Future Considerations

- Add `viewer` role for read-only access
- Add `moderator` role for category moderation
- Implement interest-specific permissions
- Audit logging for admin actions

---

## Error Handling

### Common Error Scenarios

| Scenario | HTTP Code | Response |
|----------|-----------|----------|
| Not authenticated | 401 | `Unauthorized` |
| Not authorized | 403 | `Forbidden` |
| Parent not found | 404 | `Parent interest not found` |
| Interests already seeded | 400 | `Interests already seeded` |
| Validation error | 400 | `name and displayName are required` |
| Server error | 500 | `{error message}` |

### Client Error Handling

Dashboard displays:
- Error messages in red banner
- Success messages in green banner
- Loading states during async operations
- Confirmation dialogs for destructive actions

---

## Testing

### Manual Testing Checklist

- [ ] Seed base interests (10 items created)
- [ ] Create root interest
- [ ] Create sub-interest with parent
- [ ] View full taxonomy tree
- [ ] Edit interest (name, description, keywords)
- [ ] Delete/deactivate interest
- [ ] Verify soft delete (not removed from DB)
- [ ] Filter interests by parent
- [ ] Filter interests by level
- [ ] Verify authorization (non-admin cannot modify)

### Recommended Unit Tests

```
Backend (Node.js):
  - createInterest: valid data, missing required fields, parent not found
  - updateInterest: valid updates, immutable fields
  - deleteInterest: soft delete verification
  - getInterests: filtering by parentId and level
  - getInterestTree: tree structure, max depth

Frontend (Vue):
  - Load interests from API
  - Submit create form with validation
  - Edit and submit updates
  - Delete confirmation flow
  - Seed confirmation and execution
```

---

## Deployment Notes

### Environment Variables
None required for interests system specifically. Uses existing:
- `FIREBASE_PROJECT_ID`
- `FIREBASE_PRIVATE_KEY`
- `FIREBASE_CLIENT_EMAIL`

### Database Setup
No migrations needed. Firestore auto-creates collection on first write.

### First Deployment
1. Deploy API endpoints (backend)
2. Deploy admin dashboard (frontend)
3. Admin user seeds base interests via UI button
4. System ready for use

---

## Maintenance & Monitoring

### Key Metrics to Track

- Total interests count
- Active vs inactive interests
- Hierarchy depth distribution
- Most used interests (by post count)
- Interest growth trends

### Regular Maintenance

- Monitor for inactive interests (consider cleanup)
- Update growth metrics periodically
- Audit interest hierarchies for organization
- Review and update keywords/synonyms

### Common Tasks

**Add New Interest Category:**
1. Admin dashboard → Create Interest
2. Fill form (name, displayName, etc.)
3. Select parent (optional)
4. Submit

**Reorganize Hierarchy:**
1. Currently: Must delete and recreate (due to immutable parentId)
2. Future enhancement: Allow reparenting

**Bulk Updates:**
1. Export interests data
2. Prepare changes
3. Import via seed or batch admin script

---

## Glossary

- **Interest:** A category representing a topic of user interest (e.g., "Fashion")
- **Taxonomy:** The hierarchical structure of all interests
- **Root Interest:** Top-level interest with no parent (level 0)
- **Sub-interest:** Interest with a parent (level > 0)
- **Path:** Full hierarchy chain from root to current interest
- **Soft Delete:** Deactivating data instead of removing it
- **Display Name:** User-facing name shown in UI
- **Keywords:** Searchable terms associated with interest
- **Synonyms:** Alternative names for the interest

---

## Related Documentation

- [Admin System Architecture](./ADMIN_SYSTEM_ARCHITECTURE.md)
- [Backend Patterns](./BACKEND_PATTERN.md)
- [Dashboard Patterns](./DASHBOARD_PATTERN.md)
- [Firestore Rules](../setup/FIRESTORE_RULES_SETUP.md)

---

## Future Enhancements

1. **Interest Reparenting:** Allow moving interests to different parents
2. **Bulk Operations:** Import/export interests, batch updates
3. **Interest Analytics:** Enhanced metrics and trending
4. **Auto-tagging:** ML-based interest suggestion for content
5. **User Interest Sync:** Mobile app integration for user preferences
6. **Interest Search:** Full-text search with fuzzy matching
7. **Cover Images:** Upload and manage interest cover photos
8. **Related Interests:** Intelligent recommendations
9. **A/B Testing:** Test different interest taxonomies
10. **Deprecation:** Graceful retirement of old interests

---

**Last Updated:** December 3, 2024  
**Author:** Development Team  
**Status:** Active
