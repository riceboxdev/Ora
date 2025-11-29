# Environment Variables Setup

## ✅ Already Added

The following environment variables have been added to your Vercel project:

- ✅ `MONGODB_URI` - Set to placeholder (update with your actual MongoDB URI)
- ✅ `MONGODB_DB_NAME` - Database name override (optional, defaults to database name in URI)
- ✅ `JWT_SECRET` - Generated secure secret
- ✅ `FIREBASE_PROJECT_ID` - `angles-423a4`
- ✅ `VITE_FIREBASE_API_KEY` - Firebase API key
- ✅ `VITE_FIREBASE_AUTH_DOMAIN` - `angles-423a4.firebaseapp.com`
- ✅ `VITE_FIREBASE_PROJECT_ID` - `angles-423a4`
- ✅ `VITE_FIREBASE_STORAGE_BUCKET` - `angles-423a4.firebasestorage.app`
- ✅ `VITE_FIREBASE_MESSAGING_SENDER_ID` - `1024758653829`
- ✅ `VITE_FIREBASE_APP_ID` - Firebase app ID
- ✅ `VITE_API_URL` - Empty (uses same domain)

## ⚠️ Still Needed

You need to add these manually in the Vercel dashboard:

### 1. FIREBASE_PRIVATE_KEY
Get from Firebase Console:
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: `angles-423a4`
3. Go to Project Settings → Service Accounts
4. Click "Generate New Private Key"
5. Copy the `private_key` value (including `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----`)
6. Add to Vercel as `FIREBASE_PRIVATE_KEY`

**Important:** The private key should be on a single line with `\n` for newlines, like:
```
-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC...\n-----END PRIVATE KEY-----\n
```

### 2. FIREBASE_CLIENT_EMAIL
From the same Service Accounts page:
- Copy the `client_email` value
- Should look like: `firebase-adminsdk-xxxxx@angles-423a4.iam.gserviceaccount.com`
- Add to Vercel as `FIREBASE_CLIENT_EMAIL`

### 3. Update MONGODB_URI and MONGODB_DB_NAME

**MONGODB_URI**: The current value is a placeholder. Update it with your actual MongoDB connection string:
- MongoDB Atlas: `mongodb+srv://username:password@cluster.mongodb.net/shared-cluster?retryWrites=true&w=majority`
- Local MongoDB: `mongodb://localhost:27017/shared-cluster`
- **Note**: The database name in the URI can be a placeholder (e.g., `shared-cluster`) as it will be overridden by `MONGODB_DB_NAME` if set.

**MONGODB_DB_NAME** (Recommended): Set this to specify which database to use. This allows:
- Using the same connection string across multiple projects
- Easy switching between databases via environment variables
- Better separation of configuration from code
- Example: `ios-app-dashboard` (this project) or `velvet-waitlist` (other project)

**Configuration Example:**
```
MONGODB_URI=mongodb+srv://user:pass@cluster.mongodb.net/shared-cluster?retryWrites=true&w=majority
MONGODB_DB_NAME=ios-app-dashboard
```

The connection code will automatically replace `shared-cluster` with `ios-app-dashboard` when connecting.

## How to Add Missing Variables

### Option 1: Vercel CLI
```bash
cd /Users/nickrogers/DEV/OraBeta
vercel env add FIREBASE_PRIVATE_KEY production
# Paste the private key when prompted

vercel env add FIREBASE_CLIENT_EMAIL production
# Paste the client email when prompted
```

### Option 2: Vercel Dashboard
1. Go to https://vercel.com/dashboard
2. Select project: `orabeta-admin`
3. Go to Settings → Environment Variables
4. Add each variable:
   - Key: `FIREBASE_PRIVATE_KEY`
   - Value: (paste from Firebase Console)
   - Environment: Production
5. Repeat for `FIREBASE_CLIENT_EMAIL`

## After Adding Variables

Redeploy the project to apply changes:
```bash
cd /Users/nickrogers/DEV/OraBeta
vercel --prod
```

Or trigger a redeploy from the Vercel dashboard.











