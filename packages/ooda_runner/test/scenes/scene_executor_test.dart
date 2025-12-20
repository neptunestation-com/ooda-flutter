import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:mocktail/mocktail.dart';
import 'package:ooda_runner/src/adb/adb_client.dart';
import 'package:ooda_runner/src/runner/flutter_session.dart';
import 'package:ooda_runner/src/scenes/scene_executor.dart' as executor;
import 'package:ooda_shared/ooda_shared.dart';
import 'package:test/test.dart';

class MockFlutterSession extends Mock implements FlutterSession {}

class MockAdbClient extends Mock implements AdbClient {}

Uint8List createTestPng() {
  final image = img.Image(width: 100, height: 100);
  for (int y = 0; y < 100; y++) {
    for (int x = 0; x < 100; x++) {
      image.setPixelRgba(x, y, 255, 0, 0, 255);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  group('SceneResult', () {
    test('creates result with all fields', () {
      final result = executor.SceneResult(
        sceneName: 'test_scene',
        observations: [],
        errors: [],
        elapsed: const Duration(seconds: 5),
        success: true,
      );

      expect(result.sceneName, 'test_scene');
      expect(result.observations, isEmpty);
      expect(result.errors, isEmpty);
      expect(result.elapsed.inSeconds, 5);
      expect(result.success, isTrue);
    });

    test('toString includes all information', () {
      final result = executor.SceneResult(
        sceneName: 'login_flow',
        observations: [],
        errors: [],
        elapsed: const Duration(seconds: 10),
        success: true,
      );

      final str = result.toString();
      expect(str, contains('login_flow'));
      expect(str, contains('observations: 0'));
      expect(str, contains('errors: 0'));
      expect(str, contains('success: true'));
    });
  });

  group('SceneError', () {
    test('creates error with all fields', () {
      final error = executor.SceneError(
        step: 3,
        message: 'Tap failed',
        stackTrace: 'stack trace here',
      );

      expect(error.step, 3);
      expect(error.message, 'Tap failed');
      expect(error.stackTrace, 'stack trace here');
    });

    test('toString format', () {
      final error = executor.SceneError(step: 2, message: 'Input failed');

      expect(error.toString(), contains('step: 2'));
      expect(error.toString(), contains('Input failed'));
    });
  });

  group('SceneExecutionException', () {
    test('creates exception with message', () {
      final exception = executor.SceneExecutionException('Test error');

      expect(exception.message, 'Test error');
      expect(exception.toString(), contains('Test error'));
    });
  });

  group('SceneEvents', () {
    test('SceneStartedEvent has scene name', () {
      const event = executor.SceneStartedEvent('login_flow');
      expect(event.sceneName, 'login_flow');
    });

    test('SceneCompletedEvent has scene name and observation count', () {
      const event = executor.SceneCompletedEvent('login_flow', 5);
      expect(event.sceneName, 'login_flow');
      expect(event.observationCount, 5);
    });

    test('SceneFailedEvent has scene name and error', () {
      const event = executor.SceneFailedEvent('login_flow', 'Connection lost');
      expect(event.sceneName, 'login_flow');
      expect(event.error, 'Connection lost');
    });

    test('StepStartedEvent has index and step', () {
      const step = CheckpointStep(CheckpointDefinition(name: 'test'));
      const event = executor.StepStartedEvent(0, step);
      expect(event.stepIndex, 0);
      expect(event.step, step);
    });

    test('StepCompletedEvent has index and step', () {
      const step = InteractionStep(TapInteraction(x: 100, y: 200));
      const event = executor.StepCompletedEvent(1, step);
      expect(event.stepIndex, 1);
      expect(event.step, step);
    });

    test('StepFailedEvent has index, step, and error', () {
      const step = InteractionStep(TapInteraction(x: 100, y: 200));
      const event = executor.StepFailedEvent(2, step, 'ADB error');
      expect(event.stepIndex, 2);
      expect(event.step, step);
      expect(event.error, 'ADB error');
    });

    test('SceneLogEvent has message and severity', () {
      const event = executor.SceneLogEvent(
        message: 'Capturing checkpoint',
        severity: RunnerEventSeverity.info,
      );
      expect(event.message, 'Capturing checkpoint');
      expect(event.severity, RunnerEventSeverity.info);
    });

    test('SceneLogEvent defaults to info severity', () {
      const event = executor.SceneLogEvent(message: 'Test');
      expect(event.severity, RunnerEventSeverity.info);
    });
  });

  group('SceneExecutor', () {
    late MockFlutterSession mockSession;
    late MockAdbClient mockAdb;
    late Directory tempDir;
    late executor.SceneExecutor sceneExecutor;
    const deviceId = 'emulator-5554';

    setUpAll(() {
      registerFallbackValue(const Duration(seconds: 1));
    });

    setUp(() async {
      mockSession = MockFlutterSession();
      mockAdb = MockAdbClient();
      tempDir = await Directory.systemTemp.createTemp('scene_test_');

      when(() => mockSession.reloadCount).thenReturn(0);
      when(() => mockSession.appInfo).thenReturn(null);

      sceneExecutor = executor.SceneExecutor(
        session: mockSession,
        adb: mockAdb,
        deviceId: deviceId,
        outputDir: tempDir,
      );
    });

    tearDown(() async {
      await sceneExecutor.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('emits events stream', () {
      expect(sceneExecutor.events, isA<Stream<executor.SceneEvent>>());
    });

    test('execute returns result with success when no errors', () async {
      const scene = SceneDefinition(name: 'success_scene', steps: []);

      final result = await sceneExecutor.execute(scene);

      expect(result.success, isTrue);
      expect(result.errors, isEmpty);
      expect(result.sceneName, 'success_scene');
    });

    test('execute performs hot restart when setup requests it', () async {
      const scene = SceneDefinition(
        name: 'restart_scene',
        setup: SceneSetup(hotRestart: true),
        steps: [],
      );

      when(
        () => mockSession.hotRestart(),
      ).thenAnswer((_) async => <String, dynamic>{});

      await sceneExecutor.execute(scene);

      verify(() => mockSession.hotRestart()).called(1);
    });

    test('execute captures checkpoints', () async {
      const scene = SceneDefinition(
        name: 'checkpoint_scene',
        steps: [CheckpointStep(CheckpointDefinition(name: 'test_checkpoint'))],
      );

      when(
        () => mockAdb.screenshot(deviceId),
      ).thenAnswer((_) async => createTestPng());
      when(
        () => mockAdb.logcat(deviceId, lines: any(named: 'lines')),
      ).thenAnswer((_) async => 'logcat output');

      final result = await sceneExecutor.execute(scene);

      expect(result.observations.length, 1);
      expect(result.observations.first.checkpointName, 'test_checkpoint');
    });

    test('execute handles interaction errors gracefully', () async {
      const scene = SceneDefinition(
        name: 'error_scene',
        steps: [InteractionStep(TapInteraction(x: 100, y: 200))],
      );

      when(
        () => mockAdb.tap(deviceId, 100, 200),
      ).thenThrow(AdbException('Device disconnected'));
      when(
        () => mockAdb.screenshot(deviceId),
      ).thenAnswer((_) async => createTestPng());

      final result = await sceneExecutor.execute(scene);

      expect(result.success, isFalse);
      expect(result.errors.length, 1);
      expect(result.errors.first.message, contains('Device disconnected'));
    });

    test('execute handles tap interaction', () async {
      const scene = SceneDefinition(
        name: 'tap_scene',
        steps: [InteractionStep(TapInteraction(x: 100, y: 200))],
      );

      when(() => mockAdb.tap(deviceId, 100, 200)).thenAnswer((_) async => {});
      when(
        () => mockAdb.screenshot(deviceId),
      ).thenAnswer((_) async => createTestPng());

      final result = await sceneExecutor.execute(scene);

      expect(result.success, isTrue);
      verify(() => mockAdb.tap(deviceId, 100, 200)).called(1);
    });
  });
}
