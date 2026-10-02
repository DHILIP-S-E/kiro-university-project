import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_memory_os/core/utils/daily_brief.dart';
import 'package:personal_memory_os/core/widget/widget_snapshot.dart';

final now = DateTime(2026, 10, 1, 12);

BriefItem item(String t, DateTime at, {bool deadline = false}) =>
    BriefItem(t, at, isDeadline: deadline);

void main() {
  test('empty brief gives an empty widget with the quiet headline', () {
    final s = WidgetSnapshot.fromBrief(const DailyBrief(), now);
    expect(s.isEmpty, isTrue);
    expect(s.headline, 'Nothing due. Enjoy the quiet.');
  });

  test('overdue first, then today, then deadlines, with formatted times', () {
    final s = WidgetSnapshot.fromBrief(
      DailyBrief(
        overdue: [item('Pay bill', DateTime(2026, 10, 1, 9, 5))],
        today: [item('Workshop', DateTime(2026, 10, 1, 14, 30))],
        deadlines: [item('Register', DateTime(2026, 10, 4, 23, 59), deadline: true)],
      ),
      now,
    );
    expect(s.lines.map((l) => l.title), ['Pay bill', 'Workshop', 'Register']);
    expect(s.lines.map((l) => l.when), ['09:05', '14:30', 'Oct 4']);
    expect(s.lines.map((l) => l.overdue), [true, false, false]);
    expect(s.lines.map((l) => l.deadline), [false, false, true]);
    expect(s.headline, '1 overdue · 1 today · 1 deadline this week');
  });

  test('caps at four lines, keeping the most urgent', () {
    final many = [for (var i = 0; i < 6; i++) item('late $i', DateTime(2026, 10, 1, 8, i))];
    final s = WidgetSnapshot.fromBrief(
      DailyBrief(overdue: many, today: [item('later', DateTime(2026, 10, 1, 15))]),
      now,
    );
    expect(s.lines.length, WidgetSnapshot.maxLines);
    expect(s.lines.every((l) => l.overdue), isTrue, reason: 'overdue crowds out the rest');
  });

  test('JSON carries everything the native side needs and survives encoding', () {
    final s = WidgetSnapshot.fromBrief(
      DailyBrief(today: [item('Workshop', DateTime(2026, 10, 1, 14, 30))]),
      now,
    );
    final back = jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>;
    expect(back['headline'], '1 today');
    expect(back['generatedAtMillis'], now.millisecondsSinceEpoch);
    final line = (back['lines'] as List).single as Map<String, dynamic>;
    expect(line['atMillis'], DateTime(2026, 10, 1, 14, 30).millisecondsSinceEpoch);
    expect(line['when'], '14:30');
  });
}
