# Render Deployment Guide

## Overview

This project deploys to Render using two services:
1. **Frontend**: Static site (Vite build of admin dashboard)
2. **API**: Node.js web service (Express API)

## Quick Start

### 1. Push to GitHub

```bash
git add render.yaml
git commit -m "Add Render configuration"
git push origin main
```

### 2. Create Blueprint on Render

1. Go to [Render Dashboard](https://dashboard.render.com)
2. Click **New** → **Blueprint**
3. Connect your GitHub account if needed
4. Select the `riceboxdev/Ora` repository
5. Choose the `main` branch
6. Review the services that will be created
7. Click **Apply**

### 3. Configure Environment Variables

After deployment, you need to add environment variables to the API service:

1. In Render Dashboard, go to the **ora-admin-api** service
2. Click **Environment** in the left sidebar
3. Add the following variables:

#### Firebase Admin SDK
```
FIREBASE_PROJECT_ID=<your-project-id>
FIREBASE_CLIENT_EMAIL=<your-service-account-email>
FIREBASE_PRIVATE_KEY=<your-private-key>
```

#### MongoDB (if needed)
```
MONGODB_URI=<your-mongodb-connection-string>
```

#### JWT
```
JWT_SECRET=<your-jwt-secret>
```

#### Cloudflare (for images)
```
CLOUDFLARE_ACCOUNT_ID=<your-account-id>
CLOUDFLARE_API_TOKEN=<your-api-token>
CLOUDFLARE_IMAGES_ACCOUNT_HASH=<your-account-hash>
```

> **Note**: You can get these values from your existing `.env` files or from the `.env.firebase-fix` file.

### 4. Update Frontend API URL

After the API service is deployed, Render will give you a URL like:
```
https://ora-admin-api.onrender.com
```

You need to tell the frontend to use this URL:

1. In Render Dashboard, go to the **ora-admin-dashboard** service
2. Click **Environment**
3. Add this variable:
```
VITE_API_URL=https://ora-admin-api.onrender.com
```
4. Click **Save Changes** - this will trigger a redeploy

### 5. Access Your Dashboard

Once both services are deployed:
- **Frontend URL**: `https://ora-admin-dashboard.onrender.com` (or custom domain)
- **API URL**: `https://ora-admin-api.onrender.com`

## Important Notes

### Free Tier Limitations
- Services on the free tier **spin down after 15 minutes** of inactivity
- First request after spin-down takes 30-60 seconds (cold start)
- This is normal behavior for Render's free tier

### Automatic Deploys
- Any push to `main` that modifies `render.yaml` triggers a redeploy
- Changes to code automatically trigger deploys for affected services

### Viewing Logs
- Go to each service in Render Dashboard
- Click **Logs** to see real-time output
- Useful for debugging deployment issues

## Troubleshooting

### API service fails to start
- Check the **Logs** in Render Dashboard
- Verify all environment variables are set correctly
- Ensure Firebase private key is properly formatted (include BEGIN/END markers)

### Frontend can't connect to API
- Verify `VITE_API_URL` is set in frontend environment
- Check that API service is running (not spinning down)
- Look for CORS errors in browser console

### 404 errors on frontend
- The static site configuration includes a rewrite rule to handle Vue Router
- All routes should redirect to `/index.html`
