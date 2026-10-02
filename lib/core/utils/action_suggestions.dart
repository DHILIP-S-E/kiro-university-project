import 'package:personal_memory_os/core/models/capture.dart';

/// An action the AI pulled out of a capture that the user has not yet turned
/// into a reminder or dismissed ("I need to submit the prototype by October 20").
class ActionSuggestion {
  final Capture capture;
  final ExtractedAction action;

  const ActionSuggestion(this.capture, this.action);

  /// Stable across app restarts: one suggestion per (capture, action title).
  String get key => '${capture.id}::${action.title.trim().toLowerCase()}';

  bool get hasDate => action.dueAt != null;
}

/// Suggestions still awaiting a decision, newest capture first, soonest due first
/// within a capture. Past-due items are kept: a missed deadline is exactly what
/// the user needs to see. Pure.
List<ActionSuggestion> pendingSuggestions(
  List<Capture> captures,
  Set<String> handledKeys, {
  String? eventId,
}) {
  final result = <ActionSuggestion>[];
  final sorted = [...captures]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  for (final capture in sorted) {
    if (eventId != null && capture.eventId != eventId) continue;
    final actions = capture.aiResult?.actions ?? const <ExtractedAction>[];
    final ordered = [...actions]..sort((a, b) {
        if (a.dueAt == null && b.dueAt == null) return 0;
        if (a.dueAt == null) return 1;
        if (b.dueAt == null) return -1;
        return a.dueAt!.compareTo(b.dueAt!);
      });
    for (final action in ordered) {
      if (action.reminderCreated) continue;
      final suggestion = ActionSuggestion(capture, action);
      if (handledKeys.contains(suggestion.key)) continue;
      result.add(suggestion);
    }
  }
  return result;
}
