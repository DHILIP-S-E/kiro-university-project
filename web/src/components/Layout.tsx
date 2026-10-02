import { NavLink, Outlet } from 'react-router-dom';
import { useAuth } from '../features/auth/AuthContext';
import Button from './ui/Button';

interface NavItem {
  label: string;
  to: string;
}

const navItems: NavItem[] = [
  { label: 'Dashboard', to: '/' },
  { label: 'Reminders', to: '/reminders' },
  { label: 'Events', to: '/events' },
  { label: 'Capture', to: '/capture' },
  { label: 'Memory', to: '/memory' },
  { label: 'Settings', to: '/settings' },
];

function getUserEmail(user: { getUsername?: () => string } | null): string {
  if (!user) return '';
  if (typeof user.getUsername === 'function') return user.getUsername();
  return '';
}

export default function Layout() {
  const { user, signOut } = useAuth();
  const email = getUserEmail(user);

  return (
    <div className="flex min-h-screen bg-background">
      {/* Sidebar */}
      <aside
        className="fixed top-0 left-0 h-full bg-surface border-r border-border flex flex-col"
        style={{ width: '240px' }}
      >
        {/* Logo / brand */}
        <div className="px-5 py-6 border-b border-border">
          <span className="text-textPrimary font-bold text-lg tracking-tight">
            Memory OS
          </span>
        </div>

        {/* Nav */}
        <nav className="flex-1 px-3 py-4 space-y-1 overflow-y-auto">
          {navItems.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.to === '/'}
              className={({ isActive }) =>
                [
                  'flex items-center px-3 py-2 rounded-lg text-sm font-medium transition-colors',
                  isActive
                    ? 'bg-accent text-white'
                    : 'text-textSecondary hover:bg-card hover:text-textPrimary',
                ].join(' ')
              }
            >
              {item.label}
            </NavLink>
          ))}
        </nav>

        {/* User area */}
        <div className="px-4 py-4 border-t border-border space-y-2">
          {email && (
            <p className="text-textMuted text-xs truncate" title={email}>
              {email}
            </p>
          )}
          <Button variant="ghost" size="sm" onClick={signOut} className="w-full justify-start">
            Sign Out
          </Button>
        </div>
      </aside>

      {/* Main content */}
      <main
        className="flex-1 overflow-y-auto"
        style={{ marginLeft: '240px' }}
      >
        {/* Top bar */}
        <header className="sticky top-0 z-10 bg-background border-b border-border px-6 py-3 flex items-center justify-between">
          <div /> {/* spacer */}
          <div className="flex items-center gap-3">
            {email && (
              <span className="text-textSecondary text-sm">{email}</span>
            )}
            <Button variant="ghost" size="sm" onClick={signOut}>
              Sign Out
            </Button>
          </div>
        </header>

        <div className="p-6">
          <Outlet />
        </div>
      </main>
    </div>
  );
}
