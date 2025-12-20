import 'package:flutter_test/flutter_test.dart';

import 'package:scroll_app/main.dart';

void main() {
  testWidgets('ScrollApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ScrollApp());
    expect(find.text('Scroll Test'), findsOneWidget);
  });
}
