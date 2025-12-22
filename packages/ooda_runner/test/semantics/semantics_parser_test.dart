import 'package:ooda_runner/src/semantics/semantics_parser.dart';
import 'package:test/test.dart';

void main() {
  group('SemanticsParser', () {
    group('parse', () {
      test('returns null for empty string', () {
        expect(SemanticsParser.parse(''), isNull);
        expect(SemanticsParser.parse('   '), isNull);
      });

      test('parses simple node with label', () {
        const dump = '''
SemanticsNode#22
  Rect.fromLTRB(16.0, 16.0, 344.0, 72.0)
  label: "Email"
''';
        final node = SemanticsParser.parse(dump);

        expect(node, isNotNull);
        expect(node!.id, equals(22));
        expect(node.label, equals('Email'));
        expect(node.bounds, equals(const SemanticsRect.fromLTRB(16.0, 16.0, 344.0, 72.0)));
      });

      test('parses node with actions and flags', () {
        const dump = '''
SemanticsNode#22
  Rect.fromLTRB(16.0, 16.0, 344.0, 72.0)
  actions: focus, tap
  flags: isTextField, hasEnabledState, isEnabled
  label: "Email"
''';
        final node = SemanticsParser.parse(dump);

        expect(node, isNotNull);
        expect(node!.actions, containsAll(['focus', 'tap']));
        expect(node.flags, containsAll(['isTextField', 'hasEnabledState', 'isEnabled']));
      });

      test('parses node with value', () {
        const dump = '''
SemanticsNode#22
  Rect.fromLTRB(16.0, 16.0, 344.0, 72.0)
  label: "Email"
  value: "user@example.com"
''';
        final node = SemanticsParser.parse(dump);

        expect(node, isNotNull);
        expect(node!.value, equals('user@example.com'));
      });

      test('parses nested tree structure', () {
        const dump = '''
SemanticsNode#0
 │ Rect.fromLTRB(0.0, 0.0, 1080.0, 2340.0)
 │
 └─SemanticsNode#1
   │ Rect.fromLTRB(0.0, 0.0, 360.0, 780.0)
   │
   ├─SemanticsNode#22
   │   Rect.fromLTRB(16.0, 16.0, 344.0, 72.0)
   │   label: "Email"
   │
   └─SemanticsNode#24
       Rect.fromLTRB(16.0, 88.0, 344.0, 144.0)
       label: "Password"
''';
        final root = SemanticsParser.parse(dump);

        expect(root, isNotNull);
        expect(root!.id, equals(0));
        expect(root.children, hasLength(1));

        final child1 = root.children[0];
        expect(child1.id, equals(1));
        expect(child1.children, hasLength(2));

        final email = child1.children[0];
        expect(email.id, equals(22));
        expect(email.label, equals('Email'));

        final password = child1.children[1];
        expect(password.id, equals(24));
        expect(password.label, equals('Password'));
      });

      test('handles scaled nodes', () {
        const dump = '''
SemanticsNode#0
 │ Rect.fromLTRB(0.0, 0.0, 1080.0, 2340.0)
 │
 └─SemanticsNode#1
     Rect.fromLTRB(0.0, 0.0, 360.0, 780.0) scaled by 3.0x
     label: "Scaled"
''';
        final root = SemanticsParser.parse(dump);

        expect(root, isNotNull);
        final child = root!.children[0];
        expect(child.scale, equals(3.0));
        expect(child.bounds, equals(const SemanticsRect.fromLTRB(0.0, 0.0, 360.0, 780.0)));
        expect(
          child.absoluteBounds,
          equals(const SemanticsRect.fromLTRB(0.0, 0.0, 1080.0, 2340.0)),
        );
      });
    });

    group('findByLabel', () {
      test('finds node by exact label match', () {
        const dump = '''
SemanticsNode#0
 │ Rect.fromLTRB(0.0, 0.0, 1080.0, 2340.0)
 │
 └─SemanticsNode#1
   │ Rect.fromLTRB(0.0, 0.0, 360.0, 780.0)
   │
   ├─SemanticsNode#22
   │   Rect.fromLTRB(16.0, 16.0, 344.0, 72.0)
   │   label: "Email"
   │
   └─SemanticsNode#24
       Rect.fromLTRB(16.0, 88.0, 344.0, 144.0)
       label: "Password"
''';
        final root = SemanticsParser.parse(dump)!;
        final matches = SemanticsParser.findByLabel(root, 'Email');

        expect(matches, hasLength(1));
        expect(matches[0].id, equals(22));
        expect(matches[0].bounds, equals(const SemanticsRect.fromLTRB(16.0, 16.0, 344.0, 72.0)));
      });

      test('finds multiple nodes with same label', () {
        const dump = '''
SemanticsNode#0
 │ Rect.fromLTRB(0.0, 0.0, 1080.0, 2340.0)
 │
 ├─SemanticsNode#38
 │   Rect.fromLTRB(16.0, 44.3, 70.2, 72.3)
 │   label: "Login"
 │
 └─SemanticsNode#32
     Rect.fromLTRB(0.0, 0.0, 328.0, 48.0)
     label: "Login"
''';
        final root = SemanticsParser.parse(dump)!;
        final matches = SemanticsParser.findByLabel(root, 'Login');

        expect(matches, hasLength(2));
        expect(matches[0].id, equals(38));
        expect(matches[1].id, equals(32));
      });

      test('returns empty list when label not found', () {
        const dump = '''
SemanticsNode#0
  Rect.fromLTRB(0.0, 0.0, 1080.0, 2340.0)
  label: "Email"
''';
        final root = SemanticsParser.parse(dump)!;
        final matches = SemanticsParser.findByLabel(root, 'NonExistent');

        expect(matches, isEmpty);
      });
    });

    group('findFirstByLabel', () {
      test('returns first matching node', () {
        const dump = '''
SemanticsNode#0
 │ Rect.fromLTRB(0.0, 0.0, 1080.0, 2340.0)
 │
 ├─SemanticsNode#38
 │   Rect.fromLTRB(16.0, 44.3, 70.2, 72.3)
 │   label: "Login"
 │
 └─SemanticsNode#32
     Rect.fromLTRB(0.0, 0.0, 328.0, 48.0)
     label: "Login"
''';
        final root = SemanticsParser.parse(dump)!;
        final node = SemanticsParser.findFirstByLabel(root, 'Login');

        expect(node, isNotNull);
        expect(node!.id, equals(38));
      });

      test('returns null when label not found', () {
        const dump = '''
SemanticsNode#0
  Rect.fromLTRB(0.0, 0.0, 1080.0, 2340.0)
  label: "Email"
''';
        final root = SemanticsParser.parse(dump)!;
        final node = SemanticsParser.findFirstByLabel(root, 'NonExistent');

        expect(node, isNull);
      });
    });

    group('SemanticsNode', () {
      test('absoluteBounds applies scale', () {
        const node = SemanticsNode(
          id: 1,
          bounds: SemanticsRect.fromLTRB(0, 0, 100, 200),
          scale: 2.0,
        );

        expect(node.absoluteBounds, equals(const SemanticsRect.fromLTRB(0, 0, 200, 400)));
      });

      test('toString includes id and label', () {
        const node = SemanticsNode(
          id: 22,
          bounds: SemanticsRect.fromLTRB(16, 16, 344, 72),
          label: 'Email',
        );

        expect(node.toString(), contains('22'));
        expect(node.toString(), contains('Email'));
      });
    });

    group('SemanticsRect', () {
      test('centerX returns horizontal center', () {
        const rect = SemanticsRect.fromLTRB(100, 200, 300, 400);
        expect(rect.centerX, equals(200.0));
      });

      test('centerY returns vertical center', () {
        const rect = SemanticsRect.fromLTRB(100, 200, 300, 400);
        expect(rect.centerY, equals(300.0));
      });

      test('width and height are correct', () {
        const rect = SemanticsRect.fromLTRB(10, 20, 110, 220);
        expect(rect.width, equals(100.0));
        expect(rect.height, equals(200.0));
      });

      test('zero rect has zero center', () {
        expect(SemanticsRect.zero.centerX, equals(0.0));
        expect(SemanticsRect.zero.centerY, equals(0.0));
      });
    });

    group('visibility filtering', () {
      test('node with center on screen is visible', () {
        const screenWidth = 1080;
        const screenHeight = 1920;
        const node = SemanticsNode(
          id: 1,
          bounds: SemanticsRect.fromLTRB(100, 200, 300, 400),
        );
        final bounds = node.absoluteBounds;
        final x = bounds.centerX;
        final y = bounds.centerY;
        final isVisible =
            x >= 0 && x <= screenWidth && y >= 0 && y <= screenHeight;
        expect(isVisible, isTrue);
      });

      test('node with negative Y center is off-screen (scrolled up)', () {
        const screenWidth = 1080;
        const screenHeight = 1920;
        // Node that has been scrolled up off screen
        const node = SemanticsNode(
          id: 1,
          bounds: SemanticsRect.fromLTRB(100, -300, 300, -100),
        );
        final bounds = node.absoluteBounds;
        final y = bounds.centerY;
        final isVisible = y >= 0 && y <= screenHeight;
        expect(isVisible, isFalse);
        expect(y, equals(-200.0));
      });

      test('node with Y center below screen is off-screen (scrolled down)', () {
        const screenWidth = 1080;
        const screenHeight = 1920;
        // Node that is below the visible area
        const node = SemanticsNode(
          id: 1,
          bounds: SemanticsRect.fromLTRB(100, 2000, 300, 2200),
        );
        final bounds = node.absoluteBounds;
        final y = bounds.centerY;
        final isVisible = y >= 0 && y <= screenHeight;
        expect(isVisible, isFalse);
        expect(y, equals(2100.0));
      });

      test('scaled node visibility uses absoluteBounds', () {
        const screenWidth = 1080;
        const screenHeight = 1920;
        // Node at 0-100 scaled 3x becomes 0-300
        const node = SemanticsNode(
          id: 1,
          bounds: SemanticsRect.fromLTRB(0, 0, 100, 100),
          scale: 3.0,
        );
        final bounds = node.absoluteBounds;
        expect(bounds.centerX, equals(150.0));
        expect(bounds.centerY, equals(150.0));
        final isVisible = bounds.centerX >= 0 &&
            bounds.centerX <= screenWidth &&
            bounds.centerY >= 0 &&
            bounds.centerY <= screenHeight;
        expect(isVisible, isTrue);
      });
    });
  });
}
