import 'package:ooda_runner/src/runner/flutter_session.dart';
import 'package:test/test.dart';

void main() {
  group('FlutterSessionConfig', () {
    test('builds basic args', () {
      const config = FlutterSessionConfig(projectPath: '/path/to/project');

      final args = config.buildArgs();

      expect(args, contains('run'));
      expect(args, contains('--machine'));
    });

    test('builds args with device', () {
      const config = FlutterSessionConfig(
        projectPath: '/path/to/project',
        deviceId: 'emulator-5554',
      );

      final args = config.buildArgs();

      expect(args, contains('-d'));
      expect(args, contains('emulator-5554'));
    });

    test('builds args with flavor', () {
      const config = FlutterSessionConfig(
        projectPath: '/path/to/project',
        flavor: 'production',
      );

      final args = config.buildArgs();

      expect(args, contains('--flavor'));
      expect(args, contains('production'));
    });

    test('builds args with target', () {
      const config = FlutterSessionConfig(
        projectPath: '/path/to/project',
        target: 'lib/main_dev.dart',
      );

      final args = config.buildArgs();

      expect(args, contains('-t'));
      expect(args, contains('lib/main_dev.dart'));
    });

    test('builds args with additional args', () {
      const config = FlutterSessionConfig(
        projectPath: '/path/to/project',
        additionalArgs: ['--verbose', '--debug'],
      );

      final args = config.buildArgs();

      expect(args, contains('--verbose'));
      expect(args, contains('--debug'));
    });

    test('builds args with all options', () {
      const config = FlutterSessionConfig(
        projectPath: '/path/to/project',
        deviceId: 'emulator-5554',
        flavor: 'dev',
        target: 'lib/main_dev.dart',
        additionalArgs: ['--verbose'],
      );

      final args = config.buildArgs();

      expect(args[0], 'run');
      expect(args[1], '--machine');
      expect(args.contains('-d'), isTrue);
      expect(args.contains('--flavor'), isTrue);
      expect(args.contains('-t'), isTrue);
    });
  });

  group('FlutterSessionState', () {
    test('has all expected states', () {
      expect(FlutterSessionState.values, hasLength(5));
      expect(
        FlutterSessionState.values,
        contains(FlutterSessionState.starting),
      );
      expect(FlutterSessionState.values, contains(FlutterSessionState.running));
      expect(
        FlutterSessionState.values,
        contains(FlutterSessionState.stopping),
      );
      expect(FlutterSessionState.values, contains(FlutterSessionState.stopped));
      expect(FlutterSessionState.values, contains(FlutterSessionState.error));
    });
  });

  group('AppInfo', () {
    test('creates with required fields', () {
      final info = AppInfo(appId: 'test-app', deviceId: 'emulator-5554');

      expect(info.appId, 'test-app');
      expect(info.deviceId, 'emulator-5554');
      expect(info.supportsRestart, isTrue);
      expect(info.vmServiceUri, isNull);
    });

    test('creates with all fields', () {
      final info = AppInfo(
        appId: 'test-app',
        deviceId: 'emulator-5554',
        directory: '/path/to/project',
        supportsRestart: false,
        vmServiceUri: Uri.parse('ws://127.0.0.1:12345/ws'),
      );

      expect(info.directory, '/path/to/project');
      expect(info.supportsRestart, isFalse);
      expect(info.vmServiceUri, isNotNull);
    });

    test('toString includes app and device', () {
      final info = AppInfo(appId: 'my-app', deviceId: 'device-1');
      final str = info.toString();

      expect(str, contains('my-app'));
      expect(str, contains('device-1'));
    });
  });

  group('FlutterSessionException', () {
    test('creates with message only', () {
      final exception = FlutterSessionException('Test error');

      expect(exception.message, 'Test error');
      expect(exception.cause, isNull);
      expect(exception.toString(), contains('Test error'));
    });

    test('creates with cause', () {
      final cause = Exception('Root cause');
      final exception = FlutterSessionException('Test error', cause: cause);

      expect(exception.cause, cause);
      expect(exception.toString(), contains('Root cause'));
    });
  });
}
