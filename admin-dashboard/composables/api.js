import axios from 'axios';

// Get API URL based on environment
function getApiUrl() {
  // Use VITE_API_URL if explicitly set
  if (import.meta.env.VITE_API_URL) {
    console.log('Using VITE_API_URL:', import.meta.env.VITE_API_URL);
    return import.meta.env.VITE_API_URL;
  }

  // In production, use relative URL (same domain)
  if (process.env.NODE_ENV === 'production' || import.meta.env.PROD) {
    console.log('Running in production mode, using relative URL');
    return ''; // Relative URL for production
  }

  // Default to localhost for development
  console.log('Running in development mode, using localhost:3000');
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

