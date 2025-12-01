import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import connectDB from './config/database.js';
import authRoutes from './routes/auth.js';
import adminRoutes from './routes/admin.js';
import classificationRoutes from './routes/classification.js';

// Load environment variables
dotenv.config();

const app = express();

// Connect to database (only if not in serverless environment)
if (process.env.VERCEL !== '1') {
  connectDB().catch(console.error);
}

// Configure CORS
const corsOptions = {
  origin: function (origin, callback) {
    // Allow requests with no origin (same-origin requests, mobile apps, curl)
    if (!origin) {
      return callback(null, true);
    }
    const allowedOrigins = [
      'http://localhost:5173',
      'http://localhost:3000',
      process.env.DASHBOARD_URL,
      process.env.VERCEL_URL,
      process.env.VERCEL_BRANCH_URL
    ].filter(Boolean);

    // In production, check against allowed origins
    if (process.env.NODE_ENV === 'production' && allowedOrigins.length > 0) {
      if (allowedOrigins.some(allowed => origin.includes(allowed))) {
        callback(null, true);
      } else {
        callback(null, true); // Allow all for now, can restrict later
      }
    } else {
      // In development, allow all
      callback(null, true);
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With', 'Accept'],
  exposedHeaders: ['Content-Type', 'Authorization'],
  optionsSuccessStatus: 200
};

app.use(cors(corsOptions));

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Ensure DB connection for serverless functions (skip for OPTIONS)
// Note: MongoDB is only needed for AdminUser authentication, not for Firestore routes
// So we make this optional - routes that need MongoDB will handle connection errors
app.use(async (req, res, next) => {
  if (req.method === 'OPTIONS') {
    return next();
  }
  // Only attempt MongoDB connection if MONGODB_URI is configured
  // Most routes use Firestore, so MongoDB connection is optional
  if (process.env.MONGODB_URI) {
    try {
      await connectDB();
    } catch (error) {
      // Log but don't block - routes that need MongoDB will handle the error
      // Most routes (announcements, settings, etc.) use Firestore, not MongoDB
      console.warn('MongoDB connection warning (non-blocking):', error.message);
    }
  }
  next();
});

// Routes
app.use('/api/admin/auth', authRoutes);
app.use('/api/admin/classifications', classificationRoutes);
app.use('/api/admin', adminRoutes);

// Health check
app.get('/api/health', async (req, res) => {
  const result = {
    status: 'ok',
    checks: {
      db: 'unknown',
      env: {
        hasMongoUri: !!process.env.MONGODB_URI,
        hasJwtSecret: !!process.env.JWT_SECRET,
        hasFirebaseConfig: !!(process.env.FIREBASE_PROJECT_ID && process.env.FIREBASE_PRIVATE_KEY)
      }
    }
  };

  try {
    await connectDB();
    result.checks.db = 'ok';
  } catch (error) {
    console.error('Health check DB error:', error);
    result.checks.db = 'error';
    result.status = 'degraded';
  }

  if (!result.checks.env.hasMongoUri || !result.checks.env.hasJwtSecret) {
    if (result.status === 'ok') {
      result.status = 'degraded';
    }
  }

  res.json(result);
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(err.status || 500).json({
    message: err.message || 'Internal Server Error',
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
  });
});

// Export for Vercel serverless functions
export default app;
