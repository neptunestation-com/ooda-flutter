import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../adb/adb_client.dart';
import '../adb/device_manager.dart';
import '../barriers/app_ready_barrier.dart';
import '../barriers/device_ready_barrier.dart';
import '../barriers/visual_stability_barrier.dart';
import '../daemon/vm_service_client.dart';
import '../observation/device_camera.dart';
import '../observation/flutter_camera.dart';
import '../observation/observation_bundle.dart';
import '../runner/flutter_session.dart';

/// Command to capture an observation bundle.
class ObserveCommand extends Command<int> {
  ObserveCommand() {
    argParser.addOption(
      'project',
      abbr: 'p',
      help: 'Path to the Flutter project directory.',
      defaultsTo: '.',
    );
    argParser.addOption(
      'device',
      abbr: 'd',
      help: 'Device ID. Auto-selects if not specified.',
    );
    argParser.addOption(
      'scene',
      abbr: 's',
      help: 'Scene name for the observation.',
      defaultsTo: 'manual',
    );
    argParser.addOption(
      'checkpoint',
      abbr: 'c',
      help: 'Checkpoint name for the observation.',
      defaultsTo: 'observation',
    );
    argParser.addOption(
      'output',
      abbr: 'o',
      help: 'Output directory for the observation bundle.',
      defaultsTo: 'obs',
    );
    argParser.addFlag(
      'wait-stable',
      abbr: 'w',
      help: 'Wait for visual stability before capturing.',
      defaultsTo: true,
    );
    argParser.addOption(
      'timeout',
      abbr: 't',
      help: 'Timeout in seconds for stability wait.',
      defaultsTo: '5',
    );
    argParser.addFlag(
      'start-app',
      help: 'Start the Flutter app if not running.',
      defaultsTo: false,
    );
    argParser.addFlag(
      'widget-tree',
      help: 'Capture widget tree.',
      defaultsTo: true,
    );
    argParser.addFlag(
      'semantics',
      help: 'Capture semantics tree.',
      defaultsTo: true,
    );
    argParser.addFlag('logs', help: 'Capture device logs.', defaultsTo: true);
  }

  @override
  final String name = 'observe';

  @override
  final String description =
      'Capture an observation bundle from a running Flutter app.';

