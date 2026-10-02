import 'package:intl/intl.dart';
import 'package:personal_memory_os/core/utils/daily_brief.dart';

/// One row on the home-screen widget.
class WidgetLine {
  final String title;

  /// Pre-formatted: "09:30" for today, "Oct 4" for a later deadline.
  final String when;

  /// Epoch milliseconds, so the native side can mark a line that has passed
  /// since the last update without any Dart code running.
  final int atMillis;
  final bool overdue;
  final bool deadline;

  const WidgetLine({
    required this.title,
    required this.when,
    required this.atMillis,
    this.overdue = false,
    this.deadline = false,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'when': when,
        'atMillis': atMillis,
        'overdue': overdue,
        'deadline': deadline,
      };
}

/// Everything the widget shows, ready to draw. Built from the daily brief so the
/// widget, the Today screen and the notifications always agree.
class WidgetSnapshot {
  static const maxLines = 4;

  final String headline;
  final List<WidgetLine> lines;
  final int generatedAtMillis;

  const WidgetSnapshot({
    required this.headline,
    required this.lines,
    required this.generatedAtMillis,
  });

  bool get isEmpty => lines.isEmpty;

  /// Overdue first (most urgent), then what is left today, then upcoming
  /// deadlines; capped so it fits a small widget.
  factory WidgetSnapshot.fromBrief(DailyBrief brief, DateTime now) {
    final time = DateFormat.Hm();
    final day = DateFormat.MMMd();
    final lines = <WidgetLine>[
      for (final i in brief.overdue)
        WidgetLine(
          title: i.title,
          when: time.format(i.at),
          atMillis: i.at.millisecondsSinceEpoch,
          overdue: true,
        ),
      for (final i in brief.today)
        WidgetLine(
          title: i.title,
          when: time.format(i.at),
          atMillis: i.at.millisecondsSinceEpoch,
        ),
      for (final i in brief.deadlines)
        WidgetLine(
          title: i.title,
          when: day.format(i.at),
          atMillis: i.at.millisecondsSinceEpoch,
          deadline: true,
        ),
    ].take(maxLines).toList();

    return WidgetSnapshot(
      headline: brief.headline,
      lines: lines,
      generatedAtMillis: now.millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() => {
        'headline': headline,
        'generatedAtMillis': generatedAtMillis,
        'lines': lines.map((l) => l.toJson()).toList(),
      };
}
