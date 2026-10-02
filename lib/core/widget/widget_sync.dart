import 'dart:async';
import 'dart:convert';

import 'package:personal_memory_os/core/providers/event_provider.dart';
import 'package:personal_memory_os/core/providers/reminder_provider.dart';
import 'package:personal_memory_os/core/utils/daily_brief.dart';
import 'package:personal_memory_os/core/widget/home_widget_bridge.dart';
import 'package:personal_memory_os/core/widget/widget_snapshot.dart';

/// Keeps the home-screen widget current: whenever reminders or events change it
/// rebuilds the daily brief and pushes it to the platform. Changes are batched
/// (several arrive together after a sync) and an unchanged widget is not redrawn.
class WidgetSync {
  final ReminderProvider _reminders;
  final EventProvider _events;
  final HomeWidgetBridge _bridge;
  final DateTime Function() _now;
  final Duration _debounce;

  Timer? _timer;
  String? _lastSent;

  WidgetSync(
    this._reminders,
    this._events,
    this._bridge, {
    DateTime Function()? now,
    Duration debounce = const Duration(milliseconds: 600),
  })  : _now = now ?? DateTime.now,
        _debounce = debounce;

  void start() {
    _reminders.addListener(_schedule);
    _events.addListener(_schedule);
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(_debounce, push);
  }

  /// Build and send the current snapshot now. Skipped when nothing visible changed.
  Future<void> push() async {
    final now = _now();
    final snapshot = WidgetSnapshot.fromBrief(
      buildBrief(reminders: _reminders.reminders, events: _events.events, now: now),
      now,
    );
    final visible = jsonEncode({
      'headline': snapshot.headline,
      'lines': snapshot.lines.map((l) => l.toJson()).toList(),
    });
    if (visible == _lastSent) return;
    _lastSent = visible;
    await _bridge.update(snapshot);
  }

  void dispose() {
    _timer?.cancel();
    _reminders.removeListener(_schedule);
    _events.removeListener(_schedule);
  }
}
