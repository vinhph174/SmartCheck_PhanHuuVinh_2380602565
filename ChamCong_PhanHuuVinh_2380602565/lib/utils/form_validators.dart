class FormValidators {
  FormValidators._();

  static String? departmentName(String value) {
    if (value.trim().isEmpty) return 'Vui lòng nhập tên phòng ban.';
    if (value.trim().length > 100) {
      return 'Tên phòng ban không được vượt quá 100 ký tự.';
    }
    return null;
  }

  static String? shift({
    required String name,
    required String graceMinutes,
    required int startMinutes,
    required int endMinutes,
  }) {
    if (name.trim().isEmpty) return 'Vui lòng nhập tên ca làm việc.';
    if (startMinutes == endMinutes) {
      return 'Giờ bắt đầu và kết thúc phải khác nhau.';
    }
    final grace = int.tryParse(graceMinutes.trim());
    if (grace == null || grace < 0 || grace > 120) {
      return 'Số phút cho phép phải từ 0 đến 120.';
    }
    return null;
  }

  static double? parseDecimal(String value) {
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }

  static String? location({
    required String name,
    required String address,
    required String latitude,
    required String longitude,
    required String radiusMeters,
  }) {
    if (name.trim().isEmpty || address.trim().isEmpty) {
      return 'Vui lòng nhập đầy đủ tên và địa chỉ.';
    }
    final lat = parseDecimal(latitude);
    if (lat == null || lat < -90 || lat > 90) {
      return 'Vĩ độ phải là số từ -90 đến 90.';
    }
    final lng = parseDecimal(longitude);
    if (lng == null || lng < -180 || lng > 180) {
      return 'Kinh độ phải là số từ -180 đến 180.';
    }
    final radius = int.tryParse(radiusMeters.trim());
    if (radius == null || radius < 1 || radius > 5000) {
      return 'Bán kính phải là số từ 1 đến 5000 mét.';
    }
    return null;
  }

  static String? appealReason(String value) {
    final reason = value.trim();
    if (reason.length < 5) {
      return 'Lý do giải trình phải từ 5 ký tự trở lên.';
    }

    const marker = 'lý do thực tế:';
    final markerIndex = reason.toLowerCase().lastIndexOf(marker);
    if (markerIndex >= 0) {
      final actualReason = reason.substring(markerIndex + marker.length).trim();
      if (actualReason.length < 3) {
        return 'Vui lòng nhập lý do thực tế sau phần gợi ý.';
      }
    }
    return null;
  }
}
