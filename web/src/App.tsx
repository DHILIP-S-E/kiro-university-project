import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { AuthProvider } from './features/auth/AuthContext';
import ProtectedRoute from './components/ProtectedRoute';
import Layout from './components/Layout';

import SignInScreen from './features/auth/screens/SignInScreen';
import SignUpScreen from './features/auth/screens/SignUpScreen';
import ForgotPasswordScreen from './features/auth/screens/ForgotPasswordScreen';
import DashboardScreen from './features/dashboard/DashboardScreen';
import RemindersScreen from './features/reminders/RemindersScreen';
import EventsScreen from './features/events/EventsScreen';
import EventDetailScreen from './features/events/EventDetailScreen';
import CaptureScreen from './features/capture/CaptureScreen';
import MemoryScreen from './features/memory/MemoryScreen';
import SettingsScreen from './features/settings/SettingsScreen';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 1000 * 60, // 1 minute
      retry: 1,
    },
  },
});

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <AuthProvider>
        <BrowserRouter>
          <Routes>
            {/* Public routes */}
            <Route path="/signin" element={<SignInScreen />} />
            <Route path="/signup" element={<SignUpScreen />} />
            <Route path="/forgot-password" element={<ForgotPasswordScreen />} />

            {/* Protected routes */}
            <Route element={<ProtectedRoute />}>
              <Route element={<Layout />}>
                <Route path="/" element={<DashboardScreen />} />
                <Route path="/reminders" element={<RemindersScreen />} />
                <Route path="/events" element={<EventsScreen />} />
                <Route path="/events/:id" element={<EventDetailScreen />} />
                <Route path="/capture" element={<CaptureScreen />} />
                <Route path="/memory" element={<MemoryScreen />} />
                <Route path="/settings" element={<SettingsScreen />} />
              </Route>
            </Route>

            {/* Fallback */}
            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </BrowserRouter>
      </AuthProvider>
    </QueryClientProvider>
  );
}
