/// Where the platform push token comes from (FCM on Android, APNs via FCM on iOS).
///
/// The app ships with [NoPushTokenSource]; adding Firebase means implementing
/// this interface with firebase_messaging and passing it in main.dart.
abstract class PushTokenSource {
  /// 'fcm' or 'apns' — matches the backend's DeviceRegistration.platform.
  String get platform;

  /// Current token, or null if push is unavailable / permission denied.
  Future<String?> getToken();

  /// Emits whenever the platform rotates the token.
  Stream<String> get onTokenRefresh;
}

class NoPushTokenSource implements PushTokenSource {
  @override
  String get platform => 'fcm';

  @override
  Future<String?> getToken() async => null;

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();
}
