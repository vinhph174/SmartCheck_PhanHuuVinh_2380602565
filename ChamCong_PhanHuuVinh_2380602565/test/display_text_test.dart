import 'package:flutter_test/flutter_test.dart';
import 'package:chamcong_phanhuuvinh_2380602565/config/display_text.dart';
import 'package:chamcong_phanhuuvinh_2380602565/models/models.dart';

void main() {
  test('Việt hóa vai trò và trạng thái kỹ thuật', () {
    expect(DisplayText.role('Admin'), 'Quản trị viên');
    expect(DisplayText.role('Employee'), 'Nhân viên');
    expect(DisplayText.shiftStatus('Scheduled'), 'Đã lên lịch');
    expect(DisplayText.shiftStatus('InProgress'), 'Đang làm việc');
    expect(DisplayText.shiftStatus('Completed'), 'Đã hoàn thành');
    expect(DisplayText.attendanceStatus('OnTime'), 'Đúng giờ');
    expect(DisplayText.attendanceStatus('Late'), 'Đi muộn');
    expect(DisplayText.appealStatus('Pending'), 'Chờ duyệt');
    expect(DisplayText.appealStatus('Approved'), 'Đã phê duyệt');
    expect(DisplayText.appealStatus('Rejected'), 'Đã từ chối');
    expect(DisplayText.attendancePurpose('CheckIn'), 'Chấm công vào');
    expect(DisplayText.attendancePurpose('CheckOut'), 'Chấm công ra');
  });

  test('nhân viên chỉ hoạt động khi cả hồ sơ và tài khoản đều active', () {
    EmployeeModel employee({required bool employeeActive, bool? userActive}) {
      return EmployeeModel(
        employeeId: 1,
        employeeCode: 'NV001',
        userName: 'nv001',
        fullName: 'Nhân viên',
        email: 'employee@example.test',
        emailConfirmed: true,
        isActive: employeeActive,
        userActive: userActive,
      );
    }

    expect(
      employee(employeeActive: true, userActive: true).isFullyActive,
      isTrue,
    );
    expect(
      employee(employeeActive: true, userActive: false).isFullyActive,
      isFalse,
    );
    expect(
      employee(employeeActive: false, userActive: true).isFullyActive,
      isFalse,
    );
  });
}
