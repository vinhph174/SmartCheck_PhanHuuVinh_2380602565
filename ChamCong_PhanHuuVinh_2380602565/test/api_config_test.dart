import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chamcong_phanhuuvinh_2380602565/config/api_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiConfig.baseUrl = ApiConfig.defaultBaseUrl;
  });

  test('lưu và khôi phục địa chỉ máy chủ hợp lệ', () async {
    expect(await ApiConfig.saveBaseUrl(' http://192.168.1.20:5262/ '), isTrue);
    ApiConfig.baseUrl = ApiConfig.defaultBaseUrl;

    await ApiConfig.initialize();

    expect(ApiConfig.baseUrl, 'http://192.168.1.20:5262');
  });

  test('từ chối URL có thông tin xác thực, query hoặc giao thức sai', () {
    expect(ApiConfig.normalizeBaseUrl('ftp://192.168.1.20:5262'), isNull);
    expect(ApiConfig.normalizeBaseUrl('http://user:pass@host:5262'), isNull);
    expect(ApiConfig.normalizeBaseUrl('http://host:5262?token=secret'), isNull);
    expect(ApiConfig.normalizeBaseUrl('http://host:5262/api'), isNull);
  });

  test('cấu hình đã lưu không hợp lệ bị loại bỏ', () async {
    SharedPreferences.setMockInitialValues({'api_base_url': 'not-a-url'});

    await ApiConfig.initialize();

    expect(ApiConfig.baseUrl, ApiConfig.defaultBaseUrl);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('api_base_url'), isNull);
  });
}
