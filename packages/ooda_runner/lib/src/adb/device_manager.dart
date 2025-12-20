import 'dart:async';

import 'package:ooda_shared/ooda_shared.dart';

import 'adb_client.dart';

/// Manages device discovery and selection.
class DeviceManager {
  DeviceManager({AdbClient? adbClient}) : _adb = adbClient ?? AdbClient();

  final AdbClient _adb;

  /// Currently selected device ID.
  String? _selectedDeviceId;

  /// Get the ADB client.
  AdbClient get adb => _adb;

  /// Get the currently selected device ID.
  String? get selectedDeviceId => _selectedDeviceId;

  /// List all connected devices.
  Future<List<AdbDevice>> listDevices() async {
    return _adb.devices();
  }

  /// List only ready devices (state == device).
  Future<List<AdbDevice>> listReadyDevices() async {
    final devices = await listDevices();
    return devices.where((d) => d.isReady).toList();
  }

  /// List only emulators.
  Future<List<AdbDevice>> listEmulators() async {
    final devices = await listDevices();
    return devices.where((d) => d.isEmulator).toList();
  }

  /// Select a device by ID.
  ///
  /// Throws if the device is not found or not ready.
  Future<AdbDevice> selectDevice(String deviceId) async {
    final devices = await listDevices();
    final device = devices.where((d) => d.id == deviceId).firstOrNull;

    if (device == null) {
      throw DeviceNotFoundException(deviceId);
    }

    if (!device.isReady) {
      throw DeviceNotReadyException(deviceId, device.state);
    }

    _selectedDeviceId = deviceId;
    return device;
  }

  /// Auto-select a device.
  ///
  /// Prefers emulators. If multiple devices, selects the first ready one.
  /// Throws if no devices are available.
  Future<AdbDevice> autoSelectDevice() async {
    final devices = await listReadyDevices();

    if (devices.isEmpty) {
      throw NoDevicesAvailableException();
    }

    // Prefer emulators
    final emulators = devices.where((d) => d.isEmulator).toList();
    final selected = emulators.isNotEmpty ? emulators.first : devices.first;

    _selectedDeviceId = selected.id;
    return selected;
  }

  /// Get the currently selected device.
  ///
  /// Throws if no device is selected.
  Future<AdbDevice> getSelectedDevice() async {
    if (_selectedDeviceId == null) {
      throw NoDeviceSelectedException();
    }

    return selectDevice(_selectedDeviceId!);
  }

  /// Check if the selected device is booted and ready.
  Future<bool> isSelectedDeviceReady() async {
    if (_selectedDeviceId == null) return false;
    return _adb.isBootComplete(_selectedDeviceId!);
  }

  /// Clear the device selection.
  void clearSelection() {
    _selectedDeviceId = null;
  }
}

/// Exception thrown when a device is not found.
class DeviceNotFoundException implements Exception {
  DeviceNotFoundException(this.deviceId);

  final String deviceId;

  @override
  String toString() => 'Device not found: $deviceId';
}

/// Exception thrown when a device is not ready.
class DeviceNotReadyException implements Exception {
  DeviceNotReadyException(this.deviceId, this.state);

  final String deviceId;
  final DeviceState state;

  @override
  String toString() =>
      'Device $deviceId is not ready (state: ${state.name})';
}

/// Exception thrown when no devices are available.
class NoDevicesAvailableException implements Exception {
  @override
  String toString() => 'No devices available. Start an emulator or connect a device.';
}

/// Exception thrown when no device is selected.
class NoDeviceSelectedException implements Exception {
  @override
  String toString() => 'No device selected. Call selectDevice() or autoSelectDevice() first.';
}
