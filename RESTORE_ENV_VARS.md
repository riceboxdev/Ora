# Restore Environment Variables

All environment variables have been lost. Use this guide to restore them.

## Required Environment Variables

### Backend Variables (for admin-backend)

1. **MONGODB_URI**
   - Your MongoDB connection string (shared cluster)
   - Format: `mongodb+srv://username:password@cluster.mongodb.net/shared-cluster?retryWrites=true&w=majority`
   - Or: `mongodb://localhost:27017/shared-cluster`
   - **Note**: The database name in the URI can be a placeholder (e.g., `shared-cluster`) as it will be overridden by `MONGODB_DB_NAME` if set

2. **MONGODB_DB_NAME** (Recommended)
   - Database name override for this project
   - Example: `ios-app-dashboard`
   - This allows using the same connection string across multiple projects while keeping data isolated
   - If not set, the database name from `MONGODB_URI` will be used
   - **Important**: This project should use a different database name than other projects (e.g., `velvet-waitlist` uses `velvet-waitlist`, this project should use `ios-app-dashboard`)

3. **JWT_SECRET**
   - Secret key for JWT token signing
   - Generate with: `openssl rand -hex 32`
   - Or use any secure random string

4. **FIREBASE_PROJECT_ID**
   - Value: `angles-423a4`

5. **FIREBASE_PRIVATE_KEY**
   - Get from Firebase Console → Project Settings → Service Accounts
   - Click "Generate New Private Key"
   - Copy the `private_key` value
   - Format as single line with `\n` for newlines:
     ```
     -----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC...\n-----END PRIVATE KEY-----\n
     ```

6. **FIREBASE_CLIENT_EMAIL**
   - From Firebase Console → Project Settings → Service Accounts
   - Copy the `client_email` value
   - Format: `firebase-adminsdk-xxxxx@angles-423a4.iam.gserviceaccount.com`

7. **DASHBOARD_URL** (optional but recommended)
   - Your production dashboard URL
   - Value: `https://dashboard.ora.riceboxai.com`

### Frontend Variables (for admin-dashboard - VITE_*)

1. **VITE_FIREBASE_API_KEY**
   - Get from Firebase Console → Project Settings → General
   - Value: `AIzaSyA65aFDlUYlYo24el93ZEdd0ErEiuQzB3A` (or your current key)

2. **VITE_FIREBASE_AUTH_DOMAIN**
   - Value: `angles-423a4.firebaseapp.com`

3. **VITE_FIREBASE_PROJECT_ID**
   - Value: `angles-423a4`

4. **VITE_FIREBASE_STORAGE_BUCKET**
   - Value: `angles-423a4.firebasestorage.app`

5. **VITE_FIREBASE_MESSAGING_SENDER_ID**
   - Value: `1024758653829`

6. **VITE_FIREBASE_APP_ID**
   - Get from Firebase Console → Project Settings → General
   - Format: `1:1024758653829:ios:3c7851de8c93410dbedaec` (or your current app ID)

7. **VITE_API_URL** (optional)
   - Leave empty (uses same domain) or set to your API URL

## How to Restore

### Option 1: Using Vercel CLI (Recommended)

Run these commands one by one and paste the values when prompted:

```bash
cd /Users/nickrogers/DEV/OraBeta

# Backend variables
vercel env add MONGODB_URI production
# Paste your MongoDB URI when prompted (can use placeholder database name like "shared-cluster")

vercel env add MONGODB_DB_NAME production
# Enter: ios-app-dashboard (or your preferred database name for this project)

vercel env add JWT_SECRET production
# Paste your JWT secret when prompted (generate with: openssl rand -hex 32)

vercel env add FIREBASE_PROJECT_ID production
# Enter: angles-423a4

vercel env add FIREBASE_PRIVATE_KEY production
# Paste your Firebase private key (single line with \n)

vercel env add FIREBASE_CLIENT_EMAIL production
# Paste your Firebase client email

vercel env add DASHBOARD_URL production
# Enter: https://dashboard.ora.riceboxai.com

# Frontend variables
vercel env add VITE_FIREBASE_API_KEY production
# Paste your Firebase API key

vercel env add VITE_FIREBASE_AUTH_DOMAIN production
# Enter: angles-423a4.firebaseapp.com

vercel env add VITE_FIREBASE_PROJECT_ID production
# Enter: angles-423a4

vercel env add VITE_FIREBASE_STORAGE_BUCKET production
# Enter: angles-423a4.firebasestorage.app

vercel env add VITE_FIREBASE_MESSAGING_SENDER_ID production
# Enter: 1024758653829

vercel env add VITE_FIREBASE_APP_ID production
# Paste your Firebase App ID

vercel env add VITE_API_URL production
# Leave empty or press Enter
```

