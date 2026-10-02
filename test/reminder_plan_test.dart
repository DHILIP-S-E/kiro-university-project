import 'package:flutter_test/flutter_test.dart';
import 'package:personal_memory_os/core/models/event.dart';
import 'package:personal_memory_os/core/utils/reminder_plan.dart';

final now = DateTime(2026, 10, 1, 12);

Event event(EventType type, DateTime start, {List<EventDeadline> deadlines = const []}) => Event(
      id: 'e',
      userId: 'u',
      title: 'AWS Hackathon',
      eventType: type,
      startAt: start,
      deadlines: deadlines,
      createdAt: now,
      updatedAt: now,
    );

EventDeadline deadline(String title, DateTime at) => EventDeadline(
      id: 'd',
      eventId: 'e',
      userId: 'u',
      title: title,
      deadlineType: DeadlineType.registration,
      deadlineAt: at,
      createdAt: now,
    );

void main() {
  test('hackathon: -1d, -1h, -30m before start plus deadline reminders', () {
    final plan = buildReminderPlan(
      event(EventType.hackathon, now.add(const Duration(days: 5)),
          deadlines: [deadline('Register', now.add(const Duration(days: 4)))]),
      now,
    );
    final titles = plan.map((p) => p.title).toList();
    expect(titles, containsAll([
      'AWS Hackathon starts in 1d',
      'AWS Hackathon starts in 1h',
      'AWS Hackathon starts in 30m',
      'Register due in 3d — AWS Hackathon',
      'Register due in 1d — AWS Hackathon',
      'Register due in 3h — AWS Hackathon',
    ]));
    expect(plan.where((p) => p.isDeadline).length, 3);
  });

  test('only future reminders, soonest first', () {
    final plan = buildReminderPlan(
      event(EventType.hackathon, now.add(const Duration(minutes: 45))),
      now,
    );
    expect(plan.map((p) => p.title), ['AWS Hackathon starts in 30m']);
    for (var i = 1; i < plan.length; i++) {
      expect(plan[i - 1].at.isAfter(plan[i].at), isFalse);
    }
  });

  test('an event in the past has no plan', () {
    expect(buildReminderPlan(event(EventType.meeting, now.subtract(const Duration(days: 1))), now), isEmpty);
  });

  test('types without a dedicated policy use the default offsets', () {
    final plan = buildReminderPlan(event(EventType.subscription, now.add(const Duration(days: 3))), now);
    expect(plan.map((p) => p.title), ['AWS Hackathon starts in 1d', 'AWS Hackathon starts in 30m']);
  });

  test('every event type produces a sensible plan for a far-future event', () {
    for (final type in EventType.values) {
      final plan = buildReminderPlan(event(type, now.add(const Duration(days: 30))), now);
      expect(plan, isNotEmpty, reason: '$type');
      expect(plan.every((p) => p.at.isAfter(now) && p.at.isBefore(now.add(const Duration(days: 30)))), isTrue);
    }
  });
}
