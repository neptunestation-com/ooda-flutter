import 'package:flutter_test/flutter_test.dart';

import 'package:gestures_app/main.dart';

void main() {
  testWidgets('GesturesApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const GesturesApp());
    expect(find.text('Gestures Test'), findsOneWidget);
  });
}
