import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_memory_os/core/widget/home_widget_bridge.dart';
import 'package:personal_memory_os/core/widget/widget_snapshot.dart';

const channel = MethodChannel('pmos/widget');

const snapshot = WidgetSnapshot(
  headline: '1 today',
  generatedAtMillis: 1000,
  lines: [WidgetLine(title: 'Workshop', when: '14:30', atMillis: 5000)],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('sends the snapshot as JSON on the update method', () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      received = call;
      return null;
    });
    await ChannelHomeWidgetBridge().update(snapshot);
    expect(received!.method, 'update');
    final json = jsonDecode(received!.arguments as String) as Map<String, dynamic>;
    expect(json['headline'], '1 today');
    expect((json['lines'] as List).single['title'], 'Workshop');
  });

  test('no native side (not Android) is silently fine', () async {
    await ChannelHomeWidgetBridge().update(snapshot); // must not throw
  });

  test('a native failure never breaks the app', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'boom');
    });
    await ChannelHomeWidgetBridge().update(snapshot); // must not throw
  });

  test('NoWidgetBridge does nothing', () async {
    await const NoWidgetBridge().update(snapshot);
    expect(await const NoWidgetBridge().requestPin(), isFalse);
  });

  test('pin request returns the native answer', () async {
    for (final answer in [true, false]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'pin');
        return answer;
      });
      expect(await ChannelHomeWidgetBridge().requestPin(), answer);
    }
  });

  test('pin request is false when unsupported or failing', () async {
    expect(await ChannelHomeWidgetBridge().requestPin(), isFalse); // no native side
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => throw PlatformException(code: 'x'));
    expect(await ChannelHomeWidgetBridge().requestPin(), isFalse);
  });
}
