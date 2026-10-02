import React, { createContext, useContext, useEffect, useState } from 'react';
import {
  AuthUser,
  getCurrentUser,
  signIn as clientSignIn,
  signUp as clientSignUp,
  signOut as clientSignOut,
} from '../../lib/authClient';

interface AuthContextValue {
  user: AuthUser | null;
  isLoading: boolean;
  signIn: (email: string, password: string) => Promise<void>;
  /** Creates the account and signs in. */
  signUp: (email: string, password: string, displayName?: string) => Promise<void>;
  signOut: () => void;
}

const AuthContext = createContext<AuthContextValue | undefined>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<AuthUser | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    setUser(getCurrentUser());
    setIsLoading(false);
  }, []);

  async function signIn(email: string, password: string): Promise<void> {
    setUser(await clientSignIn(email, password));
  }

  async function signUp(email: string, password: string, displayName?: string): Promise<void> {
    setUser(await clientSignUp(email, password, displayName));
  }

  function signOut(): void {
    clientSignOut();
    setUser(null);
  }

  return (
    <AuthContext.Provider value={{ user, isLoading, signIn, signUp, signOut }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth(): AuthContextValue {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}
