import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../AuthContext';
import Button from '../../../components/ui/Button';

export default function SignUpScreen() {
  const { signUp } = useAuth();
  const navigate = useNavigate();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  async function handleRegister(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    if (password.length < 8) {
      setError('Password must be at least 8 characters');
      return;
    }
    if (password !== confirmPassword) {
      setError('Passwords do not match');
      return;
    }
    setIsLoading(true);
    try {
      await signUp(email, password);
      navigate('/');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Sign up failed');
    } finally {
      setIsLoading(false);
    }
  }

  return (
    <div className="min-h-screen bg-background flex items-center justify-center px-4">
      <div className="w-full max-w-sm space-y-6">
        <div className="text-center">
          <h1 className="text-textPrimary text-2xl font-bold">Create Account</h1>
          <p className="text-textSecondary text-sm mt-1">Sign up for Personal Memory OS</p>
        </div>

        <div className="bg-surface rounded-xl p-6 space-y-4">
          {error && (
            <div className="bg-red-900/40 border border-error rounded-lg px-3 py-2 text-sm text-red-300">
              {error}
            </div>
          )}

            <form onSubmit={handleRegister} className="space-y-4">
              <div>
                <label htmlFor="email" className="block text-sm text-textSecondary mb-1">
                  Email
                </label>
                <input
                  id="email"
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  required
                  autoComplete="email"
                  className="w-full bg-card border border-border rounded-lg px-3 py-2 text-textPrimary text-sm focus:outline-none focus:ring-2 focus:ring-accent"
                />
              </div>

              <div>
                <label htmlFor="password" className="block text-sm text-textSecondary mb-1">
                  Password
                </label>
                <input
                  id="password"
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  required
                  autoComplete="new-password"
                  className="w-full bg-card border border-border rounded-lg px-3 py-2 text-textPrimary text-sm focus:outline-none focus:ring-2 focus:ring-accent"
                />
              </div>

              <div>
                <label htmlFor="confirmPassword" className="block text-sm text-textSecondary mb-1">
                  Confirm Password
                </label>
                <input
                  id="confirmPassword"
                  type="password"
                  value={confirmPassword}
                  onChange={(e) => setConfirmPassword(e.target.value)}
                  required
                  autoComplete="new-password"
                  className="w-full bg-card border border-border rounded-lg px-3 py-2 text-textPrimary text-sm focus:outline-none focus:ring-2 focus:ring-accent"
                />
              </div>

              <Button type="submit" variant="primary" className="w-full" disabled={isLoading}>
                {isLoading ? 'Creating account…' : 'Create Account'}
              </Button>
            </form>

          <div className="text-sm text-textSecondary pt-2">
            Already have an account?{' '}
            <Link to="/signin" className="text-accent hover:underline">
              Sign in
            </Link>
          </div>
        </div>
      </div>
    </div>
  );
}
