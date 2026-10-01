import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_memory_os/core/sync/sync_queue.dart';

/// Randomised property tests for the offline sync queue (spec R6.2-R6.5).
/// Each property runs over many seeded random scenarios.
void main() {
  const scenarios = 200;

  Future<SyncQueue> seeded(Random rnd, KeyValueStore store, int n) async {
    final q = SyncQueue(store);
    for (var i = 0; i < n; i++) {
      await q.enqueue(
        id: 'op$i',
        type: SyncOpType.values[rnd.nextInt(SyncOpType.values.length)],
        payload: {'n': i, 'text': 'x' * rnd.nextInt(20)},
        now: DateTime.utc(2026, 1, 1).add(Duration(seconds: i)),
      );
    }
    return q;
  }

  test('all ops succeed: executed exactly once, in enqueue order, queue empties',
      () async {
    for (var seed = 0; seed < scenarios; seed++) {
      final rnd = Random(seed);
      final n = rnd.nextInt(15);
      final q = await seeded(rnd, MemoryKeyValueStore(), n);
      final ran = <String>[];
      final r = await q.flush((op) async => ran.add(op.id));
      expect(ran, List.generate(n, (i) => 'op$i'), reason: 'seed $seed');
      expect(r.synced, n);
      expect((await q.all()), isEmpty);
    }
  });

  test('transient failure preserves every unsynced op and stops the flush',
      () async {
    for (var seed = 0; seed < scenarios; seed++) {
      final rnd = Random(seed);
      final n = 1 + rnd.nextInt(15);
      final failAt = rnd.nextInt(n);
      final q = await seeded(rnd, MemoryKeyValueStore(), n);
      final ran = <String>[];
      final r = await q.flush((op) async {
        if (op.payload['n'] == failAt) throw const TransientSyncException('offline');
        ran.add(op.id);
      });
      expect(r.stoppedOffline, isTrue);
      expect(ran.length, failAt, reason: 'ops before the failure ran');
      final left = (await q.pending()).map((o) => o.id).toList();
      expect(left, List.generate(n - failAt, (i) => 'op${failAt + i}'),
          reason: 'seed $seed: nothing lost, order kept');
    }
  });

  test('random outcomes: executed ∪ remaining == enqueued, no duplicates',
      () async {
    for (var seed = 0; seed < scenarios; seed++) {
      final rnd = Random(seed);
      final n = rnd.nextInt(20);
      final q = await seeded(rnd, MemoryKeyValueStore(), n);
      final succeeded = <String>[];
      for (var round = 0; round < 3; round++) {
        await q.flush((op) async {
          switch (rnd.nextInt(4)) {
            case 0:
              throw const TransientSyncException('offline');
            case 1:
              throw StateError('server rejected');
            case 2:
              throw const SyncConflictException('cloud wins');
            default:
              succeeded.add(op.id);
          }
        });
      }
      final remaining = (await q.all()).map((o) => o.id).toList();
      expect(succeeded.toSet().length, succeeded.length, reason: 'no double-run');
      expect({...succeeded, ...remaining}.length, n,
          reason: 'seed $seed: no op lost');
      expect(succeeded.toSet().intersection(remaining.toSet()), isEmpty);
    }
  });

  test('persistence round-trips: a new queue over the same store sees the ops',
      () async {
    for (var seed = 0; seed < scenarios; seed++) {
      final rnd = Random(seed);
      final store = MemoryKeyValueStore();
      final n = rnd.nextInt(10);
      await seeded(rnd, store, n);
      final reloaded = SyncQueue(store);
      expect((await reloaded.pending()).length, n);
      final ran = <String>[];
      await reloaded.flush((op) async => ran.add(op.id));
      expect(ran.length, n);
    }
  });

  test('crash mid-flush: SYNCING ops are retried after reload', () async {
    final store = MemoryKeyValueStore();
    final q = SyncQueue(store);
    await q.enqueue(id: 'a', type: SyncOpType.createNote, payload: {'text': 'hi'});
    // Simulate a crash: the executor never returns before the process dies.
    final hang = Completer<void>();
    unawaited(q.flush((op) => hang.future));
    await Future.delayed(const Duration(milliseconds: 10));
    expect((await q.all()).single.state, SyncState.syncing);
    final reloaded = SyncQueue(store);
    final ran = <String>[];
    await reloaded.flush((op) async => ran.add(op.id));
    expect(ran, ['a']);
  });

  test('permanent errors park the op as FAILED after maxAttempts', () async {
    final q = SyncQueue(MemoryKeyValueStore());
    await q.enqueue(id: 'bad', type: SyncOpType.createLink, payload: {});
    await q.enqueue(id: 'good', type: SyncOpType.createLink, payload: {});
    final ran = <String>[];
    for (var i = 0; i < SyncQueue.maxAttempts; i++) {
      await q.flush((op) async {
        if (op.id == 'bad') throw StateError('422');
        ran.add(op.id);
      });
    }
    final all = await q.all();
    expect(all.single.id, 'bad');
    expect(all.single.state, SyncState.failed);
    expect(ran, ['good'], reason: 'a bad op never blocks later ones');
  });

  test('conflicts are parked, not retried', () async {
    final q = SyncQueue(MemoryKeyValueStore());
    await q.enqueue(id: 'c', type: SyncOpType.createReminder, payload: {});
    var calls = 0;
    Future<void> exec(SyncOperation op) async {
      calls++;
      throw const SyncConflictException('exists');
    }

    await q.flush(exec);
    await q.flush(exec);
    expect(calls, 1);
    expect((await q.all()).single.state, SyncState.conflict);
    await q.discard('c');
    expect(await q.all(), isEmpty);
  });
}
