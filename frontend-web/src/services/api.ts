
import axios from 'axios';

const VITE_API_BASE = import.meta.env.VITE_API_BASE;

let base = VITE_API_BASE || 'https://sparehub-0t47.onrender.com/api';
if (base.endsWith('/')) {
  base = base.substring(0, base.length - 1);
}
// Ensure it has the /api prefix if it's missing
if (!base.endsWith('/api') && !base.includes('/api/')) {
  base += '/api';
}

export const API_BASE_URL = base + '/';

// Log the API Base URL in production to help debug
if (import.meta.env.PROD) {
  console.log('API Base URL:', API_BASE_URL);
}

const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  },
});

api.interceptors.request.use(
  (config) => {
    const user = JSON.parse(localStorage.getItem('user') || '{}');
    if (user && user.token) {
      config.headers['Authorization'] = 'Bearer ' + user.token;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem('user');
      // Only redirect if not already on the login page to avoid refresh loops
      if (window.location.pathname !== '/login') {
        window.location.href = '/login';
      }
    }
    return Promise.reject(error);
  }
);

export default api;
