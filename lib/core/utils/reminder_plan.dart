import 'package:personal_memory_os/core/models/event.dart';

/// One reminder in a smart plan for an event.
class PlannedReminder {
  final String title;
  final DateTime at;
  final bool isDeadline;

  const PlannedReminder(this.title, this.at, {this.isDeadline = false});
}

/// Minutes before the event starts, by event type. Mirrors the backend's
/// app/services/event_policy.py so the preview and the cloud agree.
const _eventOffsets = <EventType, List<int>>{
  EventType.hackathon: [1440, 60, 30],
  EventType.conference: [1440, 120, 30],
  EventType.workshop: [1440, 60, 15],
  EventType.webinar: [60, 10],
  EventType.meetup: [180, 30],
  EventType.meeting: [30, 10],
  EventType.appointment: [1440, 60],
  EventType.deadline: [4320, 1440, 180],
};
const _defaultOffsets = [1440, 30];
const _deadlineOffsets = [4320, 1440, 180]; // -3d, -1d, -3h

String _label(int minutes) {
  if (minutes % 1440 == 0) return '${minutes ~/ 1440}d';
  if (minutes % 60 == 0) return '${minutes ~/ 60}h';
  return '${minutes}m';
}

/// Reminders for an event: event-day reminders plus registration/submission
/// deadline reminders. Only future instants, soonest first. Pure.
List<PlannedReminder> buildReminderPlan(Event event, DateTime now) {
  final plan = <PlannedReminder>[];
  for (final minutes in _eventOffsets[event.eventType] ?? _defaultOffsets) {
    final at = event.startAt.subtract(Duration(minutes: minutes));
    if (at.isAfter(now)) {
      plan.add(PlannedReminder('${event.title} starts in ${_label(minutes)}', at));
    }
  }
  for (final deadline in event.deadlines) {
    for (final minutes in _deadlineOffsets) {
      final at = deadline.deadlineAt.subtract(Duration(minutes: minutes));
      if (at.isAfter(now)) {
        plan.add(PlannedReminder(
          '${deadline.title} due in ${_label(minutes)} — ${event.title}',
          at,
          isDeadline: true,
        ));
      }
    }
  }
  plan.sort((a, b) => a.at.compareTo(b.at));
  return plan;
}
