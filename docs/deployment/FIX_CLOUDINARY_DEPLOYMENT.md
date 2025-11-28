# Fix Cloudinary Function Deployment Issue

## Problem
The Cloud Run service `generatecloudinarysignature` already exists from the upgrade, so Firebase can't create a new one.

## Solution Options

### Option 1: Delete and Recreate (Recommended)

1. Go to [Google Cloud Console → Cloud Run](https://console.cloud.google.com/run)
2. Find the service named `generatecloudinarysignature`
3. Delete the service
4. Then redeploy:
   ```bash
   cd /Users/nickrogers/DEV/OraBeta/functions
   source ~/.nvm/nvm.sh
   nvm use default
   firebase deploy --only functions:generateCloudinarySignature
   ```

### Option 2: Update via Cloud Console

1. Go to [Google Cloud Console → Cloud Run](https://console.cloud.google.com/run)
2. Find the service `generatecloudinarysignature`
3. Click "Edit & Deploy New Revision"
4. Update the container image or configuration
5. Deploy the new revision

### Option 3: Force Update via gcloud CLI

If you have gcloud CLI authenticated:
```bash
gcloud run services delete generatecloudinarysignature --region=us-central1
firebase deploy --only functions:generateCloudinarySignature
```

## Current Status

The function code is ready (v2 format) and builds successfully. The issue is just the Cloud Run service conflict from the upgrade process.

## After Deployment

Once deployed, make sure to:
1. Set IAM permissions for authenticated users to invoke the function
2. Set Cloudinary environment variables/secrets
3. Test from the iOS app

