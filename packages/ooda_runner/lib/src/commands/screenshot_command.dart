import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../adb/adb_client.dart';
import '../adb/device_manager.dart';
import '../barriers/device_ready_barrier.dart';
import '../observation/device_camera.dart';
import '../observation/image_utils.dart';

/// Command to capture a screenshot from a device.
class ScreenshotCommand extends Command<int> {
  ScreenshotCommand() {
    argParser.addOption(
      'device',
      abbr: 'd',
      help: 'Device ID to capture from. Auto-selects if not specified.',
    );
    argParser.addOption(
      'output',
      abbr: 'o',
      help: 'Output file path.',
      defaultsTo: 'screenshot.png',
    );
    argParser.addFlag(
      'wait-stable',
      abbr: 'w',
      help: 'Wait for the screen to become stable before capturing.',
      defaultsTo: false,
    );
    argParser.addOption(
      'timeout',
      abbr: 't',
      help: 'Timeout in seconds for stability wait.',
      defaultsTo: '5',
    );
    argParser.addFlag(
      'resize',
      abbr: 'r',
      help: 'Resize image to fit within max dimension (for AI API compatibility).',
      defaultsTo: true,
    );
    argParser.addOption(
      'max-dimension',
      abbr: 'm',
      help: 'Max dimension in pixels when resizing.',
      defaultsTo: '${ImageUtils.defaultMaxDimension}',
    );
  }

  @override
  final String name = 'screenshot';

  @override
  final String description = 'Capture a screenshot from an Android device.';

  @override
  Future<int> run() async {
    final deviceId = argResults!['device'] as String?;
    final outputPath = argResults!['output'] as String;
    final waitStable = argResults!['wait-stable'] as bool;
    final timeoutSeconds = int.parse(argResults!['timeout'] as String);
    final resize = argResults!['resize'] as bool;
    final maxDimension = int.parse(argResults!['max-dimension'] as String);

    final adb = AdbClient();
    final manager = DeviceManager(adbClient: adb);

    try {
      // Select device
      final device = deviceId != null
          ? await manager.selectDevice(deviceId)
          : await manager.autoSelectDevice();

      stdout.writeln('Using device: ${device.id}');

      // Wait for device to be ready
      final barrier = DeviceReadyBarrier(
        adb: adb,
        deviceId: device.id,
        timeout: Duration(seconds: timeoutSeconds),
      );

      stdout.write('Waiting for device to be ready...');
      final result = await barrier.wait();
      if (!result.success) {
        stdout.writeln(' FAILED');
        stderr.writeln(result.diagnosticInfo);
        return 1;
      }
      stdout.writeln(' OK');

      // Create camera
      final camera = DeviceCamera(adb: adb, deviceId: device.id);

      // Capture screenshot
      if (waitStable) {
        stdout.write('Waiting for screen stability...');
        final detector = VisualStabilityDetector(camera: camera);
        final stability = await detector.waitForStability(
          timeout: Duration(seconds: timeoutSeconds),
        );

        if (!stability.stable) {
          stdout.writeln(' TIMEOUT');
          stderr.writeln('Screen did not stabilize within timeout.');
        } else {
          stdout.writeln(' OK (${stability.framesChecked} frames)');
        }

        if (stability.screenshot != null) {
          var bytes = stability.screenshot!;
          if (resize) {
            final resized = ImageUtils.resizeToFit(
              bytes,
              maxDimension: maxDimension,
            );
            if (resized != null) bytes = resized;
          }
          final file = File(outputPath);
          await file.writeAsBytes(bytes);
          stdout.writeln('Screenshot saved: ${p.absolute(file.path)}');
        }
      } else {
        var bytes = await camera.capture();
        if (resize) {
          final resized = ImageUtils.resizeToFit(
            bytes,
            maxDimension: maxDimension,
          );
          if (resized != null) bytes = resized;
        }
        final file = File(outputPath);
        await file.writeAsBytes(bytes);
        stdout.writeln('Screenshot saved: ${p.absolute(file.path)}');
      }

      return 0;
    } on DeviceNotFoundException catch (e) {
      stderr.writeln('Error: $e');
      return 1;
    } on NoDevicesAvailableException catch (e) {
      stderr.writeln('Error: $e');
      return 1;
    } on AdbException catch (e) {
      stderr.writeln('Error: $e');
      return 1;
    }
  }
}
