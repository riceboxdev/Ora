# Firestore Security Rules Setup

This document explains how to set up Firestore security rules for the OraBeta app.

## Quick Setup

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Navigate to **Firestore Database** → **Rules** tab
4. Copy the contents of `firestore.rules` file in this repository
5. Paste into the rules editor
6. Click **Publish**

## Rules Overview

### Follows Collection (`/follows/{followId}`)
- **Read**: Any authenticated user can read follows (needed to check follow status)
- **Create**: Users can only create follows where they are the follower
- **Delete**: Users can only delete their own follows
- **Update**: Not allowed (delete and recreate instead)

### User Stats Collection (`/user_stats/{userId}`)
- **Read**: Any authenticated user can read stats (public follower/following counts)
- **Write**: Authenticated users can update stats (used by FollowService transactions)

### Users Collection (`/users/{userId}`)
- **Read**: Any authenticated user can read user profiles (public information)
- **Create/Update**: Users can only create/update their own profile
- **Delete**: Users can only delete their own profile

### Collections Collection (`/collections/{collectionId}`)
- **Read**: Public collections are readable by all, private collections only by owner
- **Write**: Users can only create/update/delete their own collections

## Testing Rules

After publishing rules, test them in the Firebase Console:
1. Go to **Firestore Database** → **Rules** tab
2. Click **Rules Playground**
3. Test various scenarios to ensure rules work as expected

## Production Considerations

For production, you may want to:
- Add rate limiting for write operations
- Restrict `user_stats` writes to server-side only (via Cloud Functions)
- Add more granular permissions for user profiles
- Consider caching strategies for frequently accessed data

























