# Stream Feed Group Diagnosis

## Issue Found

From the Firebase Functions logs, I can see:

1. **Error Code:** 16 ("Does Not Exist")
2. **HTTP Status:** 404 Not Found  
3. **API Key in use:** `q8pwvyy4wrvek` (different from code default `qyfy876f96h9`)

## Root Cause

Error code 16 with 404 means Stream cannot find the resource. When posting to:
```
POST /api/v2/feeds/user/{userId}/activities/
```

Stream returns 404/16 when:
1. ❌ **The "user" feed group doesn't exist** in your Stream app (most likely)
2. ❌ The user hasn't been created in Stream yet
3. ❌ The API key doesn't match the app where feed groups are configured

## Solution Steps

### Step 1: Verify API Key Matches Your Stream App

The production function is using API key: `q8pwvyy4wrvek`

1. Go to https://dashboard.getstream.io/
2. Check which Stream app has this API key
3. Make sure that's the app where you created the feed groups

### Step 2: Verify Feed Groups Exist in the Correct App

In the Stream Dashboard for the app with API key `q8pwvyy4wrvek`:

1. Go to **Activity Feeds** → **Feed Groups**
2. Verify you have a feed group named exactly: **`user`** (lowercase, no spaces)
3. Verify you have a feed group named exactly: **`timeline`** (lowercase, no spaces)
4. Both should be **Flat Feed** type

### Step 3: Check Feed Group Configuration

For each feed group (`user` and `timeline`):

- **Type:** Flat Feed
- **Status:** Active/Enabled
- **Visibility:** Can be public or private depending on your needs

### Step 4: Verify User Exists in Stream

The Firebase Extension should create users automatically, but verify:

1. In Stream Dashboard → Activity Feeds → Users
2. Look for user ID: `qSLYaj3G7EPQ9YkOYJ7lHUOf8jj1`
3. If the user doesn't exist, the extension might not be working

### Step 5: Test Feed Group Directly

Use the `testStreamFeeds` function to test:

```swift
// In your Swift app
let streamService = StreamService()
do {
    let results = try await streamService.testStreamFeeds()
    print("Test Results: \(results)")
} catch {
    print("Error: \(error)")
}
```

This will tell you exactly which feed group is missing.

## Common Issues

### Issue 1: Wrong Stream App
**Symptom:** Feed groups exist but still get 404
**Solution:** Make sure the API key in Firebase Functions matches the app where feed groups are configured

### Issue 2: Feed Group Name Mismatch
**Symptom:** Error code 16
**Solution:** Feed groups must be exactly `user` and `timeline` (lowercase, case-sensitive)

### Issue 3: Feed Group Type Wrong
**Symptom:** Posts work but don't appear correctly
**Solution:** Both should be **Flat Feed** type, not Aggregated

### Issue 4: User Not Created
**Symptom:** Error code 16 for specific user
**Solution:** Check if Firebase Extension is creating Stream users. If not, manually create or use `ensureStreamUser` function

## Next Steps

1. **Deploy the updated error handling** (better error messages)
2. **Check Stream Dashboard** for API key `q8pwvyy4wrvek`
3. **Verify feed groups** `user` and `timeline` exist in that app
4. **Run testStreamFeeds** to get detailed diagnostics
5. **Check if user exists** in Stream Dashboard

## Quick Fix

If feed groups are missing:

1. Go to Stream Dashboard → Your App (with API key `q8pwvyy4wrvek`)
2. Go to Activity Feeds → Feed Groups
3. Click "Create Feed Group"
4. Create:
   - Name: `user` (exactly, lowercase)
   - Type: Flat Feed
   - Click Create
5. Repeat for `timeline`

Then try creating a post again.

