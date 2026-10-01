import 'package:shared_preferences/shared_preferences.dart';
import 'package:personal_memory_os/core/sync/sync_queue.dart';

/// [KeyValueStore] backed by SharedPreferences: survives app restarts, so
/// queued offline operations and cached lists are never lost.
class PrefsKeyValueStore implements KeyValueStore {
  final SharedPreferences _prefs;

  PrefsKeyValueStore(this._prefs);

  @override
  Future<String?> read(String key) async => _prefs.getString(key);

  @override
  Future<void> write(String key, String value) => _prefs.setString(key, value);
}
