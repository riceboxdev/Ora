import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

// Import routes using dynamic imports
const connectDB = (await import('./src/config/database.js')).default;
const authRoutes = (await import('./src/routes/auth.js')).default;
const adminRoutes = (await import('./src/routes/admin.js')).default;
const reportsRoutes = (await import('./src/routes/reports.js')).default;

const app = express();

// Trust proxy for Vercel (needed for rate limiting)
// Trust only the first hop (Vercel's edge) to prevent IP spoofing
app.set('trust proxy', 1);

// Connect to database
connectDB().catch(console.error);

// Configure CORS
const corsOptions = {
  origin: function (origin, callback) {
    callback(null, true); // Allow all origins
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With', 'Accept'],
  exposedHeaders: ['Content-Type', 'Authorization'],
  optionsSuccessStatus: 200
};

app.use(cors(corsOptions));

// Body parsing - but skip for multipart/form-data (let multer handle it)
const jsonParser = express.json();
const urlencodedParser = express.urlencoded({ extended: true });

app.use((req, res, next) => {
  const contentType = req.headers['content-type'] || '';
  if (contentType.includes('multipart/form-data')) {
    return next(); // Skip body parsing for multipart, let multer handle it
  }
  jsonParser(req, res, next);
});

app.use((req, res, next) => {
  const contentType = req.headers['content-type'] || '';
  if (contentType.includes('multipart/form-data')) {
    return next(); // Skip URL encoding for multipart
  }
  urlencodedParser(req, res, next);
});

// Log all requests for debugging
app.use((req, res, next) => {
  console.log(`[${req.method}] ${req.path}`, req.url);
  next();
});

// Ensure DB connection
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

// Routes - Vercel routes /api/* to this function
// The path Express receives is the full path including /api
app.use('/api/admin/auth', authRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/reports', reportsRoutes);

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
