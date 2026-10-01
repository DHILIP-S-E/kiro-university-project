import 'dart:convert';

import 'package:personal_memory_os/core/services/api_client.dart';

/// Data rights (spec R5.7, R5.8): export everything, delete everything.
abstract class AccountService {
  /// Pretty-printed JSON of all the user's data.
  Future<String> exportData();

  /// Permanently deletes all user data (S3 media, schedules, database rows).
  Future<void> deleteAllData();
}

class ApiAccountService implements AccountService {
  final ApiClient _client;

  ApiAccountService(this._client);

  @override
  Future<String> exportData() async {
    final data = await _client.get('/account/export');
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  @override
  Future<void> deleteAllData() async {
    await _client.delete('/account');
  }
}

class StubAccountService implements AccountService {
  @override
  Future<String> exportData() async =>
      const JsonEncoder.withIndent('  ').convert({'demo': true});

  @override
  Future<void> deleteAllData() async {}
}
