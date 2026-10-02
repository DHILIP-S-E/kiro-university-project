import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:personal_memory_os/core/models/event.dart';
import 'package:personal_memory_os/core/models/reminder.dart';
import 'package:personal_memory_os/core/providers/auth_provider.dart';
import 'package:personal_memory_os/core/providers/reminder_provider.dart';
import 'package:personal_memory_os/core/services/auth_service.dart';
import 'package:personal_memory_os/core/services/reminder_service.dart';
import 'package:personal_memory_os/features/events/widgets/reminder_plan_section.dart';

Event hackathon({List<EventDeadline> deadlines = const []}) {
  final start = DateTime.now().add(const Duration(days: 10));
  return Event(
    id: 'e1',
    userId: 'u',
    title: 'AWS Hackathon',
    eventType: EventType.hackathon,
    startAt: start,
    deadlines: deadlines,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

Widget host(ReminderProvider reminders, Event event) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: reminders),
        ChangeNotifierProvider.value(value: AuthProvider(StubAuthService())),
      ],
      child: MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: ReminderPlanSection(event: event))),
      ),
    );

void main() {
  testWidgets('offers the plan, creates every reminder on confirm, then hides',
      (tester) async {
    final reminders = ReminderProvider(StubReminderService());
    final event = hackathon();
    await tester.pumpWidget(host(reminders, event));

    expect(find.textContaining('Hackathon detected — create 3 reminders?'), findsOneWidget);
    final before = reminders.reminders.length;

    await tester.tap(find.text('Create all'));
    // The stub service simulates latency with timers; advance the fake clock.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    final created = reminders.reminders.skip(before).toList();
    expect(created.length, 3);
    expect(created.every((r) => r.source == ReminderSource.eventPolicy && r.contextId == 'e1'), isTrue);
    expect(find.textContaining('detected'), findsNothing, reason: 'plan applied, banner hidden');
  });

  testWidgets('shows nothing once the plan already exists', (tester) async {
    final reminders = ReminderProvider(StubReminderService());
    final event = hackathon();
    await tester.runAsync(() => reminders.createReminder(Reminder(
          id: 'r1',
          userId: 'u',
          title: 'x',
          reminderType: ReminderType.time,
          source: ReminderSource.eventPolicy,
          contextId: 'e1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        )));
    await tester.pumpWidget(host(reminders, event));
    expect(find.textContaining('detected'), findsNothing);
  });

  testWidgets('shows nothing for an event that is already over', (tester) async {
    final reminders = ReminderProvider(StubReminderService());
    final past = hackathon().copyWith(startAt: DateTime.now().subtract(const Duration(days: 2)));
    await tester.pumpWidget(host(reminders, past));
    expect(find.textContaining('detected'), findsNothing);
  });

  test('alreadyApplied only counts this event\'s policy reminders', () {
    final event = hackathon();
    Reminder r(String ctx, ReminderSource src) => Reminder(
          id: ctx, userId: 'u', title: 't', reminderType: ReminderType.time,
          source: src, contextId: ctx, createdAt: DateTime.now(), updatedAt: DateTime.now(),
        );
    expect(ReminderPlanSection.alreadyApplied(event, [r('e1', ReminderSource.manual)]), isFalse);
    expect(ReminderPlanSection.alreadyApplied(event, [r('other', ReminderSource.eventPolicy)]), isFalse);
    expect(ReminderPlanSection.alreadyApplied(event, [r('e1', ReminderSource.eventPolicy)]), isTrue);
  });
}
