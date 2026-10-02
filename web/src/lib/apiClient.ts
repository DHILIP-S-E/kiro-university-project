import axios from 'axios';
import { getAccessToken, signOut } from './authClient';

const apiClient = axios.create({
  baseURL: import.meta.env.VITE_BACKEND_URL,
});

// Request interceptor: attach the access token as Bearer (refreshed when needed)
apiClient.interceptors.request.use(async (config) => {
  const token = await getAccessToken();
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Response interceptor: on 401 sign out and redirect to sign-in
apiClient.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      signOut();
      window.location.replace('/signin');
    }
    return Promise.reject(error);
  },
);

export default apiClient;
