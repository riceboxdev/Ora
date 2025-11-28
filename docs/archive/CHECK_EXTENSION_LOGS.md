# How to Check Firebase Extension Logs

The 400 error is coming from Stream's API, but the Firebase Extension logs will show the exact error message.

## Step-by-Step to Find the Error:

1. **Go to Firebase Console**
   - Navigate to: https://console.firebase.google.com/
   - Select your project

2. **Open Functions/Extensions Logs**
   - Option A: Go to **Functions** → **Logs** tab
   - Option B: Go to **Extensions** → Click on "Stream Activity Feeds" → **Logs** tab

3. **Look for Error Messages**
   - Search for entries with "Failed to create activity"
   - Look for entries with "error" or "Error"
   - The logs should show something like:
     ```
     Failed to create activity {activity data} {error object}
     ```

4. **Check the Error Details**
   - The error object should contain:
     - Error message from Stream
     - Error code
     - Which field is invalid

5. **Alternative: Check Cloud Functions Logs**
   - Go to **Google Cloud Console**
   - Navigate to **Cloud Functions** → **Logs**
   - Find the function: `activitiesToFirestore`
   - Look for error messages

## What to Look For:

The extension code shows it logs:
- `"Failed to create activity"` followed by the activity object and error
- `"Expected 'actor' field"` if actor is missing
- `"Expected 'verb' field"` if verb is missing
- `"Expected 'object' field"` if object is missing
- `"Expected 'foreign_id' field"` if foreign_id is missing (but extension adds this)

## Share the Error Message:

Once you find the error in the logs, share:
1. The exact error message
2. The error code (if any)
3. Which field is mentioned as invalid (if any)

This will help us fix the exact issue!
























