/**
 * Email/password login against the backend's own /auth endpoints (no Cognito).
 *
 * The session lives in localStorage so a refresh keeps you signed in. The access
 * token is short-lived and refreshed quietly shortly before it expires; the
 * refresh token is only ever sent to /auth/refresh.
 */

const BASE_URL = import.meta.env.VITE_BACKEND_URL;

const KEYS = {
  access: 'pmos_access_token',
  refresh: 'pmos_refresh_token',
  user: 'pmos_user',
} as const;

export interface AuthUser {
  id: string;
  email: string;
  display_name: string | null;
}

interface LoginResponse {
  access_token: string;
  refresh_token: string;
  user: AuthUser;
}

/** The backend's own message ("Incorrect email or password", lockout, ...). */
async function errorMessage(res: Response, fallback: string): Promise<string> {
  try {
    const body = await res.json();
    const detail = body?.detail;
    if (typeof detail === 'string') return detail;
    if (Array.isArray(detail) && detail[0]?.msg) return String(detail[0].msg);
  } catch {
    /* not JSON */
  }
  return fallback;
}

async function authenticate(path: string, body: Record<string, unknown>): Promise<AuthUser> {
  let res: Response;
  try {
    res = await fetch(`${BASE_URL}${path}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
  } catch {
    throw new Error('Cannot reach the server. Check your connection.');
  }
  if (!res.ok) throw new Error(await errorMessage(res, 'Sign-in failed'));
  const data: LoginResponse = await res.json();
  localStorage.setItem(KEYS.access, data.access_token);
  localStorage.setItem(KEYS.refresh, data.refresh_token);
  localStorage.setItem(KEYS.user, JSON.stringify(data.user));
  return data.user;
}

export function signIn(email: string, password: string): Promise<AuthUser> {
  return authenticate('/auth/login', { email, password });
}

/** Creates the account and signs in at once (no verification step). */
export function signUp(email: string, password: string, displayName?: string): Promise<AuthUser> {
  return authenticate('/auth/register', { email, password, display_name: displayName });
}

export function signOut(): void {
  Object.values(KEYS).forEach((k) => localStorage.removeItem(k));
}

/** The signed-in user from storage, or null. */
export function getCurrentUser(): AuthUser | null {
  if (!localStorage.getItem(KEYS.access)) return null;
  try {
    return JSON.parse(localStorage.getItem(KEYS.user) ?? 'null');
  } catch {
    return null;
  }
}

/** Expiry (ms since epoch) of a JWT; null if unreadable. Not a security check. */
export function expiryOf(jwt: string): number | null {
  try {
    const payload = jwt.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
    const claims = JSON.parse(atob(payload));
    return typeof claims.exp === 'number' ? claims.exp * 1000 : null;
  } catch {
    return null;
  }
}

let refreshing: Promise<string | null> | null = null;

async function refreshAccessToken(): Promise<string | null> {
  const refresh = localStorage.getItem(KEYS.refresh);
  if (!refresh) return null;
  try {
    const res = await fetch(`${BASE_URL}/auth/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refresh_token: refresh }),
    });
    if (res.ok) {
      const { access_token } = await res.json();
      localStorage.setItem(KEYS.access, access_token);
      return access_token;
    }
    if (res.status === 401) signOut(); // refresh token expired or account deleted
  } catch {
    /* offline: keep the session and try again on the next call */
  }
  return localStorage.getItem(KEYS.access);
}

/** Access token for API calls, refreshed a minute before it expires. */
export async function getAccessToken(): Promise<string | null> {
  const access = localStorage.getItem(KEYS.access);
  if (!access) return null;
  const expiry = expiryOf(access);
  if (expiry !== null && Date.now() < expiry - 60_000) return access;
  refreshing ??= refreshAccessToken().finally(() => {
    refreshing = null;
  });
  return refreshing;
}
