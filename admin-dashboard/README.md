# OraBeta Admin Dashboard

Web-based admin dashboard for managing OraBeta app users, content, moderation, and settings.

## Setup

1. Install dependencies:
```bash
npm install
```

2. Create `.env` file with Firebase configuration:
```bash
cp .env.example .env
```

3. Update `.env` with your Firebase credentials and API URL.

4. Start development server:
```bash
npm run dev
```

## Deployment to Vercel

1. Install Vercel CLI (if not already installed):
```bash
npm i -g vercel
```

2. Deploy:
```bash
vercel
```

Or connect via GitHub:
- Go to [Vercel Dashboard](https://vercel.com/dashboard)
- Click "Add New Project"
- Import your GitHub repository
- Set **Root Directory** to `admin-dashboard`
- Vercel will auto-detect the configuration from `vercel.json`

3. Add environment variables in Vercel Dashboard:
- `VITE_API_URL`: Your admin backend API URL
- `VITE_FIREBASE_API_KEY`: Firebase API key
- `VITE_FIREBASE_AUTH_DOMAIN`: Firebase auth domain
- `VITE_FIREBASE_PROJECT_ID`: Firebase project ID
- `VITE_FIREBASE_STORAGE_BUCKET`: Firebase storage bucket
- `VITE_FIREBASE_MESSAGING_SENDER_ID`: Firebase messaging sender ID
- `VITE_FIREBASE_APP_ID`: Firebase app ID

## Features

- **User Management**: View, search, ban/unban users
- **Post Moderation**: Review and moderate posts
- **Analytics**: View app statistics and engagement metrics
- **Content Management**: Manage posts and tags
- **System Settings**: Configure feature flags and remote config










