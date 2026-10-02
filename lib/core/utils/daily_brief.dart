import 'package:personal_memory_os/core/models/event.dart';
import 'package:personal_memory_os/core/models/reminder.dart';

/// One line in the agenda: something that happens at [at].
class BriefItem {
  final String title;
  final DateTime at;
  final bool isDeadline;

  const BriefItem(this.title, this.at, {this.isDeadline = false});
}

/// "What do I need to know right now": overdue work, today's agenda, and the
/// deadlines coming up. Pure and deterministic — no network, so it works offline.
class DailyBrief {
  final List<BriefItem> overdue;
  final List<BriefItem> today;
  final List<BriefItem> deadlines;

  const DailyBrief({
    this.overdue = const [],
    this.today = const [],
    this.deadlines = const [],
  });

  bool get isEmpty => overdue.isEmpty && today.isEmpty && deadlines.isEmpty;

  /// One-sentence summary, most urgent first.
  String get headline {
    if (isEmpty) return 'Nothing due. Enjoy the quiet.';
    final parts = <String>[];
    if (overdue.isNotEmpty) parts.add('${overdue.length} overdue');
    if (today.isNotEmpty) parts.add('${today.length} today');
    if (deadlines.isNotEmpty) {
      parts.add('${deadlines.length} deadline${deadlines.length == 1 ? '' : 's'} this week');
    }
    return parts.join(' · ');
  }
}

/// Builds the brief for [now]. Deadlines look [deadlineDays] ahead and exclude
/// anything already shown under today.
DailyBrief buildBrief({
  required List<Reminder> reminders,
  required List<Event> events,
  required DateTime now,
  int deadlineDays = 7,
}) {
  final dayStart = DateTime(now.year, now.month, now.day);
  final dayEnd = dayStart.add(const Duration(days: 1));
  final horizon = dayStart.add(Duration(days: deadlineDays + 1));

  int byTime(BriefItem a, BriefItem b) => a.at.compareTo(b.at);

  final active = reminders.where(
    (r) => r.status == ReminderStatus.active && r.scheduledAt != null,
  );

  final overdue = active
      .where((r) => r.scheduledAt!.isBefore(now))
      .map((r) => BriefItem(r.title, r.scheduledAt!))
      .toList()
    ..sort(byTime);

  final today = <BriefItem>[
    for (final r in active)
      if (!r.scheduledAt!.isBefore(now) && r.scheduledAt!.isBefore(dayEnd))
        BriefItem(r.title, r.scheduledAt!),
    for (final e in events)
      if (e.status != EventStatus.cancelled &&
          !e.startAt.isBefore(dayStart) &&
          e.startAt.isBefore(dayEnd))
        BriefItem(e.title, e.startAt),
  ]..sort(byTime);

  final deadlines = <BriefItem>[
    for (final r in active)
      if (r.reminderType == ReminderType.deadline &&
          !r.scheduledAt!.isBefore(dayEnd) &&
          r.scheduledAt!.isBefore(horizon))
        BriefItem(r.title, r.scheduledAt!, isDeadline: true),
    for (final e in events)
      for (final d in e.deadlines)
        if (!d.deadlineAt.isBefore(dayEnd) && d.deadlineAt.isBefore(horizon))
          BriefItem('${d.title} — ${e.title}', d.deadlineAt, isDeadline: true),
  ]..sort(byTime);

  return DailyBrief(overdue: overdue, today: today, deadlines: deadlines);
}
