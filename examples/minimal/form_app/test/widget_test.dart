import 'package:flutter_test/flutter_test.dart';

import 'package:form_app/main.dart';

void main() {
  testWidgets('FormApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const FormApp());
    expect(find.text('Form Test'), findsOneWidget);
  });
}
