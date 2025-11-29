# Backend API Pattern Template

This document outlines the standard pattern for creating Express.js backend APIs, based on the Waitlist backend architecture.

## Directory Structure

```
backend/
├── src/
│   ├── routes/
│   │   ├── auth.js              # Authentication routes
│   │   └── [resource].js        # Resource CRUD routes
│   ├── models/
│   │   └── [Resource].js        # Database models (Mongoose)
│   ├── middleware/
│   │   ├── auth.js              # JWT auth middleware
│   │   └── rateLimit.js         # Rate limiting
│   ├── config/
│   │   └── database.js          # Database connection
│   └── server.js                # Express app setup
├── package.json
└── .env
```

## Server Setup Pattern

```javascript
import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import connectDB from './config/database.js';
import authRoutes from './routes/auth.js';
import resourceRoutes from './routes/resources.js';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Connect to database
connectDB().catch(console.error);

// CORS configuration
const corsOptions = {
  origin: function (origin, callback) {
    if (!origin) {
      return callback(null, true);
    }
    const allowedOrigins = [
      'http://localhost:5173',
      'http://localhost:3000'
    ];
    callback(null, true); // Allow all for now
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With', 'Accept']
};

app.use(cors(corsOptions));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Ensure DB connection for serverless functions
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
app.use('/api/auth', authRoutes);
app.use('/api/resources', resourceRoutes);

// Health check
app.get('/health', async (req, res) => {
  const result = {
    status: 'ok',
    checks: {
      db: 'unknown',
      env: {
        hasMongoUri: !!process.env.MONGODB_URI,
        hasJwtSecret: !!process.env.JWT_SECRET
      }
    }
  };

  try {
    await connectDB();
    result.checks.db = 'ok';
  } catch (error) {
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

// Start server (skip for serverless)
if (process.env.VERCEL !== '1') {
  app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
  });
}

export default app;
```

## Database Connection Pattern

```javascript
import mongoose from 'mongoose';

let cachedConnection = null;

const connectDB = async () => {
  if (cachedConnection) {
    return cachedConnection;
  }

  try {
    const connection = await mongoose.connect(process.env.MONGODB_URI, {
      useNewUrlParser: true,
      useUnifiedTopology: true
    });

    cachedConnection = connection;
    console.log('MongoDB connected');
    return connection;
  } catch (error) {
    console.error('MongoDB connection error:', error);
    throw error;
  }
};

export default connectDB;
```

## Auth Middleware Pattern

```javascript
import jwt from 'jsonwebtoken';
import User from '../models/User.js';

export const protect = async (req, res, next) => {
  let token;

  if (req.headers.authorization && req.headers.authorization.startsWith('Bearer')) {
    token = req.headers.authorization.split(' ')[1];
  }

  if (!token) {
    return res.status(401).json({ message: 'Not authorized, no token' });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = await User.findById(decoded.id).select('-password');
    
    if (!req.user) {
      return res.status(401).json({ message: 'User not found' });
    }
    
    next();
  } catch (error) {
    return res.status(401).json({ message: 'Not authorized, token failed' });
  }
};
```

## Route Pattern

```javascript
import express from 'express';
import { body, validationResult } from 'express-validator';
import Resource from '../models/Resource.js';
import { protect } from '../middleware/auth.js';

const router = express.Router();

// All routes require authentication
router.use(protect);

// @route   GET /api/resources
// @desc    Get all resources
// @access  Private
router.get('/', async (req, res) => {
  try {
    const resources = await Resource.find({ userId: req.user._id })
      .sort({ createdAt: -1 });
    res.json(resources);
  } catch (error) {
    console.error('Error fetching resources:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   POST /api/resources
// @desc    Create a new resource
// @access  Private
router.post(
  '/',
  [
    body('name').trim().notEmpty().withMessage('Name is required'),
    body('description').optional().trim()
  ],
  async (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ errors: errors.array() });
      }

      const { name, description } = req.body;

      const resource = await Resource.create({
        name,
        description,
        userId: req.user._id
      });

      res.status(201).json(resource);
    } catch (error) {
      console.error('Error creating resource:', error);
      res.status(500).json({ message: error.message });
    }
  }
);

// @route   GET /api/resources/:id
// @desc    Get resource by ID
// @access  Private
router.get('/:id', async (req, res) => {
  try {
    const resource = await Resource.findOne({
      _id: req.params.id,
      userId: req.user._id
    });

    if (!resource) {
      return res.status(404).json({ message: 'Resource not found' });
    }

    res.json(resource);
  } catch (error) {
    console.error('Error fetching resource:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   PUT /api/resources/:id
// @desc    Update resource
// @access  Private
router.put('/:id', async (req, res) => {
  try {
    const resource = await Resource.findOne({
      _id: req.params.id,
      userId: req.user._id
    });

    if (!resource) {
      return res.status(404).json({ message: 'Resource not found' });
    }

    if (req.body.name) resource.name = req.body.name;
    if (req.body.description !== undefined) resource.description = req.body.description;

    await resource.save();

    res.json(resource);
  } catch (error) {
    console.error('Error updating resource:', error);
    res.status(500).json({ message: error.message });
  }
});

// @route   DELETE /api/resources/:id
// @desc    Delete resource
// @access  Private
router.delete('/:id', async (req, res) => {
  try {
    const resource = await Resource.findOne({
      _id: req.params.id,
      userId: req.user._id
    });

    if (!resource) {
      return res.status(404).json({ message: 'Resource not found' });
    }

    await Resource.deleteOne({ _id: req.params.id });

    res.json({ message: 'Resource deleted' });
  } catch (error) {
    console.error('Error deleting resource:', error);
    res.status(500).json({ message: error.message });
  }
});

export default router;
```

## Model Pattern

```javascript
import mongoose from 'mongoose';

const resourceSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    trim: true
  },
  description: {
    type: String,
    trim: true
  },
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    required: true,
    ref: 'User'
  }
}, {
  timestamps: true
});

const Resource = mongoose.model('Resource', resourceSchema);

export default Resource;
```

## Best Practices

1. **Error Handling**: Always use try-catch, return consistent error format
2. **Validation**: Use express-validator for input validation
3. **Authentication**: Protect routes with middleware
4. **Database**: Use connection pooling for serverless
5. **CORS**: Configure CORS properly for production
6. **Environment Variables**: Use dotenv for configuration
7. **Logging**: Log errors and important operations
8. **Rate Limiting**: Implement rate limiting for auth endpoints













