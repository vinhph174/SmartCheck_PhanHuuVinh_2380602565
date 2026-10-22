import 'package:geolocator/geolocator.dart';

import 'location_service.dart';

typedef PositionLoader = Future<Position> Function();

/// Cấp một vị trí mới cho từng lần xác nhận chấm công.
///
/// Lớp này cố ý không lưu cache: mỗi lần gọi đều chuyển tiếp tới nguồn GPS.
class AttendancePositionProvider {
  AttendancePositionProvider({PositionLoader? loader})
    : _loader = loader ?? LocationService.getCurrentPosition;

  final PositionLoader _loader;

  Future<Position> getFreshPosition() => _loader();
}
