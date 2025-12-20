import 'package:flutter_test/flutter_test.dart';

import 'package:dialog_app/main.dart';

void main() {
  testWidgets('DialogApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DialogApp());
    expect(find.text('Dialog Test'), findsOneWidget);
  });
}
