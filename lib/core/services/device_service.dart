import 'package:personal_memory_os/core/services/api_client.dart';

/// Registers this device's push token with the backend so the cloud half of the
/// two-layer alarm (EventBridge Scheduler -> SNS) can reach it.
abstract class DeviceService {
  Future<void> registerPushToken(String token, {required String platform});
}

class ApiDeviceService implements DeviceService {
  final ApiClient _client;

  ApiDeviceService(this._client);

  @override
  Future<void> registerPushToken(String token, {required String platform}) async {
    await _client.post('/devices', {'token': token, 'platform': platform});
  }
}

class StubDeviceService implements DeviceService {
  @override
  Future<void> registerPushToken(String token, {required String platform}) async {}
}
