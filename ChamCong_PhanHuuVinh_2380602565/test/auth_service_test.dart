import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chamcong_phanhuuvinh_2380602565/models/models.dart';
import 'package:chamcong_phanhuuvinh_2380602565/services/auth_service.dart';
import 'package:chamcong_phanhuuvinh_2380602565/services/session_storage.dart';

class _MemoryTokenStorage implements TokenStorage {
  final Map<String, String> values = {};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

String _jwtWithExpiry(DateTime expiry) {
  final payload = base64Url
      .encode(
        utf8.encode(
          jsonEncode({'exp': expiry.toUtc().millisecondsSinceEpoch ~/ 1000}),
        ),
      )
      .replaceAll('=', '');
  return 'header.$payload.signature';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MemoryTokenStorage secureStorage;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    secureStorage = _MemoryTokenStorage();
    SessionStorage.useTokenStorageForTesting(secureStorage);
  });

  tearDown(SessionStorage.restorePlatformTokenStorage);

  test('isLoggedIn accepts a non-expired JWT', () async {
    SharedPreferences.setMockInitialValues({
      'access_token': _jwtWithExpiry(
        DateTime.now().toUtc().add(const Duration(minutes: 5)),
      ),
      'user_role': 'Employee',
    });

    expect(await AuthService.isLoggedIn(), isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('access_token'), isNull);
    expect(secureStorage.values['access_token'], isNotNull);
  });

  test('isLoggedIn rejects an expired JWT and clears the session', () async {
    SharedPreferences.setMockInitialValues({
      'access_token': _jwtWithExpiry(
        DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
      ),
      'user_role': 'Admin',
      'user_name': 'stale-user',
    });

    expect(await AuthService.isLoggedIn(), isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('access_token'), isNull);
    expect(prefs.getString('user_role'), isNull);
    expect(prefs.getString('user_name'), isNull);
    expect(secureStorage.values['access_token'], isNull);
  });

  test('saveUserSession stores JWT only in secure storage', () async {
    final token = _jwtWithExpiry(
      DateTime.now().toUtc().add(const Duration(minutes: 5)),
    );

    await AuthService.saveUserSession(
      UserModel(
        userName: 'employee',
        fullName: 'Nhân viên',
        role: 'Employee',
        accessToken: token,
        expiresInSeconds: 300,
      ),
    );

    final prefs = await SharedPreferences.getInstance();
    expect(secureStorage.values['access_token'], token);
    expect(prefs.getString('access_token'), isNull);
    expect(prefs.getString('user_role'), 'Employee');
  });

  test('logout clears secure token and session metadata', () async {
    secureStorage.values['access_token'] = _jwtWithExpiry(
      DateTime.now().toUtc().add(const Duration(minutes: 5)),
    );
    SharedPreferences.setMockInitialValues({
      'user_role': 'Employee',
      'user_name': 'employee',
      'full_name': 'Nhân viên',
      'token_expires_at': DateTime.now().millisecondsSinceEpoch,
    });

    await AuthService.logout();

    final prefs = await SharedPreferences.getInstance();
    expect(secureStorage.values['access_token'], isNull);
    expect(prefs.getString('user_role'), isNull);
    expect(prefs.getString('user_name'), isNull);
    expect(prefs.getString('full_name'), isNull);
    expect(prefs.getInt('token_expires_at'), isNull);
  });
}
