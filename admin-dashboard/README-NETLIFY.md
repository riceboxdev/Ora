# ORA Admin Dashboard - Netlify Deployment Guide

This guide will walk you through deploying the ORA Admin Dashboard to Netlify.

## Prerequisites

- A Netlify account (sign up at [netlify.com](https://www.netlify.com/))
- Node.js (v16 or later) and npm installed locally
- Git installed locally

## Deployment Steps

### 1. Prepare Your Repository

1. Make sure all your changes are committed to your Git repository
2. Push your code to GitHub, GitLab, or Bitbucket

### 2. Deploy to Netlify

#### Option A: Deploy via Netlify UI

1. Log in to your Netlify account
2. Click on "Add new site" > "Import an existing project"
3. Connect to your Git provider and select your repository
4. Configure the build settings:
   - **Build command:** `npm run build`
   - **Publish directory:** `dist`
5. Click "Deploy site"

#### Option B: Deploy via Netlify CLI (Advanced)

1. Install the Netlify CLI globally:
   ```bash
   npm install -g netlify-cli
   ```
2. Build your project locally:
   ```bash
   npm install
   npm run build
   ```
3. Deploy to Netlify:
   ```bash
   netlify deploy --prod
   ```
4. Follow the prompts to connect to your Netlify account and configure the deployment

### 3. Configure Environment Variables

1. In the Netlify dashboard, go to "Site settings" > "Build & deploy" > "Environment"
2. Add the following environment variables:
   - `VITE_API_URL`: Your API base URL (e.g., `https://your-api-url.com`)
   - `VITE_FIREBASE_API_KEY`: Your Firebase API key
   - `VITE_FIREBASE_AUTH_DOMAIN`: Your Firebase auth domain
   - `VITE_FIREBASE_PROJECT_ID`: Your Firebase project ID
   - `VITE_FIREBASE_STORAGE_BUCKET`: Your Firebase storage bucket
   - `VITE_FIREBASE_MESSAGING_SENDER_ID`: Your Firebase messaging sender ID
   - `VITE_FIREBASE_APP_ID`: Your Firebase app ID
   - `VITE_FIREBASE_MEASUREMENT_ID`: Your Firebase measurement ID (if using Analytics)

### 4. Configure Build Settings (if not auto-detected)

1. In the Netlify dashboard, go to "Site settings" > "Build & deploy" > "Build settings"
2. Set the following:
   - **Build command:** `npm run build`
   - **Publish directory:** `dist`
   - **Node.js version:** 18 (or your preferred LTS version)

### 5. Configure Redirects

Netlify should automatically use the `netlify.toml` configuration, but you can verify:

1. In the Netlify dashboard, go to "Site settings" > "Build & deploy" > "Post processing" > "Asset optimization"
2. Ensure "Pretty URLs" is enabled
3. Under "Deploy" > "Deploy settings" > "Post processing", ensure "Asset optimization" is enabled

### 6. Enable Automatic Deploys (Optional)

1. In the Netlify dashboard, go to "Site settings" > "Build & deploy" > "Continuous deployment"
2. Under "Build hooks", you can create a new build hook if needed
3. Under "Deploy contexts", configure which branches should trigger builds

## Post-Deployment

1. After deployment, visit your site URL to verify everything is working
2. Check the "Deploys" tab in Netlify for any build errors
3. Set up a custom domain if needed in "Domain settings"

## Troubleshooting

- **Build fails**: Check the build logs in the Netlify dashboard
- **Environment variables not working**: Ensure they are set in Netlify and match the names in your `.env` file
- **Routing issues**: Verify the `netlify.toml` redirects are correctly configured
- **API connection issues**: Check CORS settings on your API server

## Support

For additional help, contact the development team or refer to the main project documentation.
