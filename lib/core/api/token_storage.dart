import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _kDeviceToken = 'pch_device_token';
  static const _kAccessToken = 'pch_access_token';
  static const _kRefreshToken = 'pch_refresh_token';
  static const _kOfflinePinHash = 'pch_offline_pin_hash';
  static const _kLastAuthenticatedAt = 'pch_last_authenticated_at';
  static const _kDeviceActivated = 'pch_device_activated';

  Future<void> saveDeviceToken(String token) =>
      _secureStorage.write(key: _kDeviceToken, value: token);

  Future<String?> getDeviceToken() => _secureStorage.read(key: _kDeviceToken);

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _secureStorage.write(key: _kAccessToken, value: accessToken);
    await _secureStorage.write(key: _kRefreshToken, value: refreshToken);
  }

  Future<String?> getAccessToken() => _secureStorage.read(key: _kAccessToken);

  Future<String?> getRefreshToken() => _secureStorage.read(key: _kRefreshToken);

  Future<void> saveOfflinePinHash(String hash) =>
      _secureStorage.write(key: _kOfflinePinHash, value: hash);

  Future<String?> getOfflinePinHash() =>
      _secureStorage.read(key: _kOfflinePinHash);

  Future<void> saveLastAuthenticatedAt(DateTime time) => _secureStorage.write(
        key: _kLastAuthenticatedAt,
        value: time.toIso8601String(),
      );

  Future<DateTime?> getLastAuthenticatedAt() async {
    final value = await _secureStorage.read(key: _kLastAuthenticatedAt);
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  Future<void> setDeviceActivated(bool activated) => _secureStorage.write(
        key: _kDeviceActivated,
        value: activated.toString(),
      );

  Future<bool> isDeviceActivated() async {
    final value = await _secureStorage.read(key: _kDeviceActivated);
    return value == 'true';
  }

  Future<void> clearSessionTokens() async {
    await _secureStorage.delete(key: _kAccessToken);
    await _secureStorage.delete(key: _kRefreshToken);
  }

  Future<void> clearAll() async {
    await _secureStorage.deleteAll();
  }
}
