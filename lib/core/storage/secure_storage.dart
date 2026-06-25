import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  // Primary: EncryptedSharedPreferences (more secure)
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Fallback: regular keystore-based storage (for devices where encrypted prefs fail)
  static const _fallbackStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: false),
  );

  static const _kAccessToken = "access_token";
  static const _kRefreshToken = "refresh_token";
  static const _kUserData = "user_data";

  /// Read with fallback: tries encrypted storage first, then falls back
  Future<String?> _readSafe(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SecureStorage: encrypted read failed for $key, trying fallback. Error: $e');
      }
      try {
        return await _fallbackStorage.read(key: key);
      } catch (e2) {
        if (kDebugMode) {
          debugPrint('SecureStorage: fallback read also failed for $key. Error: $e2');
        }
        return null;
      }
    }
  }

  /// Write with fallback: writes to both storages so migration works
  Future<void> _writeSafe(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SecureStorage: encrypted write failed for $key, trying fallback. Error: $e');
      }
      try {
        await _fallbackStorage.write(key: key, value: value);
      } catch (e2) {
        if (kDebugMode) {
          debugPrint('SecureStorage: fallback write also failed for $key. Error: $e2');
        }
      }
    }
  }

  /// Delete from both storages
  Future<void> _deleteSafe(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } catch (_) {}
    try {
      await _fallbackStorage.delete(key: key);
    } catch (_) {}
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _writeSafe(_kAccessToken, accessToken);
    await _writeSafe(_kRefreshToken, refreshToken);
  }

  Future<String?> getAccessToken() => _readSafe(_kAccessToken);
  Future<String?> getRefreshToken() => _readSafe(_kRefreshToken);

  Future<void> saveUserData(String json) => _writeSafe(_kUserData, json);
  Future<String?> getUserData() => _readSafe(_kUserData);

  Future<void> clearUserData() => _deleteSafe(_kUserData);

  Future<void> clearTokens() async {
    await _deleteSafe(_kAccessToken);
    await _deleteSafe(_kRefreshToken);
  }

  Future<void> clearAll() async {
    await clearTokens();
    await clearUserData();
  }
}