import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static const _baseUrlKey = 'api_base_url';

  // Default URL for Android Emulator is 10.0.2.2:5262
  // For Windows desktop it is localhost:5262
  static String get defaultBaseUrl {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:5262';
    }
    return 'http://localhost:5262';
  }

  static String baseUrl = defaultBaseUrl;

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_baseUrlKey);
    if (saved != null) {
      final normalized = normalizeBaseUrl(saved);
      if (normalized != null) {
        baseUrl = normalized;
        return;
      }
      await prefs.remove(_baseUrlKey);
    }
    baseUrl = defaultBaseUrl;
  }

  static String? normalizeBaseUrl(String input) {
    final value = input.trim();
    final uri = Uri.tryParse(value);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }

    final normalizedPath = uri.path == '/' ? '' : uri.path;
    if (normalizedPath.isNotEmpty) return null;
    return uri.replace(path: '').toString().replaceFirst(RegExp(r'/$'), '');
  }

  static Future<bool> saveBaseUrl(String input) async {
    final normalized = normalizeBaseUrl(input);
    if (normalized == null) return false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, normalized);
    baseUrl = normalized;
    return true;
  }

  // Auth endpoints
  static String get login => '$baseUrl/api/auth/login';
  static String get verifyLogin => '$baseUrl/api/auth/verify-login';
  static String get register => '$baseUrl/api/auth/register';
  static String get verifyEmail => '$baseUrl/api/auth/verify-email';
  static String get resendVerificationOtp =>
      '$baseUrl/api/auth/resend-verification-otp';

  // Admin endpoints
  static String get adminDashboard => '$baseUrl/api/admin/dashboard';
  static String get adminEmployees => '$baseUrl/api/admin/employees';
  static String get adminPendingEmployees =>
      '$baseUrl/api/admin/employees/pending';
  static String adminEmployee(int id) => '$baseUrl/api/admin/employees/$id';
  static String activateEmployee(int id) =>
      '$baseUrl/api/admin/employees/$id/activate';
  static String deactivateEmployee(int id) =>
      '$baseUrl/api/admin/employees/$id/deactivate';

  // CRUD endpoints
  static String get departments => '$baseUrl/api/admin/crud/departments';
  static String department(int id) => '$baseUrl/api/admin/crud/departments/$id';

  static String get shifts => '$baseUrl/api/admin/crud/shifts';
  static String shift(int id) => '$baseUrl/api/admin/crud/shifts/$id';

  static String get locations => '$baseUrl/api/admin/crud/locations';
  static String location(int id) => '$baseUrl/api/admin/crud/locations/$id';

  // Shift assignments
  static String get shiftAssignments => '$baseUrl/api/shift-assignments';
  static String shiftAssignment(int id) => '$baseUrl/api/shift-assignments/$id';
  static String get myAssignments => '$baseUrl/api/shift-assignments/my';

  // Attendance
  static String get qrSession => '$baseUrl/api/attendance/qr-session';
  static String get checkIn => '$baseUrl/api/attendance/check-in';
  static String get checkOut => '$baseUrl/api/attendance/check-out';
  static String get myAttendance => '$baseUrl/api/attendance/my';
  static String get allAttendance => '$baseUrl/api/attendance/all';

  // Location shares
  static String get shareLocation => '$baseUrl/api/location-shares';
  static String get latestLocations => '$baseUrl/api/location-shares/latest';
  static String get myLocationShares => '$baseUrl/api/location-shares/my';

  // Appeals
  static String get appeals => '$baseUrl/api/appeals';
  static String get myAppeals => '$baseUrl/api/appeals/my';
  static String get appealSuggestions => '$baseUrl/api/appeals/suggestions';
  static String reviewAppeal(int id) => '$baseUrl/api/appeals/$id/review';
}
