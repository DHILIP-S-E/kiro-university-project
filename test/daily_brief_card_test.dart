import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_memory_os/core/utils/daily_brief.dart';
import 'package:personal_memory_os/features/today/widgets/daily_brief_card.dart';

Widget wrap(DailyBrief brief) =>
    MaterialApp(home: Scaffold(body: DailyBriefCard(brief: brief)));

void main() {
  testWidgets('shows the empty message', (tester) async {
    await tester.pumpWidget(wrap(const DailyBrief()));
    expect(find.text('Nothing due. Enjoy the quiet.'), findsOneWidget);
  });

  testWidgets('lists overdue, today and deadline sections', (tester) async {
    final at = DateTime(2026, 10, 4, 9, 30);
    await tester.pumpWidget(wrap(DailyBrief(
      overdue: [BriefItem('Pay bill', at)],
      today: [BriefItem('Workshop', at)],
      deadlines: [BriefItem('Register', at, isDeadline: true)],
    )));
    expect(find.text('Overdue'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Deadlines this week'), findsOneWidget);
    expect(find.text('Pay bill'), findsOneWidget);
    expect(find.text('09:30'), findsNWidgets(2));
    expect(find.text('10/4'), findsOneWidget);
  });

  testWidgets('long sections are capped with a +N more line', (tester) async {
    final at = DateTime(2026, 10, 4, 9);
    await tester.pumpWidget(wrap(DailyBrief(
      today: [for (var i = 0; i < 8; i++) BriefItem('item $i', at)],
    )));
    expect(find.text('+3 more'), findsOneWidget);
    expect(find.text('item 7'), findsNothing);
  });
}
