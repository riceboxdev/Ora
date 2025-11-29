# Firestore Collections Analysis

This document identifies all Firestore collections used in the OraBeta project and flags potentially unused collections.

## ✅ Actively Used Collections

### Core Collections
1. **`users`** - User profiles and authentication data
   - Used in: iOS app, admin backend, Cloud Functions
   - Status: ✅ **ACTIVE** - Core collection

2. **`posts`** - User posts/content
   - Used in: iOS app, admin backend, Cloud Functions
   - Status: ✅ **ACTIVE** - Core collection

3. **`follows`** - Follow relationships between users
   - Used in: iOS app (FollowService), Firestore rules
   - Status: ✅ **ACTIVE**

4. **`user_stats`** - User statistics (follower/following counts)
   - Used in: iOS app (FollowService), Firestore rules
   - Status: ✅ **ACTIVE**

### Social Features
5. **`boards`** - Pinterest-style boards
   - Used in: iOS app (BoardService), Firestore rules
   - Status: ✅ **ACTIVE**

6. **`board_posts`** - Posts saved to boards
   - Used in: iOS app (BoardService, AccountService), Firestore rules
   - Status: ✅ **ACTIVE**

7. **`likes`** - Post likes
   - Used in: iOS app (AccountService, UserPreferenceService), Firestore rules
   - Status: ✅ **ACTIVE**

8. **`comments`** - Post comments
   - Used in: iOS app (AccountService, UserPreferenceService), Firestore rules
   - Status: ✅ **ACTIVE**

9. **`post_interactions`** - User interactions with posts (views, clicks, shares)
   - Used in: iOS app (UserPreferenceService), Cloud Functions, Firestore rules
   - Status: ✅ **ACTIVE**

### Content Discovery
10. **`tags`** - Centralized tag management
    - Used in: Cloud Functions (index.ts), Firestore rules
    - Status: ✅ **ACTIVE**

11. **`trending_topics`** - Cached trending topics
    - Used in: Cloud Functions (index.ts), Firestore rules
    - Status: ✅ **ACTIVE**

### Stories
12. **`stories`** - User stories that expire after 24 hours
    - Used in: iOS app (StoryService, StoryRepository), Firestore rules
    - Status: ✅ **ACTIVE**

### Moderation & Admin
13. **`post_reports`** - Post reports from users
    - Used in: Admin backend (reports.js), Admin SDK
    - Status: ✅ **ACTIVE** - Recently added

14. **`moderation_actions`** - Moderation actions taken by admins
    - Used in: Cloud Functions (index.ts), iOS app (ModerationService)
    - Status: ✅ **ACTIVE**

15. **`system_settings`** - System-wide settings
    - Used in: Admin backend (admin.js), Cloud Functions
    - Status: ✅ **ACTIVE**

### User Preferences
16. **`account_settings`** - User account preferences and settings
    - Used in: iOS app (AccountService), Firestore rules
    - Status: ✅ **ACTIVE**

17. **`blocked_users`** - User blocking relationships
    - Used in: iOS app (AccountService), Firestore rules
    - Status: ✅ **ACTIVE**

### Notifications
18. **`notifications`** - User notifications (subcollection under `users/{userId}/notifications`)
    - Used in: Cloud Functions (notifications.ts), iOS app (NotificationManager)
    - Status: ✅ **ACTIVE**

## ⚠️ Potentially Unused Collections

### Legacy/Unused Collections
1. **`collections`** - Legacy wallpaper collections
   - **Status**: ⚠️ **POTENTIALLY UNUSED**
   - **Evidence**: 
     - Marked as "legacy" in Firestore rules (line 35: `// Collections collection - wallpaper collections (legacy)`)
     - No code references found in codebase search
     - Still has Firestore rules defined
   - **Recommendation**: 
     - Check Firebase Console to see if it has any documents
     - If empty, consider removing Firestore rules for this collection
     - If it has data, verify if it's still needed or can be migrated

2. **`feeds`** - For Stream Firebase Extension (wallpapers)
   - **Status**: ⚠️ **POTENTIALLY UNUSED**
   - **Evidence**:
     - Has Firestore rules defined (lines 108-136)
     - No code references found in codebase search
     - Comment mentions "wallpapers for Stream Firebase Extension"
   - **Recommendation**:
     - Check Firebase Console to see if it has any documents
     - Check if Stream Firebase Extension is still active
     - If not using Stream Extension, consider removing rules

## 📊 Summary

- **Total Collections Found**: 20
- **Actively Used**: 18
- **Potentially Unused**: 2

## 🔍 How to Verify Unused Collections

1. **Check Firebase Console**:
   - Go to Firestore Database
   - Check if `collections` and `feeds` have any documents
   - Check document counts and last modified dates

2. **Check Stream Extension**:
   - Go to Firebase Extensions
   - Verify if Stream Firebase Extension is installed/active
   - If not, `feeds` collection is likely unused

3. **Check Analytics**:
   - Review Firestore usage metrics
   - Collections with zero reads/writes are likely unused

## 🗑️ Safe to Remove (if confirmed unused)

If the following collections are confirmed to be unused:

1. **`collections`** - Remove Firestore rules (lines 35-44 in firestore.rules)
2. **`feeds`** - Remove Firestore rules (lines 108-136 in firestore.rules)

**Note**: Always backup your Firestore data before removing any collections or rules.

## 📝 Collections Not Found in Codebase

If you see collections in Firebase Console that are NOT listed above, they may be:
- Legacy collections from previous versions
- Test/development collections
- Collections created by Firebase Extensions
- Collections from other projects

Consider reviewing and cleaning up any unlisted collections.













