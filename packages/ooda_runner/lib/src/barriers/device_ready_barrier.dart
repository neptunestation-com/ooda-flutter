import 'dart:async';

import 'package:ooda_shared/ooda_shared.dart';

import '../adb/adb_client.dart';
import 'barrier.dart';

/// Barrier that waits for an Android device to be fully booted.
///
/// Checks `sys.boot_completed` property via ADB.
class DeviceReadyBarrier extends PollingBarrier<bool> {
  @override
  final String name = 'DeviceReady';

  final AdbClient _adb;
  final String _deviceId;

  DeviceReadyBarrier({
    required AdbClient adb,
    required String deviceId,
    super.timeout = const Duration(seconds: 60),
    super.pollingInterval = const Duration(seconds: 1),
  })  : _adb = adb,
        _deviceId = deviceId;

  @override
  Future<bool> check() async {
    return _adb.isBootComplete(_deviceId);
  }

  @override
  Future<bool?> getValue() async => true;

  @override
  Future<String> collectDiagnostics() async {
    final buffer = StringBuffer();
    buffer.writeln('Device Ready Barrier Timeout Diagnostics');
    buffer.writeln('Device ID: $_deviceId');
    buffer.writeln('');

    try {
      // Check device state
      final devices = await _adb.devices();
      final device = devices.where((d) => d.id == _deviceId).firstOrNull;

      if (device == null) {
        buffer.writeln('Device not found in ADB devices list.');
        buffer.writeln('Available devices:');
        for (final d in devices) {
          buffer.writeln('  - ${d.id} (${d.state.name})');
        }
      } else {
        buffer.writeln('Device state: ${device.state.name}');
        buffer.writeln('Is emulator: ${device.isEmulator}');
        buffer.writeln('Model: ${device.model ?? "unknown"}');

        if (device.isReady) {
          // Device is connected but boot not complete
          try {
            final bootCompleted =
                await _adb.shell(_deviceId, 'getprop sys.boot_completed');
            buffer.writeln('sys.boot_completed: ${bootCompleted.trim()}');

            final bootAnim =
                await _adb.shell(_deviceId, 'getprop init.svc.bootanim');
            buffer.writeln('init.svc.bootanim: ${bootAnim.trim()}');

            final uptime = await _adb.shell(_deviceId, 'uptime');
            buffer.writeln('Uptime: ${uptime.trim()}');
          } catch (e) {
            buffer.writeln('Failed to query device properties: $e');
          }
        }
      }
    } catch (e) {
      buffer.writeln('Failed to collect diagnostics: $e');
    }

    return buffer.toString();
  }
}

/// Barrier that waits for the device to be connected via ADB.
class DeviceConnectedBarrier extends PollingBarrier<AdbDevice> {
  @override
  final String name = 'DeviceConnected';

  final AdbClient _adb;
  final String _deviceId;
  AdbDevice? _device;

  DeviceConnectedBarrier({
    required AdbClient adb,
    required String deviceId,
    super.timeout = const Duration(seconds: 30),
    super.pollingInterval = const Duration(seconds: 1),
  })  : _adb = adb,
        _deviceId = deviceId;

  @override
  Future<bool> check() async {
    final devices = await _adb.devices();
    _device = devices.where((d) => d.id == _deviceId && d.isReady).firstOrNull;
    return _device != null;
  }

  @override
  Future<AdbDevice?> getValue() async => _device;

  @override
  Future<String> collectDiagnostics() async {
    final buffer = StringBuffer();
    buffer.writeln('Device Connected Barrier Timeout Diagnostics');
    buffer.writeln('Expected device ID: $_deviceId');
    buffer.writeln('');

    try {
      final devices = await _adb.devices();
      if (devices.isEmpty) {
        buffer.writeln('No devices connected.');
        buffer.writeln('');
        buffer.writeln('Troubleshooting:');
        buffer.writeln('  1. Start an emulator: emulator -avd <avd_name>');
        buffer.writeln('  2. Or connect a physical device with USB debugging enabled');
        buffer.writeln('  3. Run "adb devices" to verify connection');
      } else {
        buffer.writeln('Connected devices:');
        for (final d in devices) {
          buffer.writeln('  - ${d.id}');
          buffer.writeln('    State: ${d.state.name}');
          buffer.writeln('    Model: ${d.model ?? "unknown"}');
          buffer.writeln('    Ready: ${d.isReady}');
        }
      }
    } catch (e) {
      buffer.writeln('Failed to list devices: $e');
    }

    return buffer.toString();
  }
}
