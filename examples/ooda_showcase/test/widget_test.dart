import 'package:flutter_test/flutter_test.dart';

import 'package:ooda_showcase/app.dart';

void main() {
  testWidgets('OodaShowcaseApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const OodaShowcaseApp());
    expect(find.text('OODA Showcase'), findsOneWidget);
  });
}
