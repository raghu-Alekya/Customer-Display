/// Abstraction for key-value storage (replaces Hive boxes).
/// All implementations must preserve identical behavior for offline orders flow.
abstract class BoxStorage {
  Future<dynamic> get(String key);
  Future<void> put(String key, dynamic value);
  Future<bool> containsKey(String key);
  Future<void> delete(String key);
  Future<Map<String, dynamic>> toMap();
  Future<List<String>> getKeys();
}
