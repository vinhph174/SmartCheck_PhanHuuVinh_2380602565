class DisplayText {
  DisplayText._();

  static const appName = 'CHẤM CÔNG THÔNG MINH';
  static const appNameTitleCase = 'Chấm Công Thông Minh';

  static String role(String value) {
    return switch (value) {
      'Admin' => 'Quản trị viên',
      'Employee' => 'Nhân viên',
      _ => 'Không xác định',
    };
  }

  static String shiftStatus(String value) {
    return switch (value) {
      'Scheduled' => 'Đã lên lịch',
      'InProgress' => 'Đang làm việc',
      'Completed' => 'Đã hoàn thành',
      'Cancelled' => 'Đã hủy',
      _ => 'Không xác định',
    };
  }

  static String attendanceStatus(String? value) {
    return switch (value) {
      'OnTime' => 'Đúng giờ',
      'Late' => 'Đi muộn',
      _ => 'Chưa xác định',
    };
  }

  static String appealStatus(String value) {
    return switch (value) {
      'Pending' => 'Chờ duyệt',
      'Approved' => 'Đã phê duyệt',
      'Rejected' => 'Đã từ chối',
      _ => 'Không xác định',
    };
  }

  static String attendancePurpose(String value) {
    return switch (value) {
      'CheckIn' => 'Chấm công vào',
      'CheckOut' => 'Chấm công ra',
      _ => 'Không xác định',
    };
  }
}
