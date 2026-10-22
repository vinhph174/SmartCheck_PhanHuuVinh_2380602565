import 'dart:convert';

import 'package:chamcong_phanhuuvinh_2380602565/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('giữ thông báo lỗi tiếng Việt khi backend trả JSON string', () {
    final response = http.Response(
      jsonEncode('Tên phòng ban không được để trống.'),
      400,
      headers: {'content-type': 'application/json'},
    );

    final result = ApiService.processResponse(response);

    expect(result.isSuccess, isFalse);
    expect(result.message, 'Tên phòng ban không được để trống.');
  });

  test('ưu tiên trường message của lỗi 404 và 409', () {
    for (final status in [404, 409]) {
      final response = http.Response(
        jsonEncode({'message': 'Thông báo nghiệp vụ cụ thể.'}),
        status,
        headers: {'content-type': 'application/json'},
      );

      expect(
        ApiService.processResponse(response).message,
        'Thông báo nghiệp vụ cụ thể.',
      );
    }
  });

  test('chuẩn hóa lỗi 403, 429 và 503 không có nội dung', () {
    expect(
      ApiService.processResponse(http.Response('', 403)).message,
      contains('không có quyền'),
    );
    expect(
      ApiService.processResponse(http.Response('', 429)).message,
      contains('quá nhiều'),
    );
    expect(
      ApiService.processResponse(http.Response('', 503)).message,
      contains('tạm thời'),
    );
  });
}
