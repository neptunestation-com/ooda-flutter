import 'package:flutter_test/flutter_test.dart';

import 'package:animation_app/main.dart';

void main() {
  testWidgets('AnimationApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AnimationApp());
    expect(find.text('Animation Test'), findsOneWidget);
  });
}
