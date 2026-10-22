import 'package:flutter_test/flutter_test.dart';
import 'package:chamcong_phanhuuvinh_2380602565/main.dart';

void main() {
  testWidgets('SmartCheckApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartCheckApp());
    expect(find.text('CHẤM CÔNG THÔNG MINH'), findsOneWidget);
  });
}
