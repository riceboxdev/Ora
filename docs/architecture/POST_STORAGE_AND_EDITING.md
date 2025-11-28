# Post Storage and Editing Implementation

## Overview
All posts are now stored in both Firebase Firestore and Stream feeds. Post editing functionality has been added that updates both locations (with Firestore as the source of truth).

## Implementation Details

### 1. Post Creation (`createPost`)
- **Location**: `functions/src/index.ts`
- **Changes**: 
  - Posts are now saved to Firestore after successful creation in Stream
  - Firestore document ID is the Stream activity ID
  - Post data includes: `activityId`, `userId`, `imageUrl`, `thumbnailUrl`, `caption`, `tags`, `categories`, `createdAt`, `updatedAt`, `foreignId`, `targetFeeds`
  - If Firestore save fails, the post is still created in Stream (non-blocking)

### 2. Post Editing (`editPost`)
- **Location**: `functions/src/index.ts`
- **Features**:
  - Updates posts in Firestore
  - Marks posts as `edited: true` in Firestore
  - Only post owners can edit their posts
  - Updates `caption`, `tags`, and `categories`
  - **Note**: Stream activities are immutable, so we only update Firestore. The app should prioritize Firestore data when displaying posts.

### 3. Migration Functions
- **Location**: `functions/src/index.ts`
- **Functions**:
  - `migratePostsToFirestore`: Migrates posts for a specific user (or current user)
  - `migrateAllPostsToFirestore`: Migrates all posts from discover feed (admin only)
- **Features**:
  - Reads activities from Stream feeds
  - Saves them to Firestore
  - Marks migrated posts with `migrated: true`
  - Preserves existing `edited` flag if present
  - Handles errors gracefully

### 4. iOS Integration
- **StreamService.swift**: Added `editPost` method and migration methods
- **PostService.swift**: Added `editPost` method that calls StreamService

### 5. Firestore Security Rules
- **Location**: `firestore.rules`
- **Rules**:
  - Anyone authenticated can read posts (public posts)
  - Only server-side functions can create/update/delete posts
  - Posts are managed exclusively through Firebase Functions

## Firestore Post Schema

```typescript
{
  activityId: string;          // Stream activity ID (document ID)
  userId: string;              // Post owner user ID
  imageUrl: string;            // Full image URL
  thumbnailUrl: string;        // Thumbnail URL
  caption: string | null;      // Post caption
  tags: string[];              // Post tags
  categories: string[];        // Post categories
  createdAt: Timestamp;        // Creation timestamp
  updatedAt: Timestamp;        // Last update timestamp
  foreignId: string;           // Stream foreign_id
  targetFeeds: string[];       // Feeds this post was distributed to
  edited?: boolean;            // Whether post was edited
  migrated?: boolean;          // Whether post was migrated from Stream
}
```

## Usage

### Creating a Post
Posts are automatically saved to both Stream and Firestore when created via the `createPost` function.

### Editing a Post
```swift
// In iOS app
let postService = PostService(streamService: streamService, profileService: profileService)
try await postService.editPost(
    activityId: "activity-id",
    caption: "Updated caption",
    tags: ["tag1", "tag2"],
    categories: ["category1"]
)
```

### Migrating Existing Posts
```swift
// Migrate current user's posts
let result = try await streamService.migratePostsToFirestore()

// Migrate all posts (admin only)
let result = try await streamService.migrateAllPostsToFirestore()
```

## Important Notes

1. **Stream Activities are Immutable**: Stream activities cannot be updated directly without losing engagement data (likes, comments). Therefore, edits only update Firestore, and the app should prioritize Firestore data when displaying posts.

2. **Firestore as Source of Truth**: Firestore is the authoritative source for post data. When displaying posts, the app should:
   - Check Firestore first for post data
   - Fall back to Stream data if Firestore data is not available
   - Use Firestore data for edited posts

3. **Migration**: The migration functions can be used to backfill existing Stream posts into Firestore. This should be run once to migrate existing posts.

4. **Security**: All post writes (create/update/delete) are handled server-side through Firebase Functions. Client-side code cannot directly write to the posts collection.

## Next Steps

1. **Update Post Display Logic**: Modify the app to prioritize Firestore data when displaying posts
2. **Add Edit UI**: Create UI for editing posts (caption, tags, categories)
3. **Run Migration**: Run the migration functions to migrate existing posts to Firestore
4. **Test**: Test post creation, editing, and migration thoroughly

## Deployment

1. Deploy Firebase Functions:
   ```bash
   cd functions
   npm run build
   firebase deploy --only functions
   ```

2. Deploy Firestore Rules:
   ```bash
   firebase deploy --only firestore:rules
   ```

3. Test the functions:
   - Create a post and verify it's saved to Firestore
   - Edit a post and verify it's updated in Firestore
   - Run migration to migrate existing posts
















