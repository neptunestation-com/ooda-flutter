import 'package:flutter_test/flutter_test.dart';

import 'package:keyboard_app/main.dart';

void main() {
  testWidgets('KeyboardApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const KeyboardApp());
    expect(find.text('Keyboard Test'), findsOneWidget);
  });
}
