# Troubleshooting Stream Firebase Extension 400 Error

## Current Issue
Getting `400 Bad Request` when Firebase Extension tries to create activities in Stream.

## Steps to Diagnose

### 1. Check Full Error Response in Stream Dashboard
1. Go to Stream Dashboard → Logs
2. Click on the error entry
3. Look for **"Response"** or **"Error Message"** section
4. This will show the exact validation error from Stream API

### 2. Verify Document Structure in Firestore
1. Go to Firebase Console → Firestore
2. Navigate to: `feeds/user/{userId}/{wallpaperId}`
3. Check the document and verify:
   - `actor` field exists and is a string (not null)
   - `verb` field exists and is a string (not null)
   - `object` field exists and is a string (not null)
   - All three fields are at the top level (not nested)

### 3. Check Extension Configuration
1. Go to Firebase Console → Extensions
2. Click on "Stream Activity Feeds" extension
3. Verify configuration:
   - `STREAM_API_KEY` is set correctly
   - `STREAM_API_SECRET` is set correctly
   - Collection path is `feeds`
   - Feed group document ID matches your feed group name

### 4. Common Causes of 400 Errors

#### A. Missing Required Fields
- Ensure `actor`, `verb`, and `object` are all present
- They must be strings, not null or missing

#### B. Invalid Actor Format
- Try both formats:
  - Just user ID: `"0bULA5bM4OhI71GC5V0JhGiRvGG3"`
  - Reference format: `"User:0bULA5bM4OhI71GC5V0JhGiRvGG3"`
- Stream typically accepts either, but the extension might prefer one

#### C. Invalid Data Types
- All fields must be valid types:
  - Strings: `"value"`
  - Numbers: `123` (not `"123"`)
  - Arrays: `["item1", "item2"]`
  - Objects: `{"key": "value"}`

#### D. Reserved Field Names
- Stream might reject certain field names
- Try moving wallpaper-specific fields into a nested `data` object

#### E. Location Parameter
- The `location=unspecified` parameter is usually harmless
- It's a default parameter added by Stream SDK
- The real error is likely in the request body

## Testing Minimal Document

Try creating a minimal test document manually in Firestore:

1. Path: `feeds/user/{userId}/test-minimal`
2. Fields:
   ```json
   {
     "actor": "0bULA5bM4OhI71GC5V0JhGiRvGG3",
     "verb": "post",
     "object": "Wallpaper:test-minimal"
   }
   ```
3. Wait 30 seconds
4. Check Stream Dashboard to see if it works

If this minimal document works, the issue is with additional fields in your wallpaper documents.

## Next Steps

1. **Check the full error response** from Stream Dashboard - this will tell us exactly what's wrong
2. **Try the minimal document** to isolate the issue
3. **Share the error response body** so we can fix the exact issue

## Potential Fixes

### Fix 1: Use Reference Format for Actor
If the minimal document works but full documents don't, try changing actor format back to `"User:{userId}"`.

### Fix 2: Nest Custom Data
If Stream rejects additional fields, we might need to nest wallpaper data:
```json
{
  "actor": "...",
  "verb": "post",
  "object": "...",
  "data": {
    // All wallpaper fields here
  }
}
```

But check Stream's documentation - the Firebase Extension should handle this automatically.

### Fix 3: Check Extension Version
- Ensure you're using the latest version of the Stream Activity Feeds extension
- Older versions might have bugs or different requirements
























