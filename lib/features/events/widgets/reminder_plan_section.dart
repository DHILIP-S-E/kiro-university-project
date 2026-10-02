import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:personal_memory_os/core/models/event.dart';
import 'package:personal_memory_os/core/models/reminder.dart';
import 'package:personal_memory_os/core/providers/auth_provider.dart';
import 'package:personal_memory_os/core/providers/reminder_provider.dart';
import 'package:personal_memory_os/core/utils/reminder_plan.dart';
import 'package:personal_memory_os/shared/widgets/ai_suggestion_banner.dart';

/// "Hackathon detected — create all these reminders?" One tap creates the whole
/// plan (event-day + deadline reminders). Hidden once the plan has been applied
/// or when there is nothing left to remind about.
class ReminderPlanSection extends StatelessWidget {
  final Event event;

  const ReminderPlanSection({super.key, required this.event});

  /// True if this event's policy reminders already exist.
  static bool alreadyApplied(Event event, List<Reminder> reminders) =>
      reminders.any((r) =>
          r.source == ReminderSource.eventPolicy && r.contextId == event.id);

  @override
  Widget build(BuildContext context) {
    final reminders = context.watch<ReminderProvider>().reminders;
    if (alreadyApplied(event, reminders)) return const SizedBox.shrink();
    final plan = buildReminderPlan(event, DateTime.now());
    if (plan.isEmpty) return const SizedBox.shrink();

    final fmt = DateFormat.MMMd().add_jm();
    final preview = plan.take(3).map((p) => '${fmt.format(p.at)}  ${p.title}').join('\n');
    final more = plan.length > 3 ? '\n+${plan.length - 3} more' : '';

    return AiSuggestionBanner(
      message: '${_typeLabel(event.eventType)} detected — create ${plan.length} reminders?',
      detail: '$preview$more',
      confirmLabel: 'Create all',
      dismissLabel: 'Not now',
      onConfirm: () => _apply(context, plan),
      onDismiss: () {},
    );
  }

  static String _typeLabel(EventType type) {
    final name = type.name;
    return name[0].toUpperCase() + name.substring(1);
  }

  Future<void> _apply(BuildContext context, List<PlannedReminder> plan) async {
    final provider = context.read<ReminderProvider>();
    final userId = context.read<AuthProvider>().user?.id ?? 'local';
    final messenger = ScaffoldMessenger.of(context);
    final now = DateTime.now();
    var created = 0;
    try {
      for (final item in plan) {
        await provider.createReminder(Reminder(
          id: const Uuid().v4(),
          userId: userId,
          title: item.title,
          reminderType:
              item.isDeadline ? ReminderType.deadline : ReminderType.time,
          scheduledAt: item.at,
          priority:
              item.isDeadline ? ReminderPriority.high : ReminderPriority.medium,
          source: ReminderSource.eventPolicy,
          contextId: event.id,
          createdAt: now,
          updatedAt: now,
        ));
        created++;
      }
      messenger.showSnackBar(SnackBar(content: Text('Created $created reminders')));
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Created $created of ${plan.length}: $e')));
    }
  }
}
