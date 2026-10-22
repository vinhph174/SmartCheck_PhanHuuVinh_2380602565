import 'package:geolocator/geolocator.dart';

class LocationService {
  static Future<bool> isServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  static Future<LocationPermission> checkAndRequestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Dịch vụ định vị GPS chưa được bật trên thiết bị.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Quyền truy cập vị trí GPS bị từ chối.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Quyền vị trí bị từ chối vĩnh viễn. Vui lòng cấp quyền trong Cài đặt thiết bị.',
      );
    }

    return permission;
  }

  static Future<Position> getCurrentPosition() async {
    await checkAndRequestPermission();
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 10),
    );
    return await Geolocator.getCurrentPosition(
      locationSettings: locationSettings,
    );
  }

  static double calculateDistanceMeters(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }
}
