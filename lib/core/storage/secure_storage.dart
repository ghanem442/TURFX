import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _kAccessToken = "access_token";
  static const _kRefreshToken = "refresh_token";
  static const _kUserData = "user_data";

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _kAccessToken, value: accessToken);
    await _storage.write(key: _kRefreshToken, value: refreshToken);
  }

  Future<String?> getAccessToken() => _storage.read(key: _kAccessToken);
  Future<String?> getRefreshToken() => _storage.read(key: _kRefreshToken);

  Future<void> saveUserData(String json) => _storage.write(key: _kUserData, value: json);
  Future<String?> getUserData() => _storage.read(key: _kUserData);
  Future<void> clearUserData() => _storage.delete(key: _kUserData);

  Future<void> clearTokens() async {
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kRefreshToken);
  }

  Future<void> clearAll() async {
    await clearTokens();
    await clearUserData();
  }
}