import 'package:flutter_test/flutter_test.dart';
import 'package:chamcong_phanhuuvinh_2380602565/models/models.dart';

void main() {
  group('Smart Appeal Assistant Models & Logic', () {
    test('AppealSuggestionModel fromJson parse đầy đủ các trường', () {
      final json = {
        'shiftAssignmentId': 101,
        'workDate': '2026-10-21',
        'shiftName': 'Ca Hành Chính',
        'locationName': 'Trụ Sở SmartCheck',
        'anomalyType': 'LateCheckIn',
        'anomalyDescription': 'Vào ca muộn so với quy định',
        'suggestedReason': 'Tôi xin giải trình về trường hợp vào ca muộn trong ca Ca Hành Chính ngày 21/10/2026. Lý do thực tế: ',
      };

      final model = AppealSuggestionModel.fromJson(json);

      expect(model.shiftAssignmentId, 101);
      expect(model.workDate, '2026-10-21');
      expect(model.shiftName, 'Ca Hành Chính');
      expect(model.locationName, 'Trụ Sở SmartCheck');
      expect(model.anomalyType, 'LateCheckIn');
      expect(model.anomalyDescription, 'Vào ca muộn so với quy định');
      expect(
        model.suggestedReason,
        contains('Tôi xin giải trình về trường hợp'),
      );
      expect(model.suggestedReason, contains('Lý do thực tế: '));
    });

    test(
      'AttendanceAppealModel fromJson parse đúng trạng thái và review note',
      () {
        final json = {
          'id': 55,
          'employeeId': 2,
          'employeeCode': 'NV002',
          'employeeName': 'Nguyễn Văn B',
          'departmentName': 'Phòng CNTT',
          'shiftAssignmentId': 101,
          'workDate': '2026-10-21',
          'shiftName': 'Ca Hành Chính',
          'locationName': 'Trụ Sở SmartCheck',
          'reason': 'Tôi xin giải trình do gặp sự cố giao thông trên đường.',
          'status': 'Approved',
          'reviewNote': 'Đã đối soát camera và chấp thuận.',
          'reviewedBy': 'Quản trị viên',
          'submittedAtUtc': '2026-10-21T08:30:00Z',
          'reviewedAtUtc': '2026-10-21T09:00:00Z',
        };

        final appeal = AttendanceAppealModel.fromJson(json);

        expect(appeal.id, 55);
        expect(appeal.employeeName, 'Nguyễn Văn B');
        expect(appeal.status, 'Approved');
        expect(appeal.reviewNote, 'Đã đối soát camera và chấp thuận.');
        expect(appeal.reviewedBy, 'Quản trị viên');
      },
    );

    test('AttendanceAppealModel gán Status mặc định là Pending khi null', () {
      final json = {
        'id': 56,
        'shiftAssignmentId': 102,
        'workDate': '2026-10-21',
        'shiftName': 'Ca Chiều',
        'locationName': 'Trụ Sở SmartCheck',
        'reason': 'Lý do giải trình tối thiểu 5 ký tự',
        'submittedAtUtc': '2026-10-21T10:00:00Z',
      };

      final appeal = AttendanceAppealModel.fromJson(json);
      expect(appeal.status, 'Pending');
      expect(appeal.reviewNote, isNull);
    });
  });
}
