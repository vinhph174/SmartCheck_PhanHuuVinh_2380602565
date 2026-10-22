import 'package:flutter_test/flutter_test.dart';
import 'package:chamcong_phanhuuvinh_2380602565/services/sensor_service.dart';

void main() {
  group('SensorService - Tính toán độ lớn vector gia tốc (Magnitude)', () {
    test('calculateMagnitude tại gốc tọa độ (0, 0, 0) trả về 0.0', () {
      expect(SensorService.calculateMagnitude(0, 0, 0), equals(0.0));
    });

    test(
      'calculateMagnitude khi thiết bị đặt nằm yên trên bàn (0, 0, 9.80665)',
      () {
        final mag = SensorService.calculateMagnitude(0, 0, 9.80665);
        expect(mag, closeTo(9.80665, 0.0001));
      },
    );

    test(
      'calculateMagnitude theo định lý Pytago 3 chiều (3, 4, 12) = 13.0',
      () {
        final mag = SensorService.calculateMagnitude(3, 4, 12);
        expect(mag, closeTo(13.0, 0.0001));
      },
    );
  });

  group('SensorService - Phân loại trạng thái chuyển động', () {
    test('Độ lớn xấp xỉ 9.8 m/s^2 (netAcc < 1.0) -> Đứng yên (Tĩnh)', () {
      expect(SensorService.classifyMotion(9.80665), equals('Đứng yên (Tĩnh)'));
      expect(SensorService.classifyMotion(10.2), equals('Đứng yên (Tĩnh)'));
      expect(SensorService.classifyMotion(9.0), equals('Đứng yên (Tĩnh)'));
    });

    test(
      'Độ lớn dao động vừa phải (1.0 <= netAcc < 4.0) -> Chuyển động nhẹ',
      () {
        // 9.80665 + 2.0 = 11.80665 (netAcc = 2.0)
        expect(
          SensorService.classifyMotion(11.80665),
          equals('Chuyển động nhẹ'),
        );
        // 9.80665 - 2.5 = 7.30665 (netAcc = 2.5)
        expect(
          SensorService.classifyMotion(7.30665),
          equals('Chuyển động nhẹ'),
        );
      },
    );

    test('Độ lớn biến thiên mạnh (netAcc >= 4.0) -> Chuyển động mạnh / Đang di chuyển', () {
      // 9.80665 + 5.0 = 14.80665 (netAcc = 5.0)
      expect(
        SensorService.classifyMotion(14.80665),
        equals('Chuyển động mạnh / Đang di chuyển'),
      );
      // Rơi tự do hoặc lắc mạnh: magnitude = 25.0
      expect(
        SensorService.classifyMotion(25.0),
        equals('Chuyển động mạnh / Đang di chuyển'),
      );
    });

    test('Kiểm tra giá trị biên tại ngưỡng phân loại', () {
      // Biên 1: netAcc = 0.99 -> Đứng yên
      expect(
        SensorService.classifyMotion(9.80665 + 0.99),
        equals('Đứng yên (Tĩnh)'),
      );
      // Biên 2: netAcc = 1.01 -> Chuyển động nhẹ
      expect(
        SensorService.classifyMotion(9.80665 + 1.01),
        equals('Chuyển động nhẹ'),
      );
      // Biên 3: netAcc = 3.99 -> Chuyển động nhẹ
      expect(
        SensorService.classifyMotion(9.80665 + 3.99),
        equals('Chuyển động nhẹ'),
      );
      // Biên 4: netAcc = 4.01 -> Chuyển động mạnh
      expect(
        SensorService.classifyMotion(9.80665 + 4.01),
        equals('Chuyển động mạnh / Đang di chuyển'),
      );
    });
  });
}
