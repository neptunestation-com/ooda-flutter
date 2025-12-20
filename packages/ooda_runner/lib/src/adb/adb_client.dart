import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ooda_shared/ooda_shared.dart';

/// Exception thrown when an ADB command fails.
class AdbException implements Exception {
  AdbException(this.message, {this.exitCode, this.stderr});

  final String message;
  final int? exitCode;
  final String? stderr;

  @override
  String toString() {
    final buffer = StringBuffer('AdbException: $message');
    if (exitCode != null) buffer.write(' (exit code: $exitCode)');
    if (stderr != null && stderr!.isNotEmpty) buffer.write('\n$stderr');
    return buffer.toString();
  }
}

/// Client for communicating with Android devices via ADB.
class AdbClient {
  AdbClient({
    this.adbPath = 'adb',
    this.defaultTimeout = const Duration(seconds: 30),
  });

  /// Path to the ADB executable.
  final String adbPath;

  /// Default timeout for ADB commands.
  final Duration defaultTimeout;

  /// List all connected devices.
  Future<List<AdbDevice>> devices() async {
    final result = await _run(['devices', '-l']);
    final lines = result.stdout.toString().split('\n');

    final devices = <AdbDevice>[];
    for (final line in lines.skip(1)) {
      // Skip header
      if (line.trim().isEmpty) continue;

      final device = _parseDeviceLine(line);
      if (device != null) {
        devices.add(device);
      }
    }

    return devices;
  }

  /// Check if a device is fully booted.
  Future<bool> isBootComplete(String deviceId) async {
    try {
      final result = await shell(deviceId, 'getprop sys.boot_completed');
      return result.trim() == '1';
    } catch (_) {
      return false;
    }
  }

  /// Take a screenshot from the device framebuffer.
  ///
  /// Returns raw PNG bytes.
  Future<Uint8List> screenshot(String deviceId) async {
    final result = await _run([
      '-s',
      deviceId,
      'exec-out',
      'screencap',
      '-p',
    ], binary: true);

    if (result.exitCode != 0) {
      throw AdbException(
        'Failed to capture screenshot',
        exitCode: result.exitCode,
        stderr: result.stderr.toString(),
      );
    }

    return result.stdout as Uint8List;
  }

  /// Execute a shell command on the device.
  Future<String> shell(String deviceId, String command) async {
    final result = await _run(['-s', deviceId, 'shell', command]);
    return result.stdout.toString();
  }

  /// Send a tap event at the specified coordinates.
  Future<void> tap(String deviceId, int x, int y) async {
    await shell(deviceId, 'input tap $x $y');
  }

  /// Input text on the device.
  ///
  /// Note: Special characters may not work as expected.
  /// Consider using key events for special chars.
  Future<void> inputText(String deviceId, String text) async {
    // Escape special characters for shell
    final escaped = text
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll("'", "\\'")
        .replaceAll(' ', '%s')
        .replaceAll('&', '\\&')
        .replaceAll('<', '\\<')
        .replaceAll('>', '\\>')
        .replaceAll('|', '\\|')
        .replaceAll(';', '\\;');

    await shell(deviceId, 'input text "$escaped"');
  }

  /// Send a key event.
  ///
  /// Common key codes:
  /// - KEYCODE_BACK = 4
  /// - KEYCODE_ENTER = 66
  /// - KEYCODE_HOME = 3
  /// - KEYCODE_TAB = 61
  Future<void> keyEvent(String deviceId, int keyCode) async {
    await shell(deviceId, 'input keyevent $keyCode');
  }

  /// Perform a swipe gesture.
  Future<void> swipe(
    String deviceId, {
    required int startX,
    required int startY,
    required int endX,
    required int endY,
    int durationMs = 300,
  }) async {
    await shell(
      deviceId,
      'input swipe $startX $startY $endX $endY $durationMs',
    );
  }

  /// Get the foreground activity.
  Future<String?> foregroundActivity(String deviceId) async {
    final result = await shell(
      deviceId,
      'dumpsys activity activities | grep mResumedActivity',
    );
    final match = RegExp(r'(\S+/\S+)').firstMatch(result);
    return match?.group(1);
  }

  /// Get recent logcat output.
  Future<String> logcat(String deviceId, {int lines = 100, String? tag}) async {
    final tagFilter = tag != null ? '-s $tag' : '';
    return await shell(deviceId, 'logcat -d -t $lines $tagFilter');
  }

  /// Clear logcat buffer.
  Future<void> clearLogcat(String deviceId) async {
    await shell(deviceId, 'logcat -c');
  }

  /// Check if a specific package is installed.
  Future<bool> isPackageInstalled(String deviceId, String packageName) async {
    final result = await shell(deviceId, 'pm list packages $packageName');
    return result.contains('package:$packageName');
  }

  /// Get device screen resolution.
  Future<({int width, int height})> screenResolution(String deviceId) async {
    final result = await shell(deviceId, 'wm size');
    final match = RegExp(r'(\d+)x(\d+)').firstMatch(result);
    if (match == null) {
      throw AdbException('Failed to parse screen resolution: $result');
    }
    return (
      width: int.parse(match.group(1)!),
      height: int.parse(match.group(2)!),
    );
  }

  /// Wait for a device to be connected and ready.
  Future<void> waitForDevice(
    String deviceId, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    await _run(['-s', deviceId, 'wait-for-device'], timeout: timeout);
  }

  /// Run an ADB command and return the result.
  Future<ProcessResult> _run(
    List<String> args, {
    Duration? timeout,
    bool binary = false,
  }) async {
    final effectiveTimeout = timeout ?? defaultTimeout;

    try {
      final process = await Process.start(
        adbPath,
        args,
        mode: binary ? ProcessStartMode.normal : ProcessStartMode.normal,
      );

      final stdout = <int>[];
      final stderr = <int>[];

      final stdoutFuture = process.stdout.forEach(stdout.addAll);
      final stderrFuture = process.stderr.forEach(stderr.addAll);

      final exitCode = await process.exitCode.timeout(effectiveTimeout);
      await Future.wait([stdoutFuture, stderrFuture]);

      return ProcessResult(
        process.pid,
        exitCode,
        binary ? Uint8List.fromList(stdout) : utf8.decode(stdout),
        utf8.decode(stderr),
      );
    } on TimeoutException {
      throw AdbException('ADB command timed out after $effectiveTimeout');
    }
  }

  /// Parse a line from `adb devices -l` output.
  AdbDevice? _parseDeviceLine(String line) {
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return null;

    final id = parts[0];
    final state = AdbDevice.parseState(parts[1]);

    String? product;
    String? model;
    String? transportId;

    for (final part in parts.skip(2)) {
      if (part.startsWith('product:')) {
        product = part.substring('product:'.length);
      } else if (part.startsWith('model:')) {
        model = part.substring('model:'.length);
      } else if (part.startsWith('transport_id:')) {
        transportId = part.substring('transport_id:'.length);
      }
    }

    return AdbDevice(
      id: id,
      state: state,
      product: product,
      model: model,
      transportId: transportId,
    );
  }
}
