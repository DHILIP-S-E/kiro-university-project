import 'dart:async';

import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Text shared into the app from the system share sheet (a copied event page,
/// a link, an email). The app turns it into an event or a capture.
abstract class ShareSource {
  /// Text that launched the app (cold start via share), or null.
  Future<String?> initialText();

  /// Text shared while the app is already running.
  Stream<String> get texts;
}

/// Pure: the text carried by a batch of shared items. Only text and URLs count;
/// images and files are ignored here. Blank items are dropped.
String? sharedTextFrom(List<SharedMediaFile> items) {
  final parts = items
      .where((i) => i.type == SharedMediaType.text || i.type == SharedMediaType.url)
      .map((i) => i.path.trim())
      .where((t) => t.isNotEmpty)
      .toList();
  return parts.isEmpty ? null : parts.join('\n');
}

class PluginShareSource implements ShareSource {
  @override
  Future<String?> initialText() async {
    final items = await ReceiveSharingIntent.instance.getInitialMedia();
    // Consume it so the same share is not delivered again on the next launch.
    await ReceiveSharingIntent.instance.reset();
    return sharedTextFrom(items);
  }

  @override
  Stream<String> get texts => ReceiveSharingIntent.instance
      .getMediaStream()
      .map(sharedTextFrom)
      .where((t) => t != null)
      .cast<String>();
}

class NoShareSource implements ShareSource {
  const NoShareSource();

  @override
  Future<String?> initialText() async => null;

  @override
  Stream<String> get texts => const Stream.empty();
}