  @override
  Future<int> run() async {
    final projectPath = argResults!['project'] as String;
    final deviceId = argResults!['device'] as String?;
    final sceneName = argResults!['scene'] as String;
    final checkpointName = argResults!['checkpoint'] as String;
    final outputPath = argResults!['output'] as String;
    final waitStable = argResults!['wait-stable'] as bool;
    final timeoutSeconds = int.parse(argResults!['timeout'] as String);
    final startApp = argResults!['start-app'] as bool;
    final captureWidgetTree = argResults!['widget-tree'] as bool;
    final captureSemantics = argResults!['semantics'] as bool;
    final captureLogs = argResults!['logs'] as bool;

    final adb = AdbClient();
    final deviceManager = DeviceManager(adbClient: adb);

    // Select device
    String selectedDeviceId;
    try {
      if (deviceId != null) {
        await deviceManager.selectDevice(deviceId);
        selectedDeviceId = deviceId;
      } else {
        final device = await deviceManager.autoSelectDevice();
        selectedDeviceId = device.id;
      }
      stdout.writeln('Using device: $selectedDeviceId');
    } on NoDevicesAvailableException {
      stderr.writeln('Error: No devices available.');
      return 1;
    }

    // Wait for device ready
    stdout.write('Waiting for device...');
    final deviceBarrier = DeviceReadyBarrier(
      adb: adb,
      deviceId: selectedDeviceId,
    );
    final deviceResult = await deviceBarrier.wait();
    if (!deviceResult.success) {
      stdout.writeln(' FAILED');
      stderr.writeln(deviceResult.diagnosticInfo);
      return 1;
    }
    stdout.writeln(' OK');

    FlutterSession? session;
    VmServiceClient? vmClient;

    try {
      // Start app if requested
      if (startApp) {
        stdout.writeln('Starting Flutter app...');
        final config = FlutterSessionConfig(
          projectPath: projectPath,
          deviceId: selectedDeviceId,
        );
        session = await FlutterSession.start(config);

        stdout.write('Waiting for app...');
        final appBarrier = AppReadyBarrier(session: session);
        final appResult = await appBarrier.wait();
        if (!appResult.success) {
          stdout.writeln(' FAILED');
          stderr.writeln(appResult.diagnosticInfo);
          return 1;
        }
        stdout.writeln(' OK');

        // Connect to VM service
        if (session.appInfo?.vmServiceUri != null) {
          stdout.write('Connecting to VM service...');
          try {
            vmClient = await VmServiceClient.connect(
              session.appInfo!.vmServiceUri!,
            );
            stdout.writeln(' OK');
          } catch (e) {
            stdout.writeln(' FAILED: $e');
          }
        }
      }

      // Create cameras
      final deviceCamera = DeviceCamera(adb: adb, deviceId: selectedDeviceId);
      FlutterCamera? flutterCamera;
      if (vmClient != null) {
        flutterCamera = FlutterCamera(vmService: vmClient);
      }

      // Build observation
      final builder = ObservationBundleBuilder()
          .scene(sceneName)
          .checkpoint(checkpointName)
          .device(selectedDeviceId);

      if (session != null) {
        builder.reload(session.reloadCount);
      }

      // Wait for stability if requested
      if (waitStable) {
        stdout.write('Waiting for visual stability...');
        final stabilityBarrier = VisualStabilityBarrier(
          camera: deviceCamera,
          timeout: Duration(seconds: timeoutSeconds),
        );
        final stabilityResult = await stabilityBarrier.wait();

        if (stabilityResult.success && stabilityResult.value != null) {
          stdout.writeln(
            ' OK (${stabilityResult.value!.framesChecked} frames)',
          );
          builder
              .deviceScreenshot(stabilityResult.value!.screenshot!)
              .stability('stable');
        } else {
          stdout.writeln(' TIMEOUT');
          builder.stability('unstable');
          // Still capture current screenshot
          try {
            final screenshot = await deviceCamera.capture();
            builder.deviceScreenshot(screenshot);
          } catch (e) {
            stderr.writeln('Failed to capture device screenshot: $e');
          }
        }
      } else {
        // Capture immediately
        stdout.write('Capturing device screenshot...');
        try {
          final screenshot = await deviceCamera.capture();
          builder.deviceScreenshot(screenshot);
          stdout.writeln(' OK');
        } catch (e) {
          stdout.writeln(' FAILED: $e');
        }
      }

      // Capture Flutter screenshot
      if (flutterCamera != null) {
        stdout.write('Capturing Flutter screenshot...');
        try {
          final screenshot = await flutterCamera.captureScreenshot();
          builder.flutterScreenshot(screenshot);
          stdout.writeln(' OK');
        } catch (e) {
          stdout.writeln(' FAILED: $e');
        }
      }

      // Capture widget tree
      if (captureWidgetTree && flutterCamera != null) {
        stdout.write('Capturing widget tree...');
        try {
          final tree = await flutterCamera.getWidgetTree();
          builder.widgetTree(tree);
          stdout.writeln(' OK');
        } catch (e) {
          stdout.writeln(' FAILED: $e');
        }
      }

      // Capture semantics tree
      if (captureSemantics && flutterCamera != null) {
        stdout.write('Capturing semantics tree...');
        try {
          final tree = await flutterCamera.getSemanticsTree();
          builder.semanticsTree(tree);
          stdout.writeln(' OK');
        } catch (e) {
          stdout.writeln(' FAILED: $e');
        }
      }

      // Capture logs
      if (captureLogs) {
        stdout.write('Capturing logs...');
        try {
          final logcat = await adb.logcat(selectedDeviceId, lines: 100);
          builder.addLogs(logcat.split('\n'));
          stdout.writeln(' OK');
        } catch (e) {
          stdout.writeln(' FAILED: $e');
        }
      }

      // Build and save bundle
      final bundle = builder.build();

      stdout.write('Saving observation bundle...');
      final outputDir = Directory(outputPath);
      final bundleDir = await bundle.write(outputDir);
      stdout.writeln(' OK');

      // Print summary
      stdout.writeln('');
      stdout.writeln('Observation Bundle Summary:');
      stdout.writeln('-' * 40);
      stdout.writeln('Scene: $sceneName');
      stdout.writeln('Checkpoint: $checkpointName');
      stdout.writeln('Overlay present: ${bundle.overlayPresent}');
      stdout.writeln('Path: ${bundleDir.path}');
      stdout.writeln('');

      // List files
      stdout.writeln('Files:');
      await for (final entity in bundleDir.list()) {
        if (entity is File) {
          final size = await entity.length();
          final name = p.basename(entity.path);
          stdout.writeln('  $name (${_formatSize(size)})');
        }
      }

      return 0;
    } finally {
      await vmClient?.close();
      await session?.stop();
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}
