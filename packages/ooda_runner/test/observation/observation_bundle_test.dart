import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ooda_runner/src/observation/observation_bundle.dart';
import 'package:ooda_shared/ooda_shared.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('ObservationBundle', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ooda_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('creates bundle with required fields', () {
      final metadata = ObservationMetadata(
        sceneName: 'test_scene',
        checkpointName: 'test_checkpoint',
        timestamp: DateTime.now(),
        overlayPresent: false,
        deviceId: 'emulator-5554',
      );

      final bundle = ObservationBundle(
        sceneName: 'test_scene',
        checkpointName: 'test_checkpoint',
        metadata: metadata,
      );

      expect(bundle.sceneName, 'test_scene');
      expect(bundle.checkpointName, 'test_checkpoint');
      expect(bundle.overlayPresent, isFalse);
    });

    test('writes bundle to directory', () async {
      final metadata = ObservationMetadata(
        sceneName: 'login_flow',
        checkpointName: 'initial',
        timestamp: DateTime.now(),
        overlayPresent: false,
        deviceId: 'emulator-5554',
      );

      final bundle = ObservationBundle(
        sceneName: 'login_flow',
        checkpointName: 'initial',
        deviceScreenshot: Uint8List.fromList([1, 2, 3]),
        widgetTree: {'widget': 'Container'},
        logs: ['Log line 1', 'Log line 2'],
        metadata: metadata,
      );

      final outputDir = await bundle.write(tempDir);

      expect(await outputDir.exists(), isTrue);
      expect(
        await File(p.join(outputDir.path, 'meta.json')).exists(),
        isTrue,
      );
      expect(
        await File(p.join(outputDir.path, 'device.png')).exists(),
        isTrue,
      );
      expect(
        await File(p.join(outputDir.path, 'widget_tree.json')).exists(),
        isTrue,
      );
      expect(
        await File(p.join(outputDir.path, 'logs.txt')).exists(),
        isTrue,
      );
    });

    test('writes correct directory structure', () async {
      final metadata = ObservationMetadata(
        sceneName: 'scene1',
        checkpointName: 'checkpoint1',
        timestamp: DateTime.now(),
        overlayPresent: false,
        deviceId: 'device1',
      );

      final bundle = ObservationBundle(
        sceneName: 'scene1',
        checkpointName: 'checkpoint1',
        metadata: metadata,
      );

      final outputDir = await bundle.write(tempDir);

      expect(
        outputDir.path,
        equals(p.join(tempDir.path, 'scene1', 'checkpoint1')),
      );
    });

    test('reads bundle from directory', () async {
      // First write a bundle
      final originalMetadata = ObservationMetadata(
        sceneName: 'test_scene',
        checkpointName: 'test_checkpoint',
        timestamp: DateTime.parse('2025-01-15T10:30:00Z'),
        overlayPresent: false,
        deviceId: 'emulator-5554',
      );

      final original = ObservationBundle(
        sceneName: 'test_scene',
        checkpointName: 'test_checkpoint',
        widgetTree: {'widget': 'Text', 'value': 'Hello'},
        logs: ['Log 1', 'Log 2'],
        metadata: originalMetadata,
      );

      final outputDir = await original.write(tempDir);

      // Then read it back
      final restored = await ObservationBundle.read(outputDir);

      expect(restored.sceneName, 'test_scene');
      expect(restored.checkpointName, 'test_checkpoint');
      expect(restored.widgetTree, {'widget': 'Text', 'value': 'Hello'});
      expect(restored.logs, ['Log 1', 'Log 2']);
    });

    test('throws on missing meta.json', () async {
      final emptyDir = Directory(p.join(tempDir.path, 'empty'));
      await emptyDir.create();

      expect(
        () => ObservationBundle.read(emptyDir),
        throwsA(isA<ObservationBundleException>()),
      );
    });
  });

  group('ObservationBundleBuilder', () {
    test('builds bundle with all fields', () {
      final bundle = ObservationBundleBuilder()
          .scene('test_scene')
          .checkpoint('test_checkpoint', description: 'Test description')
          .device('emulator-5554')
          .deviceScreenshot(Uint8List.fromList([1, 2, 3]))
          .widgetTree({'widget': 'Container'})
          .addLog('Log line 1')
          .addLogs(['Log line 2', 'Log line 3'])
          .reload(5)
          .stability('stable')
          .build();

      expect(bundle.sceneName, 'test_scene');
      expect(bundle.checkpointName, 'test_checkpoint');
      expect(bundle.deviceScreenshot, isNotNull);
      expect(bundle.widgetTree, {'widget': 'Container'});
      expect(bundle.logs, hasLength(3));
      expect(bundle.metadata.reloadId, 5);
      expect(bundle.metadata.stabilityStatus, 'stable');
      expect(bundle.metadata.description, 'Test description');
    });

    test('throws on missing scene name', () {
      expect(
        () => ObservationBundleBuilder()
            .checkpoint('test')
            .device('device')
            .build(),
        throwsA(isA<ObservationBundleException>()),
      );
    });

    test('throws on missing checkpoint name', () {
      expect(
        () => ObservationBundleBuilder()
            .scene('test')
            .device('device')
            .build(),
        throwsA(isA<ObservationBundleException>()),
      );
    });

    test('throws on missing device ID', () {
      expect(
        () => ObservationBundleBuilder()
            .scene('test')
            .checkpoint('test')
            .build(),
        throwsA(isA<ObservationBundleException>()),
      );
    });
  });
}
