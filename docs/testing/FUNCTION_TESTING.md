# Firebase Functions Testing Guide

## Deployed Functions

The following functions have been successfully deployed:

1. **`aggregateActivity`** - Aggregates user activities to multiple feeds (discover:global, category feeds) server-side
2. **`addToDiscover`** - Legacy function for adding activities to discover:global (backwards compatibility)
3. **`onFollowCreated`** - Firestore trigger that mirrors follow relationships to Stream feeds
4. **`onFollowDeleted`** - Firestore trigger that mirrors unfollow relationships to Stream feeds

## Testing the aggregateActivity Function

### From iOS App

The function is automatically called when a user uploads an image. The client code:
1. Posts to user's own feed (user:{userId})
2. Calls `aggregateActivity` function with activity data
3. Function uses server-side credentials to post to discover:global and category feeds

### Manual Testing via Firebase Console

1. Go to Firebase Console → Functions
2. Find `aggregateActivity` function
3. Click "Test" tab
4. Use this test payload:

```json
{
  "data": {
    "activityData": {
      "type": "post",
      "text": "Test post description",
      "custom": {
        "post_id": "test-post-123",
        "title": "Test Post",
        "image_url": "https://example.com/image.jpg",
        "thumbnail_url": "https://example.com/thumb.jpg",
        "categories": ["nature", "abstract"]
      },
      "filterTags": ["tag1", "tag2", "tag3"]
    }
  }
}
```

### Testing via curl (requires auth token)

```bash
# Get your Firebase auth token first, then:
curl -X POST \
  https://us-central1-angles-423a4.cloudfunctions.net/aggregateActivity \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_FIREBASE_AUTH_TOKEN" \
  -d '{
    "data": {
      "activityData": {
        "type": "post",
        "text": "Test post",
        "custom": {
          "post_id": "test-123",
          "title": "Test",
          "image_url": "https://example.com/image.jpg",
          "thumbnail_url": "https://example.com/thumb.jpg",
          "categories": ["nature"]
        },
        "filterTags": ["tag1", "tag2", "tag3"]
      }
    }
  }'
```

## Testing Follow Functions

### Create a Follow Document

1. Go to Firestore Console
2. Create a document in `follows` collection:
   - Document ID: auto-generated
   - Fields:
     - `followerId`: "user123"
     - `followingId`: "user456"
3. The `onFollowCreated` function should automatically:
   - Create follow relationship: `timeline:user123` → `user:user456`
   - Create follow relationship: `foryou:user123` → `user:user456`

### Delete a Follow Document

1. Delete the follow document from Firestore
2. The `onFollowDeleted` function should automatically:
   - Remove follow relationship: `timeline:user123` -X→ `user:user456`
   - Remove follow relationship: `foryou:user123` -X→ `user:user456`

## Viewing Function Logs

### Via Firebase Console
1. Go to Firebase Console → Functions
2. Click on a function name
3. Click "Logs" tab to see execution logs

### Via CLI
```bash
firebase functions:log
```

### View specific function logs
```bash
firebase functions:log --only aggregateActivity
```

## Expected Behavior

### Successful Aggregation
- Activity is posted to user feed ✅
- Activity is aggregated to `discover:global` ✅
- Activity is aggregated to category feeds (e.g., `discover:nature`) if categories exist ✅
- Function returns: `{ ok: true, successCount: 1, failCount: 0 }`

### Error Handling
- If aggregation fails, the function logs the error but doesn't fail the upload
- The activity remains in the user feed even if aggregation fails
- Check function logs for specific error messages

## Troubleshooting

### Permission Errors (403)
- Verify Stream API key and secret are set correctly in function environment
- Check that Stream API key matches the one used in the iOS app (Config.swift)

### Feed Group Not Found
- Ensure feed groups (`discover`, `timeline`, `foryou`) exist in Stream Dashboard
- Create missing feed groups at: https://dashboard.getstream.io/

### Function Timeout
- Default timeout is 60 seconds
- Increase timeout if needed in function configuration

### API Version Mismatch
- All functions use Stream API v2 (`/api/v2/`)
- Verify endpoints match Stream API v2 documentation

## Next Steps

1. Test image upload from iOS app
2. Verify activity appears in:
   - User feed: `user:{userId}`
   - Discover feed: `discover:global`
   - Category feeds: `discover:{category}` (if applicable)
3. Check function logs for any errors
4. Monitor function execution times and costs

























