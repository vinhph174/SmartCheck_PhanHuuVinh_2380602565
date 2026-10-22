import 'package:chamcong_phanhuuvinh_2380602565/utils/form_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validation biểu mẫu quản trị', () {
    test('không âm thầm đổi số phút đi muộn không hợp lệ', () {
      expect(
        FormValidators.shift(
          name: 'Ca sáng',
          graceMinutes: 'abc',
          startMinutes: 480,
          endMinutes: 1020,
        ),
        isNotNull,
      );
      expect(
        FormValidators.shift(
          name: 'Ca đêm',
          graceMinutes: '15',
          startMinutes: 1320,
          endMinutes: 360,
        ),
        isNull,
      );
    });

    test('tọa độ sai không bị đổi ngầm thành 0', () {
      expect(
        FormValidators.location(
          name: 'Văn phòng',
          address: 'TP.HCM',
          latitude: 'không-phải-số',
          longitude: '106.7',
          radiusMeters: '200',
        ),
        contains('Vĩ độ'),
      );
      expect(FormValidators.parseDecimal('10,7769'), 10.7769);
    });
  });

  group('validation lý do giải trình', () {
    test('không cho gửi nguyên mẫu gợi ý chưa có lý do thực tế', () {
      expect(
        FormValidators.appealReason(
          'Tôi xin giải trình về trường hợp đi muộn. Lý do thực tế: ',
        ),
        contains('lý do thực tế'),
      );
    });

    test('chấp nhận gợi ý đã được nhân viên bổ sung', () {
      expect(
        FormValidators.appealReason(
          'Tôi xin giải trình về trường hợp đi muộn. Lý do thực tế: Xe bị hỏng.',
        ),
        isNull,
      );
    });
  });
}
