import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_memory_os/core/services/device_service.dart';
import 'package:personal_memory_os/core/services/push_registration.dart';
import 'package:personal_memory_os/core/services/push_token_source.dart';
import 'package:personal_memory_os/core/sync/sync_queue.dart';

class FakeDevice implements DeviceService {
  final calls = <String>[];
  bool fail = false;

  @override
  Future<void> registerPushToken(String token, {required String platform}) async {
    if (fail) throw StateError('offline');
    calls.add('$platform:$token');
  }
}

class FakeSource implements PushTokenSource {
  String? token;
  final refresh = StreamController<String>.broadcast();

  FakeSource(this.token);

  @override
  String get platform => 'fcm';

  @override
  Future<String?> getToken() async => token;

  @override
  Stream<String> get onTokenRefresh => refresh.stream;
}

void main() {
  test('registers a token once, not on every sign-in', () async {
    final device = FakeDevice();
    final reg = PushRegistration(device, FakeSource('t1'), MemoryKeyValueStore());
    expect(await reg.register(), isTrue);
    expect(await reg.register(), isFalse);
    expect(device.calls, ['fcm:t1']);
  });

  test('no token (push unavailable) is a quiet no-op', () async {
    final device = FakeDevice();
    final reg = PushRegistration(device, NoPushTokenSource(), MemoryKeyValueStore());
    expect(await reg.register(), isFalse);
    expect(device.calls, isEmpty);
  });

  test('a failed registration is retried next time', () async {
    final device = FakeDevice()..fail = true;
    final reg = PushRegistration(device, FakeSource('t1'), MemoryKeyValueStore());
    expect(await reg.register(), isFalse);
    device.fail = false;
    expect(await reg.register(), isTrue);
    expect(device.calls, ['fcm:t1']);
  });

  test('a rotated token is registered automatically', () async {
    final device = FakeDevice();
    final source = FakeSource('t1');
    final reg = PushRegistration(device, source, MemoryKeyValueStore());
    await reg.register();
    reg.listenForRefresh();
    source.refresh.add('t2');
    await Future<void>.delayed(Duration.zero);
    expect(device.calls, ['fcm:t1', 'fcm:t2']);
    await reg.dispose();
  });
}
