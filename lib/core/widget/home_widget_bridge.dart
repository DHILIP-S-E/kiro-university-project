import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:personal_memory_os/core/widget/widget_snapshot.dart';

/// Sends the widget's content to the platform. The Android side stores it and
/// redraws every placed widget; platforms without widgets use [NoWidgetBridge].
abstract class HomeWidgetBridge {
  Future<void> update(WidgetSnapshot snapshot);

  /// Ask the launcher to add the widget to the home screen (the user confirms in a
  /// system dialog). False when this phone or launcher does not support it.
  Future<bool> requestPin();
}

class ChannelHomeWidgetBridge implements HomeWidgetBridge {
  final MethodChannel _channel;

  ChannelHomeWidgetBridge({MethodChannel channel = const MethodChannel('pmos/widget')})
      : _channel = channel;

  @override
  Future<void> update(WidgetSnapshot snapshot) async {
    try {
      await _channel.invokeMethod<void>('update', jsonEncode(snapshot.toJson()));
    } on MissingPluginException {
      // Not Android (or a test): there is no widget to update.
    } on PlatformException {
      // A widget that fails to redraw must never break the app.
    }
  }

  @override
  Future<bool> requestPin() async {
    try {
      return await _channel.invokeMethod<bool>('pin') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}

class NoWidgetBridge implements HomeWidgetBridge {
  const NoWidgetBridge();

  @override
  Future<void> update(WidgetSnapshot snapshot) async {}

  @override
  Future<bool> requestPin() async => false;
}
