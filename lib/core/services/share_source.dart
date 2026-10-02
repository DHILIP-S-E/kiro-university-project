import 'dart:async';

import 'package:flutter/services.dart';

/// Text shared into the app from the system share sheet (a copied event page,
/// a link, an email). The app turns it into an event or a capture.
abstract class ShareSource {
  /// Text that launched the app (cold start via share), or null.
  Future<String?> initialText();

  /// Text shared while the app is already running.
  Stream<String> get texts;
}

/// Android share sheet via MainActivity's `pmos/share` channel (no plugin).
class ChannelShareSource implements ShareSource {
  final MethodChannel _channel;
  final StreamController<String> _live = StreamController<String>.broadcast();

  ChannelShareSource({MethodChannel channel = const MethodChannel('pmos/share')})
      : _channel = channel {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onShare') {
        final text = cleanSharedText(call.arguments);
        if (text != null) _live.add(text);
      }
      return null;
    });
  }

  @override
  Future<String?> initialText() async {
    try {
      return cleanSharedText(await _channel.invokeMethod<String>('getInitialText'));
    } on MissingPluginException {
      return null; // not on Android (or a test): nothing was shared
    }
  }

  @override
  Stream<String> get texts => _live.stream;
}

/// Pure: shared text trimmed, or null when it is not a non-blank string.
String? cleanSharedText(Object? raw) {
  if (raw is! String) return null;
  final text = raw.trim();
  return text.isEmpty ? null : text;
}

class NoShareSource implements ShareSource {
  const NoShareSource();

  @override
  Future<String?> initialText() async => null;

  @override
  Stream<String> get texts => const Stream.empty();
}
