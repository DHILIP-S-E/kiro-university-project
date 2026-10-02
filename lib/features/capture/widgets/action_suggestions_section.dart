import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:personal_memory_os/core/models/reminder.dart';
import 'package:personal_memory_os/core/providers/auth_provider.dart';
import 'package:personal_memory_os/core/providers/capture_provider.dart';
import 'package:personal_memory_os/core/providers/reminder_provider.dart';
import 'package:personal_memory_os/core/utils/action_suggestions.dart';
import 'package:personal_memory_os/shared/widgets/ai_suggestion_banner.dart';

/// Memory -> Reminder: turns "I need to submit the prototype by October 20",
/// spoken in a capture, into a reminder with one tap. AI suggests; the user
/// confirms (nothing is created silently).
class ActionSuggestionsSection extends StatelessWidget {
  /// Only suggestions from this event's captures; null = all captures.
  final String? eventId;
  final int maxItems;

  const ActionSuggestionsSection({super.key, this.eventId, this.maxItems = 3});

  @override
  Widget build(BuildContext context) {
    final pending =
        context.watch<CaptureProvider>().pendingActions(eventId: eventId);
    if (pending.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final s in pending.take(maxItems))
          AiSuggestionBanner(
            key: ValueKey(s.key),
            message: s.hasDate
                ? 'You mentioned a deadline — create reminder?'
                : 'You mentioned something to do — create reminder?',
            detail: _detail(s),
            confirmLabel: s.hasDate ? 'Create' : 'Pick a date',
            dismissLabel: 'Ignore',
            onConfirm: () => _confirm(context, s),
            onDismiss: () =>
                context.read<CaptureProvider>().markActionHandled(s),
          ),
      ],
    );
  }

  static String _detail(ActionSuggestion s) {
    final due = s.action.dueAt;
    if (due == null) return s.action.title;
    return '${s.action.title} · due ${DateFormat.MMMd().format(due)}';
  }

  Future<void> _confirm(BuildContext context, ActionSuggestion s) async {
    final reminders = context.read<ReminderProvider>();
    final captures = context.read<CaptureProvider>();
    final userId = context.read<AuthProvider>().user?.id ?? 'local';
    final messenger = ScaffoldMessenger.of(context);

    var when = reminderTimeFor(s.action.dueAt, DateTime.now());
    if (when == null) {
      when = await _pickDateTime(context);
      if (when == null) return; // user backed out; the suggestion stays
    }

    final isDeadline = s.hasDate;
    final now = DateTime.now();
    try {
      await reminders.createReminder(Reminder(
        id: const Uuid().v4(),
        userId: userId,
        title: s.action.title,
        reminderType: isDeadline ? ReminderType.deadline : ReminderType.time,
        scheduledAt: when,
        priority: isDeadline ? ReminderPriority.high : ReminderPriority.medium,
        source: ReminderSource.aiExtracted,
        contextId: s.capture.eventId ?? s.capture.id,
        offsets: isDeadline
            ? const [ReminderOffset(offset: '-1d'), ReminderOffset(offset: '-3h')]
            : const [],
        createdAt: now,
        updatedAt: now,
      ));
      await captures.markActionHandled(s);
      messenger.showSnackBar(SnackBar(content: Text('Reminder created: ${s.action.title}')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not create reminder: $e')));
    }
  }

  Future<DateTime?> _pickDateTime(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (date == null || !context.mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }
}

/// When to remind for an extracted due date. A bare date (midnight) means "that
/// day": remind at 09:00. A past or missing date returns null so the user picks
/// a new one instead of getting a reminder that never fires. Pure.
DateTime? reminderTimeFor(DateTime? due, DateTime now) {
  if (due == null) return null;
  final atNine = (due.hour == 0 && due.minute == 0)
      ? DateTime(due.year, due.month, due.day, 9)
      : due;
  return atNine.isAfter(now) ? atNine : null;
}
