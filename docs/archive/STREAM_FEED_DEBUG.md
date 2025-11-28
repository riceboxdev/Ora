# Stream Feed Group Debugging Guide

## Issue
Getting error: "Stream feed not configured. Please ensure the 'user' and 'timeline' feed groups exist"

## What I've Done

### 1. Enhanced Error Logging
- Added comprehensive error logging to capture full Stream API responses
- Error messages now include HTTP status codes and Stream error codes
- Full error details are logged to Firebase Functions logs

### 2. Improved Test Function
- Enhanced `testStreamFeeds` function to test each feed group individually
- Tests:
  - GET request to user feed
  - GET request to timeline feed  
  - POST activity to user feed
  - POST activity with 'to' field (like createPost does)

## Next Steps

### Step 1: Deploy the Updated Functions
```bash
cd functions
npm run build
firebase deploy --only functions
```

### Step 2: Check Firebase Functions Logs
After deploying, try creating a post again and check the Firebase Functions logs:
```bash
firebase functions:log --only createPost
```

Look for:
- `Stream API Error Details:` - Full error object from Stream
- `HTTP Status Code:` - The HTTP status code returned
- `Stream Error Object:` - Parsed Stream error with code and details

### Step 3: Verify Feed Groups in Stream Dashboard

Go to https://dashboard.getstream.io/ and verify:

1. **Feed Group Names (case-sensitive!)**
   - Feed group must be exactly: `user` (lowercase)
   - Feed group must be exactly: `timeline` (lowercase)
   - NOT `User`, `Timeline`, `USER`, etc.

2. **Feed Group Type**
   - Both should be **Flat Feed** type
   - NOT Aggregated Feed or Notification Feed

3. **Feed Group Configuration**
   - Make sure both feed groups are active/enabled
   - Check that they're not in a different app/environment

### Step 4: Test Using the Test Function

Call the `testStreamFeeds` function from your app to get detailed diagnostics:

```swift
// In your Swift code
Functions.functions().httpsCallable("testStreamFeeds").call { result, error in
    if let error = error {
        print("Error: \(error)")
        return
    }
    
    if let data = result?.data as? [String: Any] {
        print("Test Results: \(data)")
        // Check results.tests for individual test results
    }
}
```

This will tell you exactly which feed group is causing the issue.

## Common Issues

### Issue 1: Feed Group Name Mismatch
**Symptom:** Error code 6 or 16 when posting
**Solution:** Verify feed group names are exactly `user` and `timeline` (lowercase) in Stream Dashboard

### Issue 2: Feed Group Type Wrong
**Symptom:** Activities post but don't distribute properly
**Solution:** Ensure both are Flat Feed type

### Issue 3: API Keys Don't Match
**Symptom:** 401 Unauthorized errors
**Solution:** Verify STREAM_API_KEY and STREAM_API_SECRET in Firebase Functions config match the dashboard

### Issue 4: Feed Groups in Wrong App
**Symptom:** Feed groups exist but still get errors
**Solution:** Make sure you're checking the feed groups in the same Stream app that matches your API keys

## Checking API Keys

To verify your Stream API keys match:

1. In Stream Dashboard → Your App → Settings → API Keys
2. Compare with your Firebase Functions environment variables:
   ```bash
   firebase functions:config:get
   ```

## What the Enhanced Logging Will Show

When you try to create a post now, the logs will show:

```
Stream API Response: 404 - {"detail":"Feed group 'timeline' does not exist", "code": 6}
HTTP Status Code: 404
Stream Error Object: {"code": 6, "detail": "Feed group 'timeline' does not exist"}
```

This will tell you exactly which feed group is missing or misconfigured.

