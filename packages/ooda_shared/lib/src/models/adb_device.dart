import 'package:meta/meta.dart';

/// Represents the connection state of an ADB device.
enum DeviceState {
  /// Device is connected and ready.
  device,

  /// Device is offline or not responding.
  offline,

  /// Device is in unauthorized state (USB debugging not approved).
  unauthorized,

  /// Device is in bootloader mode.
  bootloader,

  /// Device is in recovery mode.
  recovery,

  /// Unknown state.
  unknown,
}

/// Represents an Android device connected via ADB.
@immutable
class AdbDevice {
  /// The device serial number or identifier (e.g., "emulator-5554").
  final String id;

  /// The connection state of the device.
  final DeviceState state;

  /// Optional product name.
  final String? product;

  /// Optional device model.
  final String? model;

  /// Optional transport ID.
  final String? transportId;

  const AdbDevice({
    required this.id,
    required this.state,
    this.product,
    this.model,
    this.transportId,
  });

  /// Whether the device is ready for use.
  bool get isReady => state == DeviceState.device;

  /// Whether this is an emulator.
  bool get isEmulator => id.startsWith('emulator-');

  @override
  String toString() => 'AdbDevice(id: $id, state: $state, model: $model)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdbDevice && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  /// Parse device state from ADB output string.
  static DeviceState parseState(String state) {
    return switch (state.toLowerCase()) {
      'device' => DeviceState.device,
      'offline' => DeviceState.offline,
      'unauthorized' => DeviceState.unauthorized,
      'bootloader' => DeviceState.bootloader,
      'recovery' => DeviceState.recovery,
      _ => DeviceState.unknown,
    };
  }
}
