# ORA Admin Backend

Express.js API server for the ORA admin dashboard.

## Setup

1. Install dependencies:
```bash
npm install
```

2. Create `.env` file:
```bash
cp .env.example .env
```

3. Update `.env` with your configuration:
- `MONGODB_URI`: MongoDB connection string
- `JWT_SECRET`: Secret key for JWT tokens
- `FIREBASE_PROJECT_ID`: Firebase project ID
- `FIREBASE_PRIVATE_KEY`: Firebase private key
- `FIREBASE_CLIENT_EMAIL`: Firebase client email
- `DASHBOARD_URL`: Dashboard URL for CORS

4. Start development server:
```bash
npm run dev
```

## Deployment

### Vercel

1. Install Vercel CLI:
```bash
npm i -g vercel
```

2. Deploy:
```bash
vercel
```

Or connect via GitHub and set **Root Directory** to `admin-backend`.

3. Add environment variables in Vercel Dashboard.

### MongoDB Atlas

1. Create a free account at [MongoDB Atlas](https://www.mongodb.com/cloud/atlas)
2. Create a new cluster
3. Get your connection string
4. Add as `MONGODB_URI` in environment variables

## API Endpoints

### Authentication
- `POST /api/admin/auth/login` - Admin login
- `GET /api/admin/auth/me` - Get current admin
- `POST /api/admin/auth/refresh` - Refresh token

### Admin Operations
- `GET /api/admin/users` - Get all users
- `GET /api/admin/analytics` - Get analytics
- `GET /api/admin/moderation/queue` - Get moderation queue
- `POST /api/admin/moderation/approve` - Approve post
- `POST /api/admin/moderation/reject` - Reject post
- `POST /api/admin/moderation/flag` - Flag post
- `POST /api/admin/users/ban` - Ban user
- `POST /api/admin/users/unban` - Unban user
- `GET /api/admin/settings` - Get system settings
- `POST /api/admin/settings` - Update system settings
- `GET /api/admin/posts` - Get posts
- `DELETE /api/admin/posts/:id` - Delete post

