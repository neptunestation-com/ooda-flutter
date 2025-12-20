import 'package:ooda_shared/ooda_shared.dart';
import 'package:test/test.dart';

void main() {
  group('AdbDevice', () {
    test('creates device with required fields', () {
      const device = AdbDevice(
        id: 'emulator-5554',
        state: DeviceState.device,
      );

      expect(device.id, 'emulator-5554');
      expect(device.state, DeviceState.device);
      expect(device.product, isNull);
      expect(device.model, isNull);
    });

    test('creates device with all fields', () {
      const device = AdbDevice(
        id: 'emulator-5554',
        state: DeviceState.device,
        product: 'sdk_gphone64_x86_64',
        model: 'sdk_gphone64_x86_64',
        transportId: '1',
      );

      expect(device.product, 'sdk_gphone64_x86_64');
      expect(device.model, 'sdk_gphone64_x86_64');
      expect(device.transportId, '1');
    });

    test('isReady returns true for device state', () {
      const device = AdbDevice(id: 'test', state: DeviceState.device);
      expect(device.isReady, isTrue);
    });

    test('isReady returns false for offline state', () {
      const device = AdbDevice(id: 'test', state: DeviceState.offline);
      expect(device.isReady, isFalse);
    });

    test('isReady returns false for unauthorized state', () {
      const device = AdbDevice(id: 'test', state: DeviceState.unauthorized);
      expect(device.isReady, isFalse);
    });

    test('isEmulator returns true for emulator ID', () {
      const device = AdbDevice(id: 'emulator-5554', state: DeviceState.device);
      expect(device.isEmulator, isTrue);
    });

    test('isEmulator returns false for physical device ID', () {
      const device = AdbDevice(id: 'ABC123DEF456', state: DeviceState.device);
      expect(device.isEmulator, isFalse);
    });

    group('parseState', () {
      test('parses device state', () {
        expect(AdbDevice.parseState('device'), DeviceState.device);
      });

      test('parses offline state', () {
        expect(AdbDevice.parseState('offline'), DeviceState.offline);
      });

      test('parses unauthorized state', () {
        expect(AdbDevice.parseState('unauthorized'), DeviceState.unauthorized);
      });

      test('parses bootloader state', () {
        expect(AdbDevice.parseState('bootloader'), DeviceState.bootloader);
      });

      test('parses recovery state', () {
        expect(AdbDevice.parseState('recovery'), DeviceState.recovery);
      });

      test('parses unknown state', () {
        expect(AdbDevice.parseState('something'), DeviceState.unknown);
      });

      test('is case insensitive', () {
        expect(AdbDevice.parseState('DEVICE'), DeviceState.device);
        expect(AdbDevice.parseState('Device'), DeviceState.device);
      });
    });

    test('equality based on id', () {
      const device1 = AdbDevice(id: 'emulator-5554', state: DeviceState.device);
      const device2 = AdbDevice(
        id: 'emulator-5554',
        state: DeviceState.offline,
        model: 'test',
      );
      const device3 = AdbDevice(id: 'emulator-5556', state: DeviceState.device);

      expect(device1, equals(device2));
      expect(device1, isNot(equals(device3)));
    });

    test('hashCode based on id', () {
      const device1 = AdbDevice(id: 'emulator-5554', state: DeviceState.device);
      const device2 = AdbDevice(id: 'emulator-5554', state: DeviceState.offline);

      expect(device1.hashCode, equals(device2.hashCode));
    });
  });
}
