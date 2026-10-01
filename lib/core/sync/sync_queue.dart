import 'dart:convert';

/// Sync state machine (spec R6.4): LOCAL_ONLY → SYNCING → SYNCED | CONFLICT | FAILED.
/// SYNCED operations are removed from the queue, so they are never persisted.
enum SyncState { localOnly, syncing, synced, conflict, failed }

enum SyncOpType { createReminder, uploadCapture, createNote, createLink }

/// Minimal async key-value persistence. Backed by SharedPreferences in the app,
/// by memory in tests.
abstract class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class MemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> data = {};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async => data[key] = value;
}

class SyncOperation {
  final String id;
  final SyncOpType type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  SyncState state;
  int attempts;
  String? lastError;

  SyncOperation({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAt,
    this.state = SyncState.localOnly,
    this.attempts = 0,
    this.lastError,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'payload': payload,
        'createdAt': createdAt.toIso8601String(),
        'state': state.name,
        'attempts': attempts,
        'lastError': lastError,
      };

  factory SyncOperation.fromJson(Map<String, dynamic> json) => SyncOperation(
        id: json['id'] as String,
        type: SyncOpType.values.byName(json['type'] as String),
        payload: Map<String, dynamic>.from(json['payload'] as Map),
        createdAt: DateTime.parse(json['createdAt'] as String),
        state: SyncState.values.byName(json['state'] as String),
        attempts: json['attempts'] as int? ?? 0,
        lastError: json['lastError'] as String?,
      );
}

/// Thrown by an executor when the failure is connectivity-related: the
/// operation stays queued and the flush stops (we are still offline).
class TransientSyncException implements Exception {
  final String message;
  const TransientSyncException(this.message);

  @override
  String toString() => 'TransientSyncException: $message';
}

/// Thrown by an executor when the server rejected the operation because the
/// data conflicts with what the cloud holds. Cloud wins (R6.5): the operation
/// is parked as CONFLICT for the user to review.
class SyncConflictException implements Exception {
  final String message;
  const SyncConflictException(this.message);

  @override
  String toString() => 'SyncConflictException: $message';
}

class FlushResult {
  final int synced;
  final int failed;
  final int conflicts;
  final int remaining;
  final bool stoppedOffline;

  const FlushResult({
    required this.synced,
    required this.failed,
    required this.conflicts,
    required this.remaining,
    required this.stoppedOffline,
  });
}

/// Persistent FIFO queue of operations made while offline (spec R6.2, R6.3).
///
/// Guarantees: operations are executed in enqueue order; an operation leaves the
/// queue only after its executor succeeds (never lost, never run twice after
/// success); a transient failure preserves everything still queued.
class SyncQueue {
  static const storageKey = 'sync_queue_v1';
  static const maxAttempts = 5;

  final KeyValueStore _store;
  final List<SyncOperation> _ops = [];
  bool _loaded = false;
  bool _flushing = false;

  SyncQueue(this._store);

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final raw = await _store.read(storageKey);
    if (raw != null && raw.isNotEmpty) {
      final list = jsonDecode(raw) as List<dynamic>;
      _ops.addAll(
        list.map((e) => SyncOperation.fromJson(e as Map<String, dynamic>)),
      );
      // A crash mid-flush leaves SYNCING behind; those are safe to retry.
      for (final op in _ops) {
        if (op.state == SyncState.syncing) op.state = SyncState.localOnly;
      }
    }
    _loaded = true;
  }

  Future<void> _persist() => _store.write(
        storageKey,
        jsonEncode(_ops.map((o) => o.toJson()).toList()),
      );

  Future<List<SyncOperation>> all() async {
    await _ensureLoaded();
    return List.unmodifiable(_ops);
  }

  /// Operations still waiting to sync (LOCAL_ONLY).
  Future<List<SyncOperation>> pending() async {
    await _ensureLoaded();
    return _ops.where((o) => o.state == SyncState.localOnly).toList();
  }

  Future<SyncOperation> enqueue({
    required String id,
    required SyncOpType type,
    required Map<String, dynamic> payload,
    DateTime? now,
  }) async {
    await _ensureLoaded();
    final op = SyncOperation(
      id: id,
      type: type,
      payload: payload,
      createdAt: now ?? DateTime.now(),
    );
    _ops.add(op);
    await _persist();
    return op;
  }

  /// Drop a parked FAILED/CONFLICT operation (user chose to discard it).
  Future<void> discard(String id) async {
    await _ensureLoaded();
    _ops.removeWhere((o) => o.id == id);
    await _persist();
  }

  /// Run every LOCAL_ONLY operation through [execute], oldest first.
  Future<FlushResult> flush(
    Future<void> Function(SyncOperation op) execute,
  ) async {
    await _ensureLoaded();
    if (_flushing) {
      return FlushResult(
        synced: 0,
        failed: 0,
        conflicts: 0,
        remaining: _ops.where((o) => o.state == SyncState.localOnly).length,
        stoppedOffline: false,
      );
    }
    _flushing = true;
    var synced = 0, failed = 0, conflicts = 0;
    var stoppedOffline = false;
    try {
      for (final op in List.of(_ops)) {
        if (op.state != SyncState.localOnly) continue;
        op.state = SyncState.syncing;
        await _persist();
        try {
          await execute(op);
          _ops.remove(op);
          synced++;
        } on TransientSyncException catch (e) {
          op.state = SyncState.localOnly;
          op.lastError = e.message;
          stoppedOffline = true;
        } on SyncConflictException catch (e) {
          op.state = SyncState.conflict;
          op.lastError = e.message;
          conflicts++;
        } catch (e) {
          op.attempts++;
          op.lastError = e.toString();
          if (op.attempts >= maxAttempts) {
            op.state = SyncState.failed;
            failed++;
          } else {
            op.state = SyncState.localOnly;
          }
        }
        await _persist();
        if (stoppedOffline) break;
      }
    } finally {
      _flushing = false;
    }
    return FlushResult(
      synced: synced,
      failed: failed,
      conflicts: conflicts,
      remaining: _ops.where((o) => o.state == SyncState.localOnly).length,
      stoppedOffline: stoppedOffline,
    );
  }
}
