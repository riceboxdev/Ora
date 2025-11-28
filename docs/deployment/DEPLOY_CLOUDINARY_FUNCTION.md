# Deploy Cloudinary Signature Function

## Quick Deploy Steps

1. **Navigate to functions directory:**
   ```bash
   cd /Users/nickrogers/DEV/OraBeta/functions
   ```

2. **Build TypeScript:**
   ```bash
   npm run build
   ```

3. **Deploy the function:**
   ```bash
   firebase deploy --only functions:generateCloudinarySignature
   ```

   Or deploy all functions:
   ```bash
   npm run deploy
   ```

## Before Deploying - Set Environment Variables

Make sure you have set these environment variables in Firebase Console:

1. Go to Firebase Console → Functions → Configuration
2. Set the following environment variables:
   - `CLOUDINARY_API_KEY` - Your Cloudinary API Key
   - `CLOUDINARY_API_SECRET` - Your Cloudinary API Secret
   - `CLOUDINARY_CLOUD_NAME` - Your Cloudinary Cloud Name (optional, defaults to "ddlpzt0qn")

Or set them via Firebase CLI:
```bash
firebase functions:config:set cloudinary.api_key="YOUR_API_KEY"
firebase functions:config:set cloudinary.api_secret="YOUR_API_SECRET"
firebase functions:config:set cloudinary.cloud_name="YOUR_CLOUD_NAME"
```

**Note:** For Firebase Functions v2+, use secrets instead:
```bash
firebase functions:secrets:set CLOUDINARY_API_KEY
firebase functions:secrets:set CLOUDINARY_API_SECRET
firebase functions:secrets:set CLOUDINARY_CLOUD_NAME
```

## Verify Deployment

After deployment, check:
1. Firebase Console → Functions → Check that `generateCloudinarySignature` is listed
2. Test the function from your iOS app
3. Check function logs: `firebase functions:log --only generateCloudinarySignature`

## Troubleshooting

If the function fails:
1. Check that you're logged in: `firebase login`
2. Verify project: `firebase use --add` or check `.firebaserc`
3. Check Node version: Should be 20 (as specified in package.json)
4. Verify environment variables are set correctly

