# Deployment Guide

This guide covers deploying Firebase Functions and Firestore rules for the OraBeta app.

## Quick Start

```bash
cd /Users/nickrogers/DEV/OraBeta/functions
npm install
npm run build
firebase deploy --only functions
firebase deploy --only firestore:rules
```

## Prerequisites

1. **Firebase CLI** installed and authenticated:
   ```bash
   firebase login
   firebase use --add  # Select your project: angles-423a4
   ```

2. **Node.js 18+** installed:
   ```bash
   node --version
   ```

3. **Environment Variables** set in Firebase Console:
   - `STREAM_API_KEY`
   - `STREAM_API_SECRET`
   - `CLOUDINARY_CLOUD_NAME` (if using Cloudinary)
   - `CLOUDINARY_API_KEY` (if using Cloudinary)
   - `CLOUDINARY_API_SECRET` (if using Cloudinary)

## Deployment Steps

### 1. Navigate to Functions Directory

```bash
cd /Users/nickrogers/DEV/OraBeta/functions
```

### 2. Install Dependencies

```bash
npm install
```

### 3. Build TypeScript

```bash
npm run build
```

This compiles `src/index.ts` to `lib/index.js`.

### 4. Deploy Firebase Functions

Deploy all functions:
```bash
npm run deploy
```

Or deploy specific functions:
```bash
firebase deploy --only functions:getStreamUserToken
firebase deploy --only functions:createPost
```

### 5. Deploy Firestore Rules

```bash
cd /Users/nickrogers/DEV/OraBeta
firebase deploy --only firestore:rules
```

### 6. Verify Deployment

After deployment:
- Functions listed in Firebase Console → Functions
- Firestore rules updated in Firebase Console → Firestore → Rules
- Test functions from your iOS app

## Key Functions

### Authentication
- `getStreamUserToken` - Generates Stream tokens for authenticated users
- `ensureStreamUser` - Creates Stream user when Firebase user is created

### Posts
- `createPost` - Creates posts and saves to Firestore
- `editPost` - Updates posts in Firestore
- `migratePostsToFirestore` - Migrates existing posts from Stream to Firestore

### Cloudinary
- `generateCloudinarySignature` - Generates signed upload signatures

## Troubleshooting

### Authentication Issues
```bash
firebase login --reauth
firebase use angles-423a4
```

### Build Errors
```bash
cd functions
npm install
npm run build
```

### Deployment Errors
1. Check you're logged in: `firebase login`
2. Verify project: `firebase use --add`
3. Check Node version: `node --version` (should be 18+)
4. Verify environment variables in Firebase Console

### Function Errors After Deployment
1. Check logs: `firebase functions:log`
2. Verify environment variables are set correctly
3. Test functions individually using Firebase Console

## Environment Variables

Set in Firebase Console → Functions → Configuration:
- Go to https://console.firebase.google.com/project/angles-423a4/settings/functions
- Scroll to "Environment variables" section
- Add required variables (see Prerequisites above)

## Notes

- **iOS App**: No deployment needed - code is built into the app bundle
- **Hot Reloading**: Functions update automatically when deployed
- **Rollback**: Use Firebase Console to rollback to previous function versions if needed

