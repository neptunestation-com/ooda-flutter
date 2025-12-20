import 'package:ooda_shared/ooda_shared.dart';
import 'package:test/test.dart';

void main() {
  group('ObservationMetadata', () {
    final testTimestamp = DateTime.parse('2025-01-15T10:30:00Z');

    test('creates with required fields', () {
      final metadata = ObservationMetadata(
        sceneName: 'login_flow',
        checkpointName: 'initial',
        timestamp: testTimestamp,
        overlayPresent: false,
        deviceId: 'emulator-5554',
      );

      expect(metadata.sceneName, 'login_flow');
      expect(metadata.checkpointName, 'initial');
      expect(metadata.timestamp, testTimestamp);
      expect(metadata.overlayPresent, isFalse);
      expect(metadata.deviceId, 'emulator-5554');
      expect(metadata.schemaVersion, '1.0.0'); // default
      expect(metadata.stabilityStatus, 'unknown'); // default
    });

    test('creates with all fields', () {
      final metadata = ObservationMetadata(
        schemaVersion: '2.0.0',
        sceneName: 'onboarding',
        checkpointName: 'keyboard_up',
        timestamp: testTimestamp,
        overlayPresent: true,
        reloadId: 42,
        deviceId: 'emulator-5556',
        stabilityStatus: 'stable',
        description: 'Test checkpoint',
        extra: {'custom_field': 'value'},
      );

      expect(metadata.schemaVersion, '2.0.0');
      expect(metadata.reloadId, 42);
      expect(metadata.stabilityStatus, 'stable');
      expect(metadata.description, 'Test checkpoint');
      expect(metadata.extra, {'custom_field': 'value'});
    });

    test('serializes to JSON', () {
      final metadata = ObservationMetadata(
        sceneName: 'login_flow',
        checkpointName: 'after_submit',
        timestamp: testTimestamp,
        overlayPresent: true,
        reloadId: 5,
        deviceId: 'emulator-5554',
        stabilityStatus: 'stable',
        description: 'After form submission',
      );

      final json = metadata.toJson();

      expect(json['schema_version'], '1.0.0');
      expect(json['scene'], 'login_flow');
      expect(json['checkpoint'], 'after_submit');
      expect(json['timestamp'], '2025-01-15T10:30:00.000Z');
      expect(json['overlay_present'], isTrue);
      expect(json['reload_id'], 5);
      expect(json['device_id'], 'emulator-5554');
      expect(json['stability_status'], 'stable');
      expect(json['description'], 'After form submission');
    });

    test('JSON excludes null optional fields', () {
      final metadata = ObservationMetadata(
        sceneName: 'test',
        checkpointName: 'checkpoint',
        timestamp: testTimestamp,
        overlayPresent: false,
        deviceId: 'device-1',
      );

      final json = metadata.toJson();

      expect(json.containsKey('reload_id'), isFalse);
      expect(json.containsKey('description'), isFalse);
    });

    test('deserializes from JSON', () {
      final json = {
        'schema_version': '1.0.0',
        'scene': 'login_flow',
        'checkpoint': 'initial',
        'timestamp': '2025-01-15T10:30:00.000Z',
        'overlay_present': true,
        'reload_id': 10,
        'device_id': 'emulator-5554',
        'stability_status': 'stable',
        'description': 'Test',
      };

      final metadata = ObservationMetadata.fromJson(json);

      expect(metadata.sceneName, 'login_flow');
      expect(metadata.checkpointName, 'initial');
      expect(metadata.overlayPresent, isTrue);
      expect(metadata.reloadId, 10);
      expect(metadata.description, 'Test');
    });

    test('roundtrip JSON serialization', () {
      final original = ObservationMetadata(
        sceneName: 'test_scene',
        checkpointName: 'test_checkpoint',
        timestamp: testTimestamp,
        overlayPresent: true,
        reloadId: 42,
        deviceId: 'test-device',
        stabilityStatus: 'stable',
        description: 'Test description',
      );

      final json = original.toJson();
      final restored = ObservationMetadata.fromJson(json);

      expect(restored.sceneName, original.sceneName);
      expect(restored.checkpointName, original.checkpointName);
      expect(restored.overlayPresent, original.overlayPresent);
      expect(restored.reloadId, original.reloadId);
      expect(restored.deviceId, original.deviceId);
      expect(restored.description, original.description);
    });
  });
}
