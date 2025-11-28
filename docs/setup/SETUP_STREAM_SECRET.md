# Setup Stream API Secret

## Quick Setup

### For Local Development (Emulator)

I've created a `.env` file in the `functions/` directory with your API key and secret. This is already in `.gitignore` so it won't be committed.

**Verify it's set up:**
```bash
cd functions
cat .env
```

You should see:
```
STREAM_API_KEY=8pwvyy4wrvek
STREAM_API_SECRET=z83ynbabke3s6r9uxh58w9njt7qmbxakf9fh76vzgrw5y4rm7bmfjzm2jz3y4p6a
CLOUDINARY_CLOUD_NAME=ddlpzt0qn
```

### For Production (Firebase Functions)

You need to set the secret in Firebase Functions. Here are your options:

#### Option 1: Using Firebase Console (Easiest)

1. Go to: https://console.firebase.google.com/project/angles-423a4/settings/functions
2. Scroll down to **Environment variables** section
3. Click **Add variable**
4. Add:
   - **Name:** `STREAM_API_SECRET`
   - **Value:** `z83ynbabke3s6r9uxh58w9njt7qmbxakf9fh76vzgrw5y4rm7bmfjzm2jz3y4p6a`
5. Click **Save**
6. Also add `STREAM_API_KEY` if it's not there:
   - **Name:** `STREAM_API_KEY`
   - **Value:** `8pwvyy4wrvek`
7. **Important:** Redeploy your functions after adding environment variables:
   ```bash
   firebase deploy --only functions
   ```

#### Option 2: Using Firebase CLI (Alternative)

For v2 functions (like `generateCloudinarySignature`), you can use:

```bash
# Set the secret (interactive)
firebase functions:secrets:set STREAM_API_SECRET

# When prompted, paste: z83ynbabke3s6r9uxh58w9njt7qmbxakf9fh76vzgrw5y4rm7bmfjzm2jz3y4p6a

# Grant access to the function
firebase functions:secrets:access STREAM_API_SECRET

# Deploy
firebase deploy --only functions
```

**Note:** This requires updating your function code to use `runWith({ secrets: ['STREAM_API_SECRET'] })`.

#### Option 3: Quick Deploy with Environment Variables

If you want to set it directly during deployment, you can modify `firebase.json` or use environment variables. However, the Console method (Option 1) is recommended.

## Verify It's Working

After deploying:

1. **Test locally first:**
   ```bash
   cd functions
   npm run build
   firebase emulators:start --only functions
   ```

2. **Check logs after deploying:**
   ```bash
   firebase functions:log --only createPost
   ```
   
   Look for: `Stream API Key being used: 8pwvyy4w...`

3. **Test creating a post** from your app

## Important: Verify Feed Groups

After setting up the API secret, make sure:

1. Go to https://dashboard.getstream.io/
2. Select the app with API key `8pwvyy4wrvek`
3. Go to **Activity Feeds** → **Feed Groups**
4. Verify these exist (exactly lowercase):
   - `user` (Flat Feed)
   - `timeline` (Flat Feed)

If they don't exist, create them now!

## Security Notes

✅ `.env` file is in `.gitignore` - your secrets won't be committed
✅ For production, use Firebase Console environment variables
❌ Never commit secrets to git
❌ Never share secrets publicly

## Next Steps

1. ✅ API key updated in code: `8pwvyy4wrvek`
2. ✅ `.env` file created for local development
3. ⏳ **Set `STREAM_API_SECRET` in Firebase Console** (see Option 1 above)
4. ⏳ **Verify feed groups exist** in Stream Dashboard
5. ⏳ **Deploy functions:** `firebase deploy --only functions`
6. ⏳ **Test creating a post**

