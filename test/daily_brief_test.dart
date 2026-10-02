import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_memory_os/core/models/event.dart';
import 'package:personal_memory_os/core/models/reminder.dart';
import 'package:personal_memory_os/core/utils/daily_brief.dart';

final now = DateTime(2026, 10, 1, 12);

Reminder reminder(String id, DateTime? at,
        {ReminderType type = ReminderType.time,
        ReminderStatus status = ReminderStatus.active}) =>
    Reminder(
      id: id,
      userId: 'u',
      title: id,
      reminderType: type,
      scheduledAt: at,
      status: status,
      createdAt: now,
      updatedAt: now,
    );

Event event(String id, DateTime start,
        {List<EventDeadline> deadlines = const [],
        EventStatus status = EventStatus.upcoming}) =>
    Event(
      id: id,
      userId: 'u',
      title: id,
      eventType: EventType.hackathon,
      startAt: start,
      status: status,
      deadlines: deadlines,
      createdAt: now,
      updatedAt: now,
    );

void main() {
  test('empty brief says so', () {
    final b = buildBrief(reminders: [], events: [], now: now);
    expect(b.isEmpty, isTrue);
    expect(b.headline, 'Nothing due. Enjoy the quiet.');
  });

  test('splits overdue, today and upcoming deadlines', () {
    final b = buildBrief(
      now: now,
      reminders: [
        reminder('late', now.subtract(const Duration(hours: 3))),
        reminder('later-today', now.add(const Duration(hours: 4))),
        reminder('tomorrow-deadline', now.add(const Duration(days: 1)),
            type: ReminderType.deadline),
        reminder('far', now.add(const Duration(days: 30)),
            type: ReminderType.deadline),
      ],
      events: [
        event('workshop', now.add(const Duration(hours: 2))),
        event('hack', now.add(const Duration(days: 20)), deadlines: [
          EventDeadline(
            id: 'd',
            eventId: 'hack',
            userId: 'u',
            title: 'Register',
            deadlineType: DeadlineType.registration,
            deadlineAt: now.add(const Duration(days: 3)),
            createdAt: now,
          ),
        ]),
      ],
    );
    expect(b.overdue.map((i) => i.title), ['late']);
    expect(b.today.map((i) => i.title), ['workshop', 'later-today']);
    expect(b.deadlines.map((i) => i.title),
        ['tomorrow-deadline', 'Register — hack']);
    expect(b.headline, '1 overdue · 2 today · 2 deadlines this week');
  });

  test('completed, cancelled and undated items are excluded', () {
    final b = buildBrief(now: now, events: [
      event('cancelled', now.add(const Duration(hours: 1)),
          status: EventStatus.cancelled),
    ], reminders: [
      reminder('done', now.add(const Duration(hours: 1)),
          status: ReminderStatus.completed),
      reminder('undated', null),
    ]);
    expect(b.isEmpty, isTrue);
  });

  test('randomised: sections never overlap and are sorted', () {
    for (var seed = 0; seed < 200; seed++) {
      final rnd = Random(seed);
      final reminders = List.generate(
        rnd.nextInt(15),
        (i) => reminder(
          'r$i',
          now.add(Duration(minutes: rnd.nextInt(60 * 24 * 14) - 60 * 24 * 3)),
          type: rnd.nextBool() ? ReminderType.deadline : ReminderType.time,
        ),
      );
      final b = buildBrief(reminders: reminders, events: [], now: now);
      final ids = [...b.overdue, ...b.today, ...b.deadlines].map((i) => i.title);
      expect(ids.toSet().length, ids.length, reason: 'seed $seed: no item twice');
      for (final section in [b.overdue, b.today, b.deadlines]) {
        for (var i = 1; i < section.length; i++) {
          expect(section[i - 1].at.isAfter(section[i].at), isFalse);
        }
      }
      expect(b.overdue.every((i) => i.at.isBefore(now)), isTrue);
    }
  });
}
