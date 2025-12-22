import 'package:test/test.dart';
import 'package:ooda_runner/src/update_checker.dart';

void main() {
  group('parseVersion', () {
    test('parses standard semver', () {
      expect(parseVersion('1.2.3'), equals([1, 2, 3]));
      expect(parseVersion('0.1.0'), equals([0, 1, 0]));
      expect(parseVersion('10.20.30'), equals([10, 20, 30]));
    });

    test('parses semver with prerelease suffix', () {
      expect(parseVersion('1.2.3-beta'), equals([1, 2, 3]));
      expect(parseVersion('0.1.0-alpha.1'), equals([0, 1, 0]));
    });

    test('returns null for invalid versions', () {
      expect(parseVersion('invalid'), isNull);
      expect(parseVersion('1.2'), isNull);
      expect(parseVersion('v1.2.3'), isNull);
      expect(parseVersion(''), isNull);
    });
  });

  group('isNewerVersion', () {
    test('detects newer major version', () {
      expect(isNewerVersion('2.0.0', '1.0.0'), isTrue);
      expect(isNewerVersion('1.0.0', '2.0.0'), isFalse);
    });

    test('detects newer minor version', () {
      expect(isNewerVersion('1.2.0', '1.1.0'), isTrue);
      expect(isNewerVersion('1.1.0', '1.2.0'), isFalse);
    });

    test('detects newer patch version', () {
      expect(isNewerVersion('1.1.2', '1.1.1'), isTrue);
      expect(isNewerVersion('1.1.1', '1.1.2'), isFalse);
    });

    test('returns false for equal versions', () {
      expect(isNewerVersion('1.0.0', '1.0.0'), isFalse);
      expect(isNewerVersion('0.1.0', '0.1.0'), isFalse);
    });

    test('returns false for invalid versions', () {
      expect(isNewerVersion('invalid', '1.0.0'), isFalse);
      expect(isNewerVersion('1.0.0', 'invalid'), isFalse);
      expect(isNewerVersion('invalid', 'also-invalid'), isFalse);
    });

    test('handles large version numbers', () {
      expect(isNewerVersion('100.200.300', '99.999.999'), isTrue);
    });
  });

  group('UpdateCheckResult', () {
    test('printUpdateNotification does nothing when no update available', () {
      const result = UpdateCheckResult(
        updateAvailable: false,
        latestVersion: '0.1.0',
        currentVersion: '0.1.0',
      );

      // Should not throw
      printUpdateNotification(result);
    });
  });
}
