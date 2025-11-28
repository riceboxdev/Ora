# Update Stream API Key

## Current Situation

Your Swift app uses API key: `8pwvyy4wrvek`
Firebase Functions code has been updated to use the same default.

## Action Required

### Step 1: Get Your Stream API Secret

1. Go to https://dashboard.getstream.io/
2. Select the app with API key `8pwvyy4wrvek`
3. Go to **Settings** → **API Keys**
4. Copy the **API Secret** (keep it secure!)

### Step 2: Update Firebase Functions Environment Variables

You need to set the environment variables in Firebase Functions. Use one of these methods:

#### Option A: Using Firebase CLI (Recommended)

```bash
cd functions

# Set the API key and secret
firebase functions:config:set stream.api_key="8pwvyy4wrvek"
firebase functions:config:set stream.api_secret="YOUR_API_SECRET_HERE"

# Deploy to apply changes
firebase deploy --only functions
```

**Note:** The old `functions:config:set` method is being phased out. For new projects, use environment variables.

#### Option B: Using Environment Variables (Modern Method)

For Firebase Functions v2 (which you're using for `generateCloudinarySignature`), use environment variables:

1. Go to Firebase Console: https://console.firebase.google.com/
2. Select your project
3. Go to **Functions** → **Configuration**
4. Click **Add Variable**
5. Add:
   - `STREAM_API_KEY` = `8pwvyy4wrvek`
   - `STREAM_API_SECRET` = `YOUR_API_SECRET_HERE`
6. Redeploy functions:
   ```bash
   firebase deploy --only functions
   ```

#### Option C: Using .env file for Local Testing

For local emulator testing, create `functions/.env`:

```env
STREAM_API_KEY=8pwvyy4wrvek
STREAM_API_SECRET=YOUR_API_SECRET_HERE
CLOUDINARY_CLOUD_NAME=ddlpzt0qn
CLOUDINARY_API_KEY=your_key_here
CLOUDINARY_API_SECRET=your_secret_here
```

**Important:** Add `.env` to `.gitignore`:
```bash
echo ".env" >> functions/.gitignore
```

### Step 3: Verify Feed Groups Exist

After updating the API key, verify the feed groups exist in the correct Stream app:

1. Go to https://dashboard.getstream.io/
2. Select the app with API key `8pwvyy4wrvek`
3. Go to **Activity Feeds** → **Feed Groups**
4. Verify these feed groups exist (exactly lowercase):
   - `user` (Flat Feed type)
   - `timeline` (Flat Feed type)

If they don't exist, create them:
- Click "Create Feed Group"
- Name: `user`, Type: Flat Feed
- Click "Create"
- Repeat for `timeline`

### Step 4: Verify User Exists in Stream

The Firebase Extension should create users automatically, but verify:

1. In Stream Dashboard → **Activity Feeds** → **Users**
2. Look for your user ID: `qSLYaj3G7EPQ9YkOYJ7lHUOf8jj1`
3. If it doesn't exist, the extension might not be working

### Step 5: Test

After updating:

1. **Deploy the updated functions:**
   ```bash
   cd functions
   npm run build
   cd ..
   firebase deploy --only functions
   ```

2. **Test creating a post** from your app

3. **Check the logs** to verify the correct API key is being used:
   ```bash
   firebase functions:log --only createPost
   ```
   Look for: `Stream API Key being used: 8pwvyy4w...`

## Troubleshooting

### Issue: "Invalid API key" or "Unauthorized"
**Solution:** 
- Verify the API secret is correct
- Make sure environment variables are set and functions are redeployed
- Check that you're using the secret for API key `8pwvyy4wrvek`

### Issue: Still getting error code 16
**Solution:**
- Verify feed groups `user` and `timeline` exist in the Stream app with API key `8pwvyy4wrvek`
- Make sure feed group names are exactly `user` and `timeline` (lowercase)
- Check that both are Flat Feed type

### Issue: Functions still using old API key
**Solution:**
- Make sure you redeployed after setting environment variables
- Check environment variables are set correctly: `firebase functions:config:get`
- Verify in logs: `firebase functions:log --only createPost`

## Security Note

⚠️ **Never commit API secrets to git!**

- The `.env` file should be in `.gitignore`
- Use Firebase environment variables for production
- Never hardcode secrets in code

## Next Steps

1. ✅ Update Firebase Functions environment variables with the new API key and secret
2. ✅ Verify feed groups exist in Stream Dashboard
3. ✅ Redeploy functions
4. ✅ Test creating a post
5. ✅ Check logs to confirm correct API key is being used

