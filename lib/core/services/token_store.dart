import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where login tokens live between launches.
abstract class TokenStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> clear();
}

/// Keychain / Keystore backed storage for the real app.
class SecureTokenStore implements TokenStore {
  final _storage = const FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> clear() => _storage.deleteAll();
}

/// For tests.
class MemoryTokenStore implements TokenStore {
  final Map<String, String> data = {};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async => data[key] = value;

  @override
  Future<void> clear() async => data.clear();
}
