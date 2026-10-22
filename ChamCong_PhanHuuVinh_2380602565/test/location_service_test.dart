import 'package:flutter_test/flutter_test.dart';
import 'package:chamcong_phanhuuvinh_2380602565/services/location_service.dart';

void main() {
  group('LocationService - Tính khoảng cách GPS (Haversine)', () {
    test('Khoảng cách giữa hai điểm trùng nhau trả về 0.0m', () {
      final distance = LocationService.calculateDistanceMeters(
        10.7769,
        106.7009,
        10.7769,
        106.7009,
      );
      expect(distance, closeTo(0.0, 0.01));
    });

    test('Khoảng cách giữa 2 điểm gần nhau trong nội thành TP.HCM', () {
      // Điểm 1: Nhà thờ Đức Bà (10.7797, 106.6990)
      // Điểm 2: Chợ Bến Thành (10.7725, 106.6980)
      // Khoảng cách thực địa ~ 800m
      final distance = LocationService.calculateDistanceMeters(
        10.7797,
        106.6990,
        10.7725,
        106.6980,
      );
      expect(distance, greaterThan(750.0));
      expect(distance, lessThan(850.0));
    });

    test('Khoảng cách nhỏ trong phạm vi bán kính chấm công (20m - 50m)', () {
      // Dịch chuyển vĩ độ ~ 0.0002 độ tương đương ~ 22 mét
      final distance = LocationService.calculateDistanceMeters(
        10.7769,
        106.7009,
        10.7771,
        106.7009,
      );
      expect(distance, greaterThan(20.0));
      expect(distance, lessThan(25.0));
    });
  });
}
