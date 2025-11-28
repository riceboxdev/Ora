# Unused Firebase Functions Analysis

## Functions Currently Used

### Called from iOS App:
1. ✅ `ensureStreamUser` - Called from AuthViewModel
2. ✅ `testStreamFeeds` - Called from StreamService
3. ✅ `createPost` - Called from StreamService
4. ✅ `trackEngagement` - Called from StreamService
5. ✅ `analyzeFeatures` - Called from StreamService
6. ✅ `getPersonalizedFeed` - Called from StreamService
7. ✅ `getFollowRecommendations` - Called from StreamService
8. ✅ `getFeedActivities` - Called from StreamService
9. ✅ `addReaction` - Called from StreamService (likes)
10. ✅ `removeReaction` - Called from StreamService (unlikes)
11. ✅ `checkReaction` - Called from StreamService (check if liked)
12. ✅ `generateCloudinarySignature` - Called from ImageUploadService

### Auto-triggered (Firestore/Auth triggers):
13. ✅ `onFollowCreated` - Firestore trigger when follow is created
14. ✅ `onFollowDeleted` - Firestore trigger when follow is deleted
15. ✅ `onNotificationCreated` - Firestore trigger when notification is created (FCM push)

---

## Functions NOT Used (Can be removed)

### 1. ❌ `listFeedGroups`
- **Location**: Line 272
- **Purpose**: Lists all feed groups
- **Status**: Not called from iOS app or other functions
- **Recommendation**: **SAFE TO DELETE** (unless used for admin/debugging)

### 2. ❌ `createFeedGroup`
- **Location**: Line 285
- **Purpose**: Creates a new feed group
- **Status**: Not called from iOS app or other functions
- **Recommendation**: **SAFE TO DELETE** (unless used for admin/debugging)

### 3. ❌ `updateFeedGroup`
- **Location**: Line 303
- **Purpose**: Updates a feed group
- **Status**: Not called from iOS app or other functions
- **Recommendation**: **SAFE TO DELETE** (unless used for admin/debugging)

### 4. ❌ `deleteFeedGroup`
- **Location**: Line 314
- **Purpose**: Deletes a feed group
- **Status**: Not called from iOS app or other functions
- **Recommendation**: **SAFE TO DELETE** (unless used for admin/debugging)

### 5. ❌ `aggregateActivity`
- **Location**: Line 436
- **Purpose**: Aggregates activities (legacy function)
- **Status**: Not called from iOS app. `createPost` handles aggregation via Stream's 'to' field
- **Recommendation**: **SAFE TO DELETE** (replaced by `createPost`)

### 6. ❌ `postActivityToUserFeed`
- **Location**: Line 538
- **Purpose**: Posts activity to user feed (legacy function)
- **Status**: Not called from iOS app. `createPost` handles this
- **Recommendation**: **SAFE TO DELETE** (replaced by `createPost`)

### 7. ❌ `verifyStreamFeed`
- **Location**: Line 697
- **Purpose**: Verifies if a Stream feed exists
- **Status**: Not called from iOS app or other functions
- **Recommendation**: **SAFE TO DELETE** (or keep for debugging if needed)

### 8. ❌ `addToDiscover`
- **Location**: Line 842
- **Purpose**: Adds activity to discover feed (legacy function)
- **Status**: Not called from iOS app. `createPost` handles this via 'to' field
- **Recommendation**: **SAFE TO DELETE** (replaced by `createPost`)

### 9. ❌ `markNotificationsRead`
- **Location**: Line 2150
- **Purpose**: Marks Stream notifications as read (DEPRECATED)
- **Status**: Marked as deprecated. Old Stream notification system replaced with Firestore
- **Recommendation**: **SAFE TO DELETE** (already deprecated, replaced by Firestore updates)

---

## Summary

**Total Functions**: 25
**Used Functions**: 15 (12 called from iOS + 3 triggers)
**Unused Functions**: 9

### Recommended Actions:

1. **Immediate deletion** (definitely unused):
   - `aggregateActivity`
   - `postActivityToUserFeed`
   - `addToDiscover`
   - `markNotificationsRead`

2. **Consider deletion** (may be used for admin/debugging):
   - `listFeedGroups`
   - `createFeedGroup`
   - `updateFeedGroup`
   - `deleteFeedGroup`
   - `verifyStreamFeed`

3. **Keep** (actively used):
   - All 12 functions called from iOS app
   - 3 trigger functions (onFollowCreated, onFollowDeleted, onNotificationCreated)

### Notes:
- The feed group management functions (`listFeedGroups`, `createFeedGroup`, etc.) might be useful for admin operations or future features
- `verifyStreamFeed` might be useful for debugging
- All other unused functions appear to be legacy code from before the `createPost` function was created





















