const serverless = require('serverless-http');
const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');

// Import your server routes
const authRoutes = require('../src/routes/auth.js');
const adminRoutes = require('../src/routes/admin.js');

// Load environment variables
dotenv.config();

const app = express();

// Configure CORS for Netlify
const corsOptions = {
  origin: function (origin, callback) {
    // Allow requests with no origin (like mobile apps or curl requests)
    if (!origin) return callback(null, true);
    
    const allowedOrigins = [
      'http://localhost:5173',
      'http://localhost:3000',
      'https://oraadmin.netlify.app',
      process.env.DASHBOARD_URL,
      process.env.URL // Netlify provides this
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

// Apply CORS middleware
app.options('*', cors(corsOptions));
app.use(cors(corsOptions));

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Routes
app.use('/api/admin/auth', authRoutes);
app.use('/api/admin', adminRoutes);

// Health check
app.get('/api/health', async (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString()
  });
});

// Export as serverless function
module.exports.handler = serverless(app);
