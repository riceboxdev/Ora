import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import api from '../services/api';
import { signInWithEmailAndPassword, signOut } from 'firebase/auth';
import { auth } from '../services/firebase';

export const useAuthStore = defineStore('auth', () => {
  const admin = ref(null);
  const token = ref(localStorage.getItem('token') || null);
  const loading = ref(false);
  const error = ref(null);

  const isAuthenticated = computed(() => !!token.value);

  async function login(email, password) {
    try {
      loading.value = true;
      error.value = null;
      
      // First, sign in with Firebase Auth
      const userCredential = await signInWithEmailAndPassword(auth, email, password);
      const firebaseToken = await userCredential.user.getIdToken();
      
      // Then, send Firebase token to backend to get JWT
      const response = await api.post('/api/admin/auth/login', {
        firebaseToken: firebaseToken
      });
      
      token.value = response.data.token;
      admin.value = response.data.admin;
      localStorage.setItem('token', token.value);
      localStorage.setItem('admin', JSON.stringify(admin.value));
      
      return response.data;
    } catch (err) {
      error.value = err.response?.data?.message || err.message || 'Login failed';
      throw err;
    } finally {
      loading.value = false;
    }
  }

  async function logout() {
    try {
      await signOut(auth);
    } catch (err) {
      console.error('Firebase sign out error:', err);
    }
    
    token.value = null;
    admin.value = null;
    localStorage.removeItem('token');
    localStorage.removeItem('admin');
  }

  async function fetchAdmin() {
    try {
      const response = await api.get('/api/admin/auth/me');
      admin.value = response.data;
      localStorage.setItem('admin', JSON.stringify(admin.value));
      return response.data;
    } catch (err) {
      logout();
      throw err;
    }
  }

  function initializeFromStorage() {
    const storedAdmin = localStorage.getItem('admin');
    if (storedAdmin) {
      admin.value = JSON.parse(storedAdmin);
    }
  }

  return {
    admin,
    token,
    loading,
    error,
    isAuthenticated,
    login,
    logout,
    fetchAdmin,
    initializeFromStorage
  };
});

