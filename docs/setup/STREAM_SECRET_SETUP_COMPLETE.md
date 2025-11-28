# Stream API Secret Setup - Next Steps

## ✅ What's Done

1. ✅ API key updated in code: `8pwvyy4wrvek`
2. ✅ Secret created in Firebase: `STREAM_API_SECRET`
3. ✅ `.env` file created for local development (in `.gitignore`)

## ⚠️ Important: Set Environment Variable in Firebase Console

Since most of your functions use **Firebase Functions v1** (not v2), they read from environment variables, not secrets directly.

### Quick Setup (5 minutes)

1. **Go to Firebase Console:**
   - https://console.firebase.google.com/project/angles-423a4/settings/functions

2. **Scroll to "Environment variables" section**

3. **Click "Add variable"** and add:
   - **Name:** `STREAM_API_SECRET`
   - **Value:** `z83ynbabke3s6r9uxh58w9njt7qmbxakf9fh76vzgrw5y4rm7bmfjzm2jz3y4p6a`
   - Click **Save**

4. **Also add (if not already there):**
   - **Name:** `STREAM_API_KEY`
   - **Value:** `8pwvyy4wrvek`
   - Click **Save**

5. **Redeploy functions:**
   ```bash
   cd /Users/nickrogers/DEV/OraBeta
   firebase deploy --only functions
   ```

## Verify Feed Groups Exist

**Critical:** Before testing, verify feed groups exist in Stream Dashboard:

1. Go to: https://dashboard.getstream.io/
2. Select the app with API key `8pwvyy4wrvek`
3. Go to **Activity Feeds** → **Feed Groups**
4. Verify these exist (exactly lowercase):
   - `user` (type: Flat Feed)
   - `timeline` (type: Flat Feed)

**If they don't exist, create them:**
- Click "Create Feed Group"
- Name: `user`, Type: Flat Feed → Create
- Repeat for `timeline`

## Test

After deploying:

1. **Try creating a post** from your app
2. **Check logs:**
   ```bash
   firebase functions:log --only createPost
   ```
   Look for: `Stream API Key being used: 8pwvyy4w...`

## Local Testing

For local emulator testing, the `.env` file is already set up. Just run:
```bash
cd functions
npm run build
firebase emulators:start --only functions
```

Then in Xcode, set `USE_LOCAL_FUNCTIONS=true` in your scheme's environment variables.

## Summary

**What you need to do:**
1. ⏳ Set `STREAM_API_SECRET` and `STREAM_API_KEY` in Firebase Console (see above)
2. ⏳ Verify feed groups `user` and `timeline` exist in Stream Dashboard
3. ⏳ Deploy: `firebase deploy --only functions`
4. ⏳ Test creating a post

**That's it!** After these steps, your Stream integration should work.

