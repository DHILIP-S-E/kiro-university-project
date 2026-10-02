import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { isAfter, parseISO, subDays } from 'date-fns';
import { listReminders } from '../reminders/remindersApi';
import { listEvents } from '../events/eventsApi';
import { listCaptures } from '../capture/capturesApi';
import Badge from '../../components/ui/Badge';
import Card from '../../components/ui/Card';
import LoadingSpinner from '../../components/ui/LoadingSpinner';
import type { Reminder, Event, Capture } from '../../types/index';

export default function DashboardScreen() {
  const now = new Date();
  const sevenDaysAgo = subDays(now, 7);

  const remindersQuery = useQuery({
    queryKey: ['reminders', 'active'],
    queryFn: () => listReminders({ reminder_status: 'active' }),
  });

  const eventsQuery = useQuery({
    queryKey: ['events'],
    queryFn: () => listEvents(),
  });

  const capturesQuery = useQuery({
    queryKey: ['captures'],
    queryFn: () => listCaptures(),
  });

  const isLoading =
    remindersQuery.isLoading || eventsQuery.isLoading || capturesQuery.isLoading;

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-64">
        <LoadingSpinner size="lg" />
      </div>
    );
  }

  const activeReminders: Reminder[] = remindersQuery.data ?? [];
  const allEvents: Event[] = eventsQuery.data ?? [];
  const allCaptures: Capture[] = capturesQuery.data ?? [];

  // Overdue: active reminder with scheduled_at in the past
  const overdueReminders = activeReminders.filter((r) => {
    if (!r.scheduled_at) return false;
    return isAfter(now, parseISO(r.scheduled_at));
  });

  // Upcoming events sorted by start_at asc, next 3
  const upcomingEvents = [...allEvents]
    .filter((e) => isAfter(parseISO(e.start_at), now))
    .sort((a, b) => parseISO(a.start_at).getTime() - parseISO(b.start_at).getTime())
    .slice(0, 3);

  // Captures in the last 7 days
  const recentCaptures = allCaptures
    .filter((c) => isAfter(parseISO(c.created_at), sevenDaysAgo))
    .slice(0, 5);

  const capturesThisWeek = allCaptures.filter((c) =>
    isAfter(parseISO(c.created_at), sevenDaysAgo),
  ).length;

  return (
    <div className="space-y-6">
      <h1 className="text-textPrimary text-2xl font-bold">Dashboard</h1>

      {/* Overdue reminders — error section */}
      {overdueReminders.length > 0 && (
        <div className="rounded-xl border border-error bg-red-950/30 p-4 space-y-2">
          <h2 className="text-error font-semibold text-sm uppercase tracking-wide">
            ⚠ Overdue Reminders ({overdueReminders.length})
          </h2>
          <ul className="space-y-2">
            {overdueReminders.map((r) => (
              <li key={r.id} className="flex items-center justify-between">
                <span className="text-textPrimary text-sm">{r.title}</span>
                <div className="flex items-center gap-2">
                  <Badge label={r.priority} />
                  {r.scheduled_at && (
                    <span className="text-error text-xs">
                      {new Date(r.scheduled_at).toLocaleString()}
                    </span>
                  )}
                </div>
              </li>
            ))}
          </ul>
          <Link to="/reminders" className="text-xs text-accent hover:underline">
            View all reminders →
          </Link>
        </div>
      )}

      {/* Summary row */}
      <div className="grid grid-cols-3 gap-4">
        <Card variant="card">
          <p className="text-textMuted text-xs uppercase tracking-wide mb-1">Active Reminders</p>
          <p className="text-textPrimary text-3xl font-bold">{activeReminders.length}</p>
        </Card>
        <Card variant="card">
          <p className="text-textMuted text-xs uppercase tracking-wide mb-1">Upcoming Events</p>
          <p className="text-textPrimary text-3xl font-bold">
            {allEvents.filter((e) => isAfter(parseISO(e.start_at), now)).length}
          </p>
        </Card>
        <Card variant="card">
          <p className="text-textMuted text-xs uppercase tracking-wide mb-1">Captures This Week</p>
          <p className="text-textPrimary text-3xl font-bold">{capturesThisWeek}</p>
        </Card>
      </div>

      {/* Upcoming events */}
      <section>
        <div className="flex items-center justify-between mb-3">
          <h2 className="text-textPrimary font-semibold">Next Events</h2>
          <Link to="/events" className="text-xs text-accent hover:underline">
            View all →
          </Link>
        </div>
        {upcomingEvents.length === 0 ? (
          <p className="text-textMuted text-sm">No upcoming events.</p>
        ) : (
          <div className="space-y-3">
            {upcomingEvents.map((ev) => (
              <Link key={ev.id} to={`/events/${ev.id}`}>
                <Card variant="card" className="hover:border hover:border-accent transition-colors">
                  <div className="flex items-start justify-between">
                    <div>
                      <p className="text-textPrimary font-medium">{ev.title}</p>
                      <p className="text-textSecondary text-xs mt-0.5">
                        {new Date(ev.start_at).toLocaleString()}
                        {ev.location ? ` · ${ev.location}` : ''}
                        {ev.is_virtual ? ' · Virtual' : ''}
                      </p>
                    </div>
                    <Badge label={ev.event_type} />
                  </div>
                </Card>
              </Link>
            ))}
          </div>
        )}
      </section>

      {/* Recent captures */}
      <section>
        <div className="flex items-center justify-between mb-3">
          <h2 className="text-textPrimary font-semibold">Recent Captures</h2>
          <Link to="/capture" className="text-xs text-accent hover:underline">
            View all →
          </Link>
        </div>
        {recentCaptures.length === 0 ? (
          <p className="text-textMuted text-sm">No captures in the last 7 days.</p>
        ) : (
          <Card variant="surface" className="divide-y divide-border">
            {recentCaptures.map((c) => (
              <div key={c.id} className="flex items-center justify-between py-2 first:pt-0 last:pb-0">
                <div>
                  <p className="text-textPrimary text-sm capitalize">{c.capture_type}</p>
                  {c.content && (
                    <p className="text-textMuted text-xs truncate max-w-xs">{c.content}</p>
                  )}
                </div>
                <Badge label={c.processing_status} />
              </div>
            ))}
          </Card>
        )}
      </section>
    </div>
  );
}
