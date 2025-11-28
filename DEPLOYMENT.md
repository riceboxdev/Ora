# OraBeta Admin Dashboard Deployment

## ⚠️ IMPORTANT: Single Project Deployment

**The admin dashboard MUST be deployed as a single Vercel project from the repository root.**

**DO NOT deploy `admin-backend/` or `admin-dashboard/` separately.**

See [DEPLOY_ADMIN.md](DEPLOY_ADMIN.md) for detailed deployment instructions.

## Deployment Status

✅ **Deployed to Vercel as a single project: `orabeta-admin`**

Production URL: https://dashboard.ora.riceboxai.com

## Environment Variables Required

You need to set the following environment variables in the Vercel dashboard:

### Backend Environment Variables

1. **MONGODB_URI** - MongoDB connection string
   - Example: `mongodb+srv://username:password@cluster.mongodb.net/orabeta-admin`

2. **JWT_SECRET** - Secret key for JWT tokens
   - Generate with: `openssl rand -hex 32`

3. **FIREBASE_PROJECT_ID** - Firebase project ID
   - Value: `angles-423a4`

4. **FIREBASE_PRIVATE_KEY** - Firebase Admin SDK private key
   - Get from Firebase Console → Project Settings → Service Accounts
   - Format: `-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n`

5. **FIREBASE_CLIENT_EMAIL** - Firebase Admin SDK client email
   - Example: `firebase-adminsdk-xxxxx@angles-423a4.iam.gserviceaccount.com`

6. **DASHBOARD_URL** - Your production dashboard URL (for CORS)
   - Value: `https://dashboard.ora.riceboxai.com`

### Dashboard Environment Variables

1. **VITE_API_URL** - Leave empty (uses same domain) or set to your API URL
2. **VITE_FIREBASE_API_KEY** - `AIzaSyA65aFDlUYlYo24el93ZEdd0ErEiuQzB3A`
3. **VITE_FIREBASE_AUTH_DOMAIN** - `angles-423a4.firebaseapp.com`
4. **VITE_FIREBASE_PROJECT_ID** - `angles-423a4`
5. **VITE_FIREBASE_STORAGE_BUCKET** - `angles-423a4.firebasestorage.app`
6. **VITE_FIREBASE_MESSAGING_SENDER_ID** - `1024758653829`
7. **VITE_FIREBASE_APP_ID** - `1:1024758653829:ios:3c7851de8c93410dbedaec`

## Setting Environment Variables in Vercel

1. Go to [Vercel Dashboard](https://vercel.com/dashboard)
2. Select the `orabeta-admin` project
3. Go to Settings → Environment Variables
4. Add each variable above
5. Redeploy the project

## Project Structure

```
OraBeta/
├── api/                    # Vercel API routes (serverless functions)
│   └── index.js           # Express app for /api/* routes
├── admin-backend/         # Backend source code
├── admin-dashboard/       # Frontend source code
└── vercel.json            # Vercel configuration
```

## API Routes

All API routes are prefixed with `/api`:
- `/api/admin/auth/*` - Authentication endpoints
- `/api/admin/*` - Admin operations
- `/api/health` - Health check

## Next Steps

1. Set environment variables in Vercel dashboard
2. Create initial admin user in MongoDB
3. Test the deployment
4. Update production URL if needed





