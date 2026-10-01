import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:personal_memory_os/core/sync/sync_queue.dart';

/// Flushes the [SyncQueue] on app start and every time connectivity returns.
class SyncCoordinator {
  final SyncQueue _queue;
  final Future<void> Function(SyncOperation op) _execute;
  final void Function(FlushResult result)? onFlushed;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  SyncCoordinator(this._queue, this._execute, {this.onFlushed});

  void start() {
    _flush();
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) _flush();
    });
  }

  Future<void> _flush() async {
    final result = await _queue.flush(_execute);
    onFlushed?.call(result);
  }

  Future<void> dispose() async => _sub?.cancel();
}