### Option 2: Using Vercel Dashboard

1. Go to https://vercel.com/dashboard
2. Select project: `orabeta-admin`
3. Go to **Settings** → **Environment Variables**
4. Click **Add New** for each variable
5. Set **Environment** to **Production** (and Preview/Development if needed)
6. Add all variables from the list above

## After Adding Variables

Redeploy the project:

```bash
vercel --prod
```

Or trigger a redeploy from the Vercel dashboard.

## Verify Variables Are Set

Check that all variables are set:

```bash
vercel env ls
```

You should see all the variables listed.

## Quick Reference - All Variables at Once

If you have a `.env.local` file with all values, you can use this script:

```bash
# Make sure you're in the project root
cd /Users/nickrogers/DEV/OraBeta

# Add all backend variables
vercel env add MONGODB_URI production < your_mongodb_uri.txt
vercel env add JWT_SECRET production < your_jwt_secret.txt
vercel env add FIREBASE_PROJECT_ID production
# Type: angles-423a4
vercel env add FIREBASE_PRIVATE_KEY production < your_private_key.txt
vercel env add FIREBASE_CLIENT_EMAIL production < your_client_email.txt
vercel env add DASHBOARD_URL production
# Type: https://dashboard.ora.riceboxai.com

# Add all frontend variables
vercel env add VITE_FIREBASE_API_KEY production
# Type: AIzaSyA65aFDlUYlYo24el93ZEdd0ErEiuQzB3A
vercel env add VITE_FIREBASE_AUTH_DOMAIN production
# Type: angles-423a4.firebaseapp.com
vercel env add VITE_FIREBASE_PROJECT_ID production
# Type: angles-423a4
vercel env add VITE_FIREBASE_STORAGE_BUCKET production
# Type: angles-423a4.firebasestorage.app
vercel env add VITE_FIREBASE_MESSAGING_SENDER_ID production
# Type: 1024758653829
vercel env add VITE_FIREBASE_APP_ID production
# Type: 1:1024758653829:ios:3c7851de8c93410dbedaec
vercel env add VITE_API_URL production
# Press Enter (leave empty)
```

## Troubleshooting

### If variables don't appear after adding:
1. Make sure you selected the correct environment (Production)
2. Redeploy the project
3. Check Vercel function logs for errors

### If you need to get Firebase credentials:
1. Go to https://console.firebase.google.com/
2. Select project: `angles-423a4`
3. Go to Project Settings → Service Accounts
4. Click "Generate New Private Key"
5. Copy `private_key` and `client_email` from the JSON file

### If MongoDB URI is missing:
- Check your MongoDB Atlas dashboard
- Or use a local MongoDB connection string
- Format: `mongodb+srv://username:password@cluster.mongodb.net/shared-cluster?retryWrites=true&w=majority`
- The database name in the URI can be a placeholder (e.g., `shared-cluster`) as it will be overridden by `MONGODB_DB_NAME`

### Database Name Configuration:
- Set `MONGODB_DB_NAME=ios-app-dashboard` for this project
- This ensures data isolation from other projects using the same cluster (e.g., `velvet-waitlist` uses `velvet-waitlist`)
- Both projects can use the exact same `MONGODB_URI` connection string


