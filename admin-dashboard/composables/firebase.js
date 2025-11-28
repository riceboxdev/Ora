import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';

const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID,
  storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID,
  appId: import.meta.env.VITE_FIREBASE_APP_ID
};

// Check if Firebase config is available
const hasFirebaseConfig = firebaseConfig.apiKey && firebaseConfig.projectId;

let app;
let auth;

if (hasFirebaseConfig) {
  try {
    // Initialize Firebase
    app = initializeApp(firebaseConfig);
    // Initialize Firebase Auth
    auth = getAuth(app);
  } catch (error) {
    console.error('Firebase initialization error:', error);
  }
} else {
  console.warn('Firebase configuration is missing. Some features may not work.');
}

export { auth };
export default app;

