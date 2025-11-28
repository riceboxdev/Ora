# Admin Dashboard Deployment Guide

## ⚠️ IMPORTANT: Single Project Deployment

The admin dashboard MUST be deployed as a **single Vercel project from the repository root**. Do NOT deploy `admin-backend/` or `admin-dashboard/` separately.

## Project Structure

```
OraBeta/                          ← Deploy from HERE (root)
├── api/                          ← Serverless function (uses admin-backend code)
│   └── index.js
├── admin-backend/                ← Backend source (imported by api/index.js)
│   └── src/
├── admin-dashboard/              ← Frontend source
│   └── dist/                     ← Build output
└── vercel.json                   ← Root config (defines single project)
```

## Deployment Steps

### Option 1: Vercel CLI (Recommended)

```bash
# Make sure you're in the repository ROOT
cd /Users/nickrogers/DEV/OraBeta

# Deploy from root (this uses vercel.json at root)
vercel --prod
```

### Option 2: Vercel Dashboard

1. Go to [Vercel Dashboard](https://vercel.com/dashboard)
2. Find the **`orabeta-admin`** project (or create it if it doesn't exist)
3. Go to Settings → General
4. **Root Directory**: Leave EMPTY or set to `/` (root)
5. **Framework Preset**: Other
6. Click "Deploy" or push to your connected Git branch

### Option 3: Git Push (Auto-deploy)

If you have auto-deploy enabled:
1. Commit and push your changes
2. Vercel will automatically deploy from the root

## Configuration

The root `vercel.json` handles everything:

```json
{
  "buildCommand": "cd admin-dashboard && npm install && npm run build",
  "outputDirectory": "admin-dashboard/dist",
  "installCommand": "cd admin-backend && npm install && cd ../admin-dashboard && npm install && cd ../api && npm install",
  "rewrites": [
    {
      "source": "/api/(.*)",
      "destination": "/api/index.js"    ← Backend routes
    },
    {
      "source": "/(.*)",
      "destination": "/index.html"      ← Frontend routes
    }
  ]
}
```

## ⚠️ Common Mistakes to Avoid

### ❌ DON'T Deploy These Separately:
- `admin-backend/` as its own project
- `admin-dashboard/` as its own project
- Any subdirectory as a project

### ✅ DO:
- Deploy from repository root
- Use the root `vercel.json`
- Ensure Root Directory in Vercel is set to `/` or empty

## Verifying Deployment

After deployment, verify:

1. **Frontend works**: https://dashboard.ora.riceboxai.com
2. **Backend API works**: https://dashboard.ora.riceboxai.com/api/health
3. **Single project**: Check Vercel dashboard - should see ONE project, not two

## Troubleshooting

### If you accidentally created two projects:

1. Delete the separate `admin-backend` or `admin-dashboard` projects in Vercel
2. Keep only the root project (`orabeta-admin`)
3. Redeploy from root

### If API routes don't work:

1. Check that `api/index.js` exists and imports from `admin-backend/src/`
2. Verify environment variables are set in the root project
3. Check Vercel function logs for errors

## Environment Variables

All environment variables must be set in the **root project** (not in sub-projects):

- `MONGODB_URI`
- `JWT_SECRET`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_PRIVATE_KEY`
- `FIREBASE_CLIENT_EMAIL`
- `DASHBOARD_URL`
- `VITE_*` variables (for dashboard build)

## Current Deployment Status

- **Project Name**: `orabeta-admin`
- **Production URL**: https://dashboard.ora.riceboxai.com
- **Deployment Type**: Single project from root
- **Backend**: Serverless function at `/api/*`
- **Frontend**: Static site at `/*`

