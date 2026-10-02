import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../AuthContext';
import Button from '../../../components/ui/Button';

export default function ForgotPasswordScreen() {
  const { forgotPassword, confirmForgotPassword } = useAuth();
  const navigate = useNavigate();
  const [step, setStep] = useState<'email' | 'confirm'>('email');
  const [email, setEmail] = useState('');
  const [code, setCode] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  async function handleSendCode(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setIsLoading(true);
    try {
      await forgotPassword(email);
      setStep('confirm');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to send reset code');
    } finally {
      setIsLoading(false);
    }
  }

  async function handleReset(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setIsLoading(true);
    try {
      await confirmForgotPassword(email, code, newPassword);
      navigate('/signin');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Password reset failed');
    } finally {
      setIsLoading(false);
    }
  }

  return (
    <div className="min-h-screen bg-background flex items-center justify-center px-4">
      <div className="w-full max-w-sm space-y-6">
        <div className="text-center">
          <h1 className="text-textPrimary text-2xl font-bold">Reset Password</h1>
          <p className="text-textSecondary text-sm mt-1">
            {step === 'email' ? 'Enter your email to receive a reset code' : 'Enter the code and new password'}
          </p>
        </div>

        <div className="bg-surface rounded-xl p-6 space-y-4">
          {error && (
            <div className="bg-red-900/40 border border-error rounded-lg px-3 py-2 text-sm text-red-300">
              {error}
            </div>
          )}

          {step === 'email' ? (
            <form onSubmit={handleSendCode} className="space-y-4">
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
              <Button type="submit" variant="primary" className="w-full" disabled={isLoading}>
                {isLoading ? 'Sending…' : 'Send Reset Code'}
              </Button>
            </form>
          ) : (
            <form onSubmit={handleReset} className="space-y-4">
              <div>
                <label htmlFor="code" className="block text-sm text-textSecondary mb-1">
                  Reset Code
                </label>
                <input
                  id="code"
                  type="text"
                  value={code}
                  onChange={(e) => setCode(e.target.value)}
                  required
                  autoComplete="one-time-code"
                  className="w-full bg-card border border-border rounded-lg px-3 py-2 text-textPrimary text-sm focus:outline-none focus:ring-2 focus:ring-accent"
                />
              </div>
              <div>
                <label htmlFor="newPassword" className="block text-sm text-textSecondary mb-1">
                  New Password
                </label>
                <input
                  id="newPassword"
                  type="password"
                  value={newPassword}
                  onChange={(e) => setNewPassword(e.target.value)}
                  required
                  autoComplete="new-password"
                  className="w-full bg-card border border-border rounded-lg px-3 py-2 text-textPrimary text-sm focus:outline-none focus:ring-2 focus:ring-accent"
                />
              </div>
              <Button type="submit" variant="primary" className="w-full" disabled={isLoading}>
                {isLoading ? 'Resetting…' : 'Reset Password'}
              </Button>
            </form>
          )}

          <div className="text-sm text-textSecondary pt-2">
            <Link to="/signin" className="text-accent hover:underline">
              Back to sign in
            </Link>
          </div>
        </div>
      </div>
    </div>
  );
}
