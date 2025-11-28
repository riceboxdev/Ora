# Verifying Stream Firebase Extension is Working

This guide will help you verify that the Stream Activity Feeds Firebase Extension is properly installed and syncing Firestore documents to Stream.

## Method 1: Check Extension Status in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Navigate to **Extensions** (in the left sidebar)
4. Find **"Stream Activity Feeds"** extension
5. Check the status - it should show as **"Active"** or **"Installed"**
6. Click on the extension to see:
   - Configuration settings
   - Health status
   - Usage metrics

## Method 2: Check Extension Logs

1. In Firebase Console, go to **Extensions** → **Stream Activity Feeds**
2. Click on the **"Logs"** tab
3. Look for recent activity logs showing:
   - Document creation events
   - Activity creation in Stream
   - Any errors or warnings

Alternatively, use Firebase CLI:
```bash
firebase functions:log --only ext-activity-feeds-firestore
```

## Method 3: Manual Test - Create a Test Document

1. Go to **Firestore Database** in Firebase Console
2. Navigate to: `feeds/user/{yourUserId}/`
3. Create a new document with a test ID (e.g., `test-123`)
4. Add these required fields:
   ```json
   {
     "actor": "User:YOUR_USER_ID",
     "verb": "post",
     "object": "Wallpaper:test-123",
     "title": "Test Wallpaper",
     "imageUrl": "https://example.com/image.jpg",
     "thumbnailUrl": "https://example.com/thumb.jpg",
     "userId": "YOUR_USER_ID",
     "categories": ["nature"],
     "tags": ["test", "verification"],
     "createdAt": "2025-01-15T12:00:00Z"
   }
   ```
5. Save the document
6. Wait 10-30 seconds for the extension to process

## Method 4: Verify in Stream Dashboard

1. Go to [Stream Dashboard](https://dashboard.getstream.io/)
2. Select your app
3. Navigate to **Activity Feeds** → **Feed Explorer**
4. Select feed group: `user`
5. Select feed ID: `{yourUserId}`
6. You should see the test activity appear within 30 seconds
7. Check that the activity contains the data from your Firestore document

## Method 5: Check via Your App

### Test Upload Flow

1. Open your app
2. Upload a new wallpaper
3. Check Xcode console for logs:
   ```
   ✅ [STREAM SERVICE] Saved wallpaper to Firestore: feeds/user/{userId}/{wallpaperId}
   ```
4. Wait 10-30 seconds
5. Check Stream Dashboard (as in Method 4) to see if the activity appears

### Test Migration

1. Open your app
2. Go to Debug menu
3. Run "Migrate Wallpapers to Firestore"
4. Check console logs for success/failure
5. Verify in Firestore that documents were created at correct paths
6. Check Stream Dashboard to see if activities appear

## Method 6: Check Firestore Console

1. Go to **Firestore Database** in Firebase Console
2. Navigate to `feeds/user/{userId}/`
3. You should see documents with wallpaper IDs as document IDs
4. Each document should have:
   - `actor`, `verb`, `object` (required Stream fields)
   - All wallpaper data fields
5. Check document timestamps to see recent activity

## Method 7: Monitor Extension Metrics

1. In Firebase Console, go to **Extensions** → **Stream Activity Feeds**
2. Check the **Monitoring** tab for:
   - Number of documents processed
   - Success/failure rates
   - Processing latency
   - Error rates

## Troubleshooting

### Extension Not Processing Documents

1. **Check Extension Status**: Ensure extension is "Active"
2. **Check Configuration**: Verify Stream API key and secret are correct
3. **Check Logs**: Look for error messages in extension logs
4. **Check Path Structure**: Documents must be at `feeds/{feedId}/{userId}/{foreignId}`
5. **Check Required Fields**: Documents must have `actor`, `verb`, `object`

### Activities Not Appearing in Stream

1. **Wait Time**: Extension processes asynchronously, wait 10-30 seconds
2. **Check Stream Dashboard**: Use Feed Explorer to check specific feeds
3. **Check Extension Logs**: Look for errors in processing
4. **Verify Feed Group**: Ensure feed group exists in Stream Dashboard
5. **Check Permissions**: Ensure Stream API key has write permissions

### Common Errors

**"Permission denied"**
- Check Firestore security rules allow writes
- Ensure user is authenticated
- Verify document path matches rules

**"Missing required fields"**
- Ensure document has `actor`, `verb`, `object` fields
- Fields must be strings (not null)

**"Extension not found"**
- Verify extension is installed
- Check extension name matches configuration

## Quick Verification Script

You can also verify programmatically by checking if activities exist in Stream after creating Firestore documents:

```swift
// After saving to Firestore, wait a bit, then check Stream
try await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
let activities = try await streamService.getFeedActivities(feed: userFeed, limit: 10)
// Check if your wallpaper activity is in the list
```

## Expected Behavior

When working correctly:
1. Document created in Firestore → Activity appears in Stream within 10-30 seconds
2. Document updated in Firestore → Activity updated in Stream within 10-30 seconds
3. Document deleted in Firestore → Activity deleted in Stream within 10-30 seconds

The extension processes changes asynchronously, so there will be a short delay.























