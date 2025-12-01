import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import connectDB from './config/database.js';
import authRoutes from './routes/auth.js';
import adminRoutes from './routes/admin.js';

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
    // Allow requests with no origin (like mobile apps or curl requests)
    if (!origin) return callback(null, true);
    
    const allowedOrigins = [
      'http://localhost:5173',
      'http://localhost:3000',
      'https://orabeta-admin-hotlny40o-nicks-projects-5b81dad2.vercel.app',
      'https://oraadmin.netlify.app',
      process.env.DASHBOARD_URL,
      process.env.VERCEL_URL,
      process.env.VERCEL_BRANCH_URL
    ].filter(Boolean);

    // Allow all origins in development
    if (process.env.NODE_ENV !== 'production') {
      console.log(`Allowing CORS for origin: ${origin} (development mode)`);
      return callback(null, true);
    }

    // In production, check against allowed origins
    if (allowedOrigins.some(allowed => 
      origin === allowed || 
      origin.includes(allowed) ||
      (new URL(allowed).hostname && origin.endsWith(new URL(allowed).hostname))
    )) {
      console.log(`Allowing CORS for origin: ${origin}`);
      callback(null, true);
    } else {
      console.warn('CORS blocked request from origin:', origin);
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With', 'Accept'],
  exposedHeaders: ['Content-Type', 'Authorization'],
  optionsSuccessStatus: 200,
  preflightContinue: false
};

// Apply CORS middleware with preflight support
app.options('*', cors(corsOptions)); // Enable preflight for all routes
app.use(cors(corsOptions));

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Ensure DB connection for serverless functions (skip for OPTIONS)
app.use(async (req, res, next) => {
  if (req.method === 'OPTIONS') {
    return next();
  }
  try {
    await connectDB();
    next();
  } catch (error) {
    console.error('Database connection error:', error);
    res.status(500).json({ message: 'Database connection failed' });
  }
});

// Routes
app.use('/api/admin/auth', authRoutes);
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
