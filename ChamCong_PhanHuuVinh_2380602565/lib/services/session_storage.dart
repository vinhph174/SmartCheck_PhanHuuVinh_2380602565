import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class TokenStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class PlatformTokenStorage implements TokenStorage {
  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class SessionStorage {
  static const tokenKey = 'access_token';
  static TokenStorage _tokenStorage = PlatformTokenStorage();

  static Future<String?> readToken() async {
    final prefs = await SharedPreferences.getInstance();
    final secureToken = await _tokenStorage.read(tokenKey);
    if (secureToken != null && secureToken.isNotEmpty) {
      await prefs.remove(tokenKey);
      return secureToken;
    }

    final legacyToken = prefs.getString(tokenKey);
    if (legacyToken == null || legacyToken.isEmpty) return null;

    // Migration an toàn: chỉ xóa bản cũ sau khi ghi và đọc kiểm chứng thành công.
    try {
      await _tokenStorage.write(tokenKey, legacyToken);
      final migratedToken = await _tokenStorage.read(tokenKey);
      if (migratedToken == legacyToken) {
        await prefs.remove(tokenKey);
        return migratedToken;
      }
    } catch (_) {
      // Giữ bản cũ để không làm mất phiên nếu Keystore tạm thời lỗi.
    }
    return legacyToken;
  }

  static Future<void> writeToken(String token) async {
    await _tokenStorage.write(tokenKey, token);
    final stored = await _tokenStorage.read(tokenKey);
    if (stored != token) {
      throw StateError('Không thể lưu phiên đăng nhập an toàn.');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenKey);
  }

  static Future<void> clearSession({SharedPreferences? preferences}) async {
    await _tokenStorage.delete(tokenKey);
    final prefs = preferences ?? await SharedPreferences.getInstance();
    await prefs.remove(tokenKey);
    await prefs.remove('user_role');
    await prefs.remove('user_name');
    await prefs.remove('full_name');
    await prefs.remove('token_expires_at');
  }

  @visibleForTesting
  static void useTokenStorageForTesting(TokenStorage storage) {
    _tokenStorage = storage;
  }

  @visibleForTesting
  static void restorePlatformTokenStorage() {
    _tokenStorage = PlatformTokenStorage();
  }
}
