import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';
import { fileURLToPath, URL } from 'node:url';

// Check if we're in production (Netlify sets NODE_ENV to 'production')
const isProduction = process.env.NODE_ENV === 'production';

export default defineConfig({
  base: isProduction ? '/' : '/',
  plugins: [vue()],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url))
    }
  },
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: process.env.VITE_API_URL || 'http://localhost:3000',
        changeOrigin: true,
        secure: false
      }
    }
  },
  build: {
    outDir: 'dist',
    assetsDir: 'assets',
    sourcemap: !isProduction,
    rollupOptions: {
      output: {
        manualChunks: {
          vue: ['vue', 'vue-router', 'pinia'],
          ui: ['@headlessui/vue'],
          charts: ['chart.js', 'vue-chartjs']
        }
      }
    }
  },
  define: {
    'process.env': process.env
  }
});

