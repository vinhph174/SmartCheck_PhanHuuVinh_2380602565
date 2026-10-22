import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/models.dart';
import 'api_service.dart';
import 'session_storage.dart';

class AuthService {
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = await SessionStorage.readToken();
    if (token == null || token.isEmpty) return false;

    final storedExpiry = prefs.getInt('token_expires_at');
    final expiresAt = storedExpiry ?? _readJwtExpiry(token);
    if (expiresAt == null ||
        DateTime.now().toUtc().millisecondsSinceEpoch >= expiresAt) {
      await _clearSession(prefs);
      return false;
    }

    return true;
  }

  static Future<String> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_role') ?? 'Employee';
  }

  static Future<String> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_name') ?? '';
  }

  static Future<String> getFullName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('full_name') ?? '';
  }

  static Future<void> saveUserSession(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    final expiresAt = DateTime.now()
        .toUtc()
        .add(Duration(seconds: user.expiresInSeconds))
        .millisecondsSinceEpoch;
    await SessionStorage.writeToken(user.accessToken);
    await prefs.setString('user_role', user.role);
    await prefs.setString('user_name', user.userName);
    await prefs.setString('full_name', user.fullName);
    await prefs.setInt('token_expires_at', expiresAt);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await _clearSession(prefs);
  }

  static Future<void> _clearSession(SharedPreferences prefs) async {
    await SessionStorage.clearSession(preferences: prefs);
  }

  static int? _readJwtExpiry(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final exp = payload is Map<String, dynamic> ? payload['exp'] : null;
      return exp is num ? exp.toInt() * 1000 : null;
    } catch (_) {
      return null;
    }
  }

  // Step 1: Login with username & password -> returns loginTicket
  static Future<ApiResponse> login(String userName, String password) async {
    return await ApiService.post(
      ApiConfig.login,
      body: {'userName': userName.trim(), 'password': password},
      withAuth: false,
    );
  }

  // Step 2: Verify login with loginTicket & OTP code -> returns JWT accessToken
  static Future<ApiResponse> verifyLogin(
    String userName,
    String loginTicket,
    String code,
  ) async {
    final res = await ApiService.post(
      ApiConfig.verifyLogin,
      body: {
        'userName': userName.trim(),
        'loginTicket': loginTicket,
        'code': code.trim(),
      },
      withAuth: false,
    );

    if (res.isSuccess && res.data is Map<String, dynamic>) {
      final user = UserModel.fromJson(res.data);
      await saveUserSession(user);
    }
    return res;
  }

  // Register new employee account
  static Future<ApiResponse> register({
    required String fullName,
    required String userName,
    required String email,
    required String password,
  }) async {
    return await ApiService.post(
      ApiConfig.register,
      body: {
        'fullName': fullName.trim(),
        'userName': userName.trim(),
        'email': email.trim(),
        'password': password,
      },
      withAuth: false,
    );
  }

  // Verify email with OTP code
  static Future<ApiResponse> verifyEmail(String email, String code) async {
    return await ApiService.post(
      ApiConfig.verifyEmail,
      body: {'email': email.trim(), 'code': code.trim()},
      withAuth: false,
    );
  }

  // Resend verification OTP code
  static Future<ApiResponse> resendVerificationOtp(String email) async {
    return await ApiService.post(
      ApiConfig.resendVerificationOtp,
      body: {'email': email.trim()},
      withAuth: false,
    );
  }
}
