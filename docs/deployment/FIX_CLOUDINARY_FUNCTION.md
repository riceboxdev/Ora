# Fix Cloudinary Function - v2 (Cloud Run) Upgrade

## Current Status
The `generateCloudinarySignature` function is being upgraded to Firebase Functions v2 (Cloud Run), but the upgrade is in progress and needs to be finalized.

## Steps to Complete

### 1. Finalize the Upgrade in Google Cloud Console

1. Go to [Google Cloud Console](https://console.cloud.google.com/functions)
2. Select your project: `angles-423a4`
3. Find the `generateCloudinarySignature` function
4. Check if there's an "Upgrade in Progress" status
5. Click on the function and either:
   - **Commit** the upgrade (if it's ready)
   - **Abort** the upgrade (if you want to start over)

### 2. After Finalizing, Deploy the Updated Code

Once the upgrade is finalized, deploy the updated function:

```bash
cd /Users/nickrogers/DEV/OraBeta/functions
source ~/.nvm/nvm.sh
nvm use default
firebase deploy --only functions:generateCloudinarySignature
```

### 3. Set IAM Permissions for Cloud Run

For v2 functions on Cloud Run, authenticated users need proper IAM permissions:

1. Go to [Google Cloud Console](https://console.cloud.google.com/run)
2. Find the Cloud Run service for `generateCloudinarySignature`
3. Go to **Permissions** tab
4. Ensure that authenticated users can invoke the function:
   - Click **Add Principal**
   - Principal: `allUsers` (or `allAuthenticatedUsers` for authenticated only)
   - Role: `Cloud Run Invoker`
   - Click **Save**

### 4. Set Environment Variables

Make sure Cloudinary credentials are set as environment variables or secrets:

```bash
cd /Users/nickrogers/DEV/OraBeta/functions
source ~/.nvm/nvm.sh
nvm use default

# Set as secrets (recommended for v2)
firebase functions:secrets:set CLOUDINARY_API_KEY
firebase functions:secrets:set CLOUDINARY_API_SECRET
firebase functions:secrets:set CLOUDINARY_CLOUD_NAME
```

Or in Google Cloud Console:
1. Go to Cloud Run service
2. Edit the service
3. Under **Variables & Secrets**, add:
   - `CLOUDINARY_API_KEY`
   - `CLOUDINARY_API_SECRET`
   - `CLOUDINARY_CLOUD_NAME`

### 5. Test the Function

After deployment, test from your iOS app. The function should now:
- Accept authenticated requests from Firebase Auth users
- Return Cloudinary signature for signed uploads
- Work with Cloud Run infrastructure

## Key Changes Made

1. ✅ Updated function to use Firebase Functions v2 API
2. ✅ Changed from `context.auth` to `request.auth` (v2 format)
3. ✅ Added explicit region configuration for v2
4. ✅ Updated error handling to use v2 error types

## Troubleshooting

If you still get `UNAUTHENTICATED` errors:
1. Verify the function is fully deployed (check Cloud Run logs)
2. Check IAM permissions (authenticated users need `Cloud Run Invoker` role)
3. Verify the user is authenticated in the iOS app
4. Check Firebase Console → Functions → Logs for detailed error messages

