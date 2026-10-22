import 'dart:convert';

import 'package:chamcong_phanhuuvinh_2380602565/screens/admin/admin_departments_screen.dart';
import 'package:chamcong_phanhuuvinh_2380602565/services/api_service.dart';
import 'package:chamcong_phanhuuvinh_2380602565/services/session_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _EmptyTokenStorage implements TokenStorage {
  @override
  Future<void> delete(String key) async {}

  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SessionStorage.useTokenStorageForTesting(_EmptyTokenStorage());
  });

  tearDown(() {
    ApiService.restoreDefaultClient();
    SessionStorage.restorePlatformTokenStorage();
  });

  testWidgets('lỗi API giữ hộp thoại CRUD và dữ liệu đang nhập', (
    tester,
  ) async {
    ApiService.useClientForTesting(
      MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode(<Object>[]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({'message': 'Tên phòng ban đã tồn tại.'}),
          409,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await tester.pumpWidget(const MaterialApp(home: AdminDepartmentsScreen()));
    // Do not use pumpAndSettle while the screen owns an animated loading
    // indicator. Two frames are enough for the mocked GET future to finish.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Phòng Kỹ thuật');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Lưu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Phòng Kỹ thuật'), findsOneWidget);
    expect(find.text('Tên phòng ban đã tồn tại.'), findsOneWidget);
  });
}
