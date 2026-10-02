import 'package:flutter_test/flutter_test.dart';
import 'package:personal_memory_os/core/models/capture.dart';
import 'package:personal_memory_os/core/utils/action_suggestions.dart';

final t0 = DateTime(2026, 10, 1, 12);

Capture capture(String id, List<ExtractedAction> actions,
        {String? eventId, DateTime? at}) =>
    Capture(
      id: id,
      userId: 'u',
      eventId: eventId,
      type: CaptureType.voice,
      aiResult: CaptureAiResult(summary: 's', actions: actions),
      createdAt: at ?? t0,
      updatedAt: t0,
    );

void main() {
  test('lists actions from captures, soonest due first, undated last', () {
    final s = pendingSuggestions([
      capture('c1', [
        ExtractedAction(title: 'Read docs'),
        ExtractedAction(title: 'Submit prototype', dueAt: DateTime(2026, 10, 20)),
        ExtractedAction(title: 'Register', dueAt: DateTime(2026, 10, 5)),
      ]),
    ], {});
    expect(s.map((e) => e.action.title), ['Register', 'Submit prototype', 'Read docs']);
  });

  test('handled and already-created actions are not suggested again', () {
    final c = capture('c1', [
      ExtractedAction(title: 'Done already', reminderCreated: true),
      ExtractedAction(title: 'Dismissed'),
      ExtractedAction(title: 'Keep me'),
    ]);
    final handled = {ActionSuggestion(c, c.aiResult!.actions[1]).key};
    final s = pendingSuggestions([c], handled);
    expect(s.map((e) => e.action.title), ['Keep me']);
  });

  test('keys are case and whitespace insensitive', () {
    final c = capture('c1', [ExtractedAction(title: '  Submit Prototype ')]);
    expect(ActionSuggestion(c, c.aiResult!.actions.first).key, 'c1::submit prototype');
  });

  test('filters by event and orders newest capture first', () {
    final s = pendingSuggestions([
      capture('old', [ExtractedAction(title: 'a')], eventId: 'e1', at: t0),
      capture('new', [ExtractedAction(title: 'b')], eventId: 'e1', at: t0.add(const Duration(hours: 1))),
      capture('other', [ExtractedAction(title: 'c')], eventId: 'e2'),
    ], {}, eventId: 'e1');
    expect(s.map((e) => e.capture.id), ['new', 'old']);
  });

  test('captures without AI results contribute nothing', () {
    final bare = Capture(
      id: 'x', userId: 'u', type: CaptureType.photo, createdAt: t0, updatedAt: t0,
    );
    expect(pendingSuggestions([bare], {}), isEmpty);
  });
}
