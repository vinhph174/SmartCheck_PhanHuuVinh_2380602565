import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'session_storage.dart';

class ApiResponse {
  final bool isSuccess;
  final int statusCode;
  final dynamic data;
  final String? message;

  ApiResponse({
    required this.isSuccess,
    required this.statusCode,
    this.data,
    this.message,
  });
}

class ApiService {
  static http.Client _client = http.Client();

  @visibleForTesting
  static void useClientForTesting(http.Client client) {
    _client.close();
    _client = client;
  }

  @visibleForTesting
  static void restoreDefaultClient() {
    _client.close();
    _client = http.Client();
  }

  static Future<String?> getToken() async {
    return SessionStorage.readToken();
  }

  static Future<Map<String, String>> _getHeaders({bool withAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (withAuth) {
      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  static String _formatNetworkError(dynamic e) {
    return 'Không thể kết nối máy chủ. Vui lòng kiểm tra kết nối mạng và thử lại.';
  }

  static Future<ApiResponse> get(String url, {bool withAuth = true}) async {
    try {
      final headers = await _getHeaders(withAuth: withAuth);
      final response = await _client
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 15));
      return await _handleResponse(response, withAuth: withAuth);
    } catch (e) {
      return ApiResponse(
        isSuccess: false,
        statusCode: 0,
        message: _formatNetworkError(e),
      );
    }
  }

  static Future<ApiResponse> post(
    String url, {
    dynamic body,
    bool withAuth = true,
  }) async {
    try {
      final headers = await _getHeaders(withAuth: withAuth);
      final response = await _client
          .post(
            Uri.parse(url),
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 15));
      return await _handleResponse(response, withAuth: withAuth);
    } catch (e) {
      return ApiResponse(
        isSuccess: false,
        statusCode: 0,
        message: _formatNetworkError(e),
      );
    }
  }

  static Future<ApiResponse> put(
    String url, {
    dynamic body,
    bool withAuth = true,
  }) async {
    try {
      final headers = await _getHeaders(withAuth: withAuth);
      final response = await _client
          .put(
            Uri.parse(url),
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 15));
      return await _handleResponse(response, withAuth: withAuth);
    } catch (e) {
      return ApiResponse(
        isSuccess: false,
        statusCode: 0,
        message: _formatNetworkError(e),
      );
    }
  }

  static Future<ApiResponse> delete(String url, {bool withAuth = true}) async {
    try {
      final headers = await _getHeaders(withAuth: withAuth);
      final response = await _client
          .delete(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 15));
      return await _handleResponse(response, withAuth: withAuth);
    } catch (e) {
      return ApiResponse(
        isSuccess: false,
        statusCode: 0,
        message: _formatNetworkError(e),
      );
    }
  }

  @visibleForTesting
  static ApiResponse processResponse(http.Response response) {
    dynamic data;
    String? message;

    if (response.bodyBytes.isNotEmpty) {
      final decodedBody = utf8.decode(response.bodyBytes);
      try {
        data = jsonDecode(decodedBody);
        if (data is Map<String, dynamic>) {
          final rawMessage = data['message'];
          if (rawMessage is String && rawMessage.isNotEmpty) {
            message = rawMessage;
          } else {
            message = _validationMessage(data['errors']);
          }
        } else if (data is String && data.trim().isNotEmpty) {
          // Một số endpoint cũ trả lỗi JSON dạng chuỗi. Giữ lại thông báo
          // cụ thể thay vì thay bằng thông báo HTTP chung.
          message = data.trim();
        }
      } catch (_) {
        data = decodedBody;
      }
    }

    final isSuccess = response.statusCode >= 200 && response.statusCode < 300;
    if (!isSuccess && message == null) {
      if (response.statusCode == 400) {
        message = 'Dữ liệu gửi lên không hợp lệ.';
      } else if (response.statusCode == 401) {
        message = 'Phiên làm việc đã hết hạn hoặc không có quyền truy cập.';
      } else if (response.statusCode == 403) {
        message = 'Bạn không có quyền thực hiện thao tác này.';
      } else if (response.statusCode == 404) {
        message = 'Không tìm thấy dữ liệu yêu cầu.';
      } else if (response.statusCode == 409) {
        message = 'Dữ liệu bị trùng lặp hoặc xung đột.';
      } else if (response.statusCode == 429) {
        message = 'Bạn thao tác quá nhiều lần. Vui lòng chờ rồi thử lại.';
      } else if (response.statusCode == 503) {
        message = 'Dịch vụ tạm thời chưa sẵn sàng. Vui lòng thử lại sau.';
      } else if (response.statusCode >= 500) {
        message = 'Máy chủ đang bận hoặc gặp lỗi nội bộ.';
      } else {
        message = 'Thao tác không thành công (${response.statusCode}).';
      }
    }

    return ApiResponse(
      isSuccess: isSuccess,
      statusCode: response.statusCode,
      data: data,
      message: message,
    );
  }

  static String? _validationMessage(dynamic errors) {
    if (errors is List || errors is Map) {
      return 'Dữ liệu gửi lên không hợp lệ. Vui lòng kiểm tra lại các trường.';
    }
    return null;
  }

  static Future<ApiResponse> _handleResponse(
    http.Response response, {
    required bool withAuth,
  }) async {
    final result = processResponse(response);
    if (withAuth && response.statusCode == 401) {
      await SessionStorage.clearSession();
    }
    return result;
  }
}
