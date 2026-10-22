import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';

class MotionData {
  final double x;
  final double y;
  final double z;
  final double magnitude;
  final String status; // 'Đứng yên', 'Di chuyển nhẹ', 'Đang chuyển động mạnh'
  final DateTime timestamp;

  MotionData({
    required this.x,
    required this.y,
    required this.z,
    required this.magnitude,
    required this.status,
    required this.timestamp,
  });
}

class SensorService {
  /// Tính độ lớn vector gia tốc: |a| = sqrt(x^2 + y^2 + z^2)
  static double calculateMagnitude(double x, double y, double z) {
    return sqrt(x * x + y * y + z * z);
  }

  /// Phân loại trạng thái chuyển động dựa trên độ lệch khỏi trọng lực trái đất (9.80665 m/s^2)
  static String classifyMotion(double magnitude) {
    final netAcc = (magnitude - 9.80665).abs();
    if (netAcc < 1.0) {
      return 'Đứng yên (Tĩnh)';
    } else if (netAcc < 4.0) {
      return 'Chuyển động nhẹ';
    } else {
      return 'Chuyển động mạnh / Đang di chuyển';
    }
  }

  Stream<MotionData> get motionStream {
    return accelerometerEventStream().map((event) {
      final mag = calculateMagnitude(event.x, event.y, event.z);
      final status = classifyMotion(mag);

      return MotionData(
        x: event.x,
        y: event.y,
        z: event.z,
        magnitude: mag,
        status: status,
        timestamp: DateTime.now(),
      );
    });
  }
}
