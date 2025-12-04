import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';

dotenv.config();

const connectDB = (await import('./src/config/database.js')).default;
const authRoutes = (await import('./src/routes/auth.js')).default;
const adminRoutes = (await import('./src/routes/admin.js')).default;
const reportsRoutes = (await import('./src/routes/reports.js')).default;
const migrationRoutes = (await import('./src/routes/migrationRoutes.js')).default;

const app = express();

app.set('trust proxy', 1);

connectDB().catch(console.error);

const corsOptions = {
  origin: function (origin, callback) {
    callback(null, true);
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With', 'Accept'],
  exposedHeaders: ['Content-Type', 'Authorization'],
  optionsSuccessStatus: 200
};

app.use(cors(corsOptions));

const jsonParser = express.json();
const urlencodedParser = express.urlencoded({ extended: true });

app.use((req, res, next) => {
  const contentType = req.headers['content-type'] || '';
  if (contentType.includes('multipart/form-data')) {
    return next();
  }
  jsonParser(req, res, next);
});

app.use((req, res, next) => {
  const contentType = req.headers['content-type'] || '';
  if (contentType.includes('multipart/form-data')) {
    return next();
  }
  urlencodedParser(req, res, next);
});

app.use((req, res, next) => {
  console.log(`[${req.method}] ${req.path}`, req.url);
  next();
});

app.use(async (req, res, next) => {
  if (req.method === 'OPTIONS') {
    return next();
  }
  if (process.env.MONGODB_URI) {
    try {
      await connectDB();
    } catch (error) {
      console.warn('MongoDB connection warning (non-blocking):', error.message);
    }
  }
  next();
});

app.use('/api/admin/auth', authRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/reports', reportsRoutes);
app.use('/api/migrations', migrationRoutes);

app.get('/api/health', async (req, res) => {
  const result = {
    status: 'ok',
    checks: {
      db: 'unknown',
      firestore: 'unknown',
      env: {
        hasMongoUri: !!process.env.MONGODB_URI,
        hasJwtSecret: !!process.env.JWT_SECRET,
        hasFirebaseConfig: !!(process.env.FIREBASE_PROJECT_ID && process.env.FIREBASE_PRIVATE_KEY && process.env.FIREBASE_CLIENT_EMAIL),
      }
    }
  };

  try {
    if (process.env.MONGODB_URI) {
      await connectDB();
      result.checks.db = 'ok';
    } else {
      result.checks.db = 'skipped';
    }
  } catch (error) {
    console.error('Health check DB error:', error);
    result.checks.db = 'error';
    result.status = 'degraded';
  }

  res.json(result);
});

app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(err.status || 500).json({
    message: err.message || 'Internal Server Error',
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack })
  });
});

export default app;
