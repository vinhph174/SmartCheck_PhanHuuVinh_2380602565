import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:chamcong_phanhuuvinh_2380602565/services/attendance_position_provider.dart';

Position _position(double latitude) => Position(
  longitude: 106.7009,
  latitude: latitude,
  timestamp: DateTime.now(),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  test('mỗi lần xác nhận chấm công đều yêu cầu một vị trí GPS mới', () async {
    var calls = 0;
    final provider = AttendancePositionProvider(
      loader: () async => _position(10.0 + ++calls),
    );

    final first = await provider.getFreshPosition();
    final second = await provider.getFreshPosition();

    expect(calls, 2);
    expect(first.latitude, 11.0);
    expect(second.latitude, 12.0);
  });

  test('lỗi lấy GPS mới được chuyển tiếp, không trả lại vị trí cũ', () async {
    final provider = AttendancePositionProvider(
      loader: () async => throw Exception('GPS unavailable'),
    );

    await expectLater(provider.getFreshPosition(), throwsException);
  });
}
