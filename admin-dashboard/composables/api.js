import axios from 'axios';

// Use environment variable or default to relative URL (same domain in production)
// In production, use relative URLs to work with Vercel rewrites
// In development, use localhost
// Get API URL - check at runtime to ensure correct detection
function getApiUrl() {
  // 1. Check for explicit environment variable (Render/Vercel)
  if (import.meta.env.VITE_API_URL) {
    return import.meta.env.VITE_API_URL;
  }

  // 2. Check if we're in production (not localhost)
  if (typeof window !== 'undefined') {
    const hostname = window.location.hostname;
    if (!hostname.includes('localhost') && !hostname.includes('127.0.0.1')) {
      // In production without VITE_API_URL, we might want to use relative path
      // if served from same domain, OR fail if separate.
      // For now, returning empty string implies relative path.
      return '';
    }
  }

  // 3. Default to localhost for development
  return 'http://localhost:3000';
}

const api = axios.create({
  baseURL: '', // Will be set dynamically in interceptor
  headers: {
    'Content-Type': 'application/json'
  }
});

// Add token to requests and set baseURL dynamically
api.interceptors.request.use(
  (config) => {
    // Set baseURL dynamically based on current environment
    if (!config.baseURL && !config.url?.startsWith('http')) {
      config.baseURL = getApiUrl();
    }

    const token = localStorage.getItem('token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    // If sending FormData, remove Content-Type header so axios can set it with boundary
    if (config.data instanceof FormData) {
      delete config.headers['Content-Type'];
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Handle auth errors
api.interceptors.response.use(
  (response) => response,
  (error) => {
    // Only redirect on 401 if we're not already on login page
    if (error.response?.status === 401 &&
      !window.location.pathname.includes('/login')) {
      localStorage.removeItem('token');
      localStorage.removeItem('admin');
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

export default api;

