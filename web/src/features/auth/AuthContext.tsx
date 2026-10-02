import React, { createContext, useContext, useEffect, useState } from 'react';
import { CognitoUser, ISignUpResult } from 'amazon-cognito-identity-js';
import {
  getCurrentUser,
  signIn as cognitoSignIn,
  signUp as cognitoSignUp,
  confirmSignUp as cognitoConfirmSignUp,
  signOut as cognitoSignOut,
  forgotPassword as cognitoForgotPassword,
  confirmForgotPassword as cognitoConfirmForgotPassword,
} from '../../lib/cognitoClient';

interface AuthContextValue {
  user: CognitoUser | null;
  isLoading: boolean;
  signIn: (email: string, password: string) => Promise<void>;
  signUp: (email: string, password: string) => Promise<ISignUpResult>;
  confirmSignUp: (email: string, code: string) => Promise<void>;
  signOut: () => void;
  forgotPassword: (email: string) => Promise<void>;
  confirmForgotPassword: (email: string, code: string, newPassword: string) => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | undefined>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<CognitoUser | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    const currentUser = getCurrentUser();
    setUser(currentUser);
    setIsLoading(false);
  }, []);

  async function signIn(email: string, password: string): Promise<void> {
    const cognitoUser = await cognitoSignIn(email, password);
    setUser(cognitoUser);
  }

  async function signUp(email: string, password: string): Promise<ISignUpResult> {
    return cognitoSignUp(email, password);
  }

  async function confirmSignUp(email: string, code: string): Promise<void> {
    return cognitoConfirmSignUp(email, code);
  }

  function signOut(): void {
    cognitoSignOut();
    setUser(null);
  }

  async function forgotPassword(email: string): Promise<void> {
    return cognitoForgotPassword(email);
  }

  async function confirmForgotPassword(
    email: string,
    code: string,
    newPassword: string,
  ): Promise<void> {
    return cognitoConfirmForgotPassword(email, code, newPassword);
  }

  return (
    <AuthContext.Provider
      value={{
        user,
        isLoading,
        signIn,
        signUp,
        confirmSignUp,
        signOut,
        forgotPassword,
        confirmForgotPassword,
      }}
    >
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
