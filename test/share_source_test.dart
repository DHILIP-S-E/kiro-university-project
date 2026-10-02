import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_memory_os/core/services/share_source.dart';

const channel = MethodChannel('pmos/share');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('cleanSharedText trims and rejects blanks and non-strings', () {
    expect(cleanSharedText('  AWS Hackathon Oct 4  '), 'AWS Hackathon Oct 4');
    expect(cleanSharedText('   '), isNull);
    expect(cleanSharedText(null), isNull);
    expect(cleanSharedText(42), isNull);
  });

  test('cold start: initial text comes from the native side', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getInitialText');
      return '  Register by Oct 1\nhttps://example.com ';
    });
    expect(await ChannelShareSource().initialText(),
        'Register by Oct 1\nhttps://example.com');
  });

  test('cold start without a share returns null', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
    expect(await ChannelShareSource().initialText(), isNull);
  });

  test('no native side (not Android): nothing shared, no crash', () async {
    expect(await ChannelShareSource().initialText(), isNull);
  });

  test('shares while running arrive on the stream', () async {
    final source = ChannelShareSource();
    final received = <String>[];
    final sub = source.texts.listen(received.add);

    Future<void> nativePush(Object? text) =>
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
          'pmos/share',
          const StandardMethodCodec().encodeMethodCall(MethodCall('onShare', text)),
          (_) {},
        );

    await nativePush('Gemini Workshop Oct 12');
    await nativePush('   ');
    await nativePush(null);
    await nativePush('Second share');
    await Future<void>.delayed(Duration.zero);

    expect(received, ['Gemini Workshop Oct 12', 'Second share']);
    await sub.cancel();
  });

  test('NoShareSource shares nothing', () async {
    expect(await const NoShareSource().initialText(), isNull);
    expect(await const NoShareSource().texts.isEmpty, isTrue);
  });
}
