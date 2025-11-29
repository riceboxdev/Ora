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

1. **MONGODB_URI** - MongoDB connection string (shared cluster)
   - Example: `mongodb+srv://username:password@cluster.mongodb.net/shared-cluster?retryWrites=true&w=majority`
   - The database name in the URI can be a placeholder (e.g., `shared-cluster`) as it will be overridden by `MONGODB_DB_NAME` if set

2. **MONGODB_DB_NAME** - Database name override (recommended)
   - Example: `ios-app-dashboard`
   - This allows using the same connection string across multiple projects while keeping data isolated
   - If not set, the database name from `MONGODB_URI` will be used
   - **Important**: This project should use a different database name than other projects (e.g., `velvet-waitlist` uses `velvet-waitlist`, this project should use `ios-app-dashboard`)

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





