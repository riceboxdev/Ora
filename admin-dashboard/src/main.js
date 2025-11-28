import { createApp } from 'vue';
import { createPinia } from 'pinia';
import App from './App.vue';
import router from './router';
import '../assets/css/main.css';

const app = createApp(App);
const pinia = createPinia();

app.use(pinia);
app.use(router);

// Add global error handler
app.config.errorHandler = (err, instance, info) => {
  console.error('Vue error:', err, info);
};

// Mount with error handling
try {
  app.mount('#app');
} catch (error) {
  console.error('Failed to mount app:', error);
  document.body.innerHTML = '<div style="padding: 20px; font-family: sans-serif;"><h1>Application Error</h1><p>Failed to load the application. Please check the browser console for details.</p></div>';
}
