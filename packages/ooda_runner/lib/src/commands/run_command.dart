import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../adb/adb_client.dart';
import '../adb/device_manager.dart';
import '../barriers/app_ready_barrier.dart';
import '../barriers/device_ready_barrier.dart';
import '../daemon/vm_service_client.dart';
import '../observation/device_camera.dart';
import '../runner/flutter_session.dart';

/// Command to start and manage a Flutter run session.
class RunCommand extends Command<int> {
  RunCommand() {
    argParser.addOption(
      'project',
      abbr: 'p',
      help: 'Path to the Flutter project directory.',
      defaultsTo: '.',
    );
    argParser.addOption(
      'device',
      abbr: 'd',
      help: 'Device ID to run on. Auto-selects if not specified.',
    );
    argParser.addOption(
      'target',
      abbr: 't',
      help: 'Target file to run (defaults to lib/main.dart).',
    );
    argParser.addOption('flavor', help: 'Build flavor to use.');
    argParser.addFlag(
      'hot-reload',
      abbr: 'r',
      help: 'Trigger a hot reload after app starts.',
      defaultsTo: false,
    );
    argParser.addFlag(
      'screenshot',
      abbr: 's',
      help: 'Take a screenshot after app starts.',
      defaultsTo: false,
    );
    argParser.addOption(
      'screenshot-output',
      help: 'Output path for screenshot.',
      defaultsTo: 'screenshot.png',
    );
    argParser.addFlag(
      'widget-tree',
      abbr: 'w',
      help: 'Dump widget tree after app starts.',
      defaultsTo: false,
    );
    argParser.addFlag(
      'interactive',
      abbr: 'i',
      help: 'Keep session running for interactive commands.',
      defaultsTo: false,
    );
  }

  @override
  final String name = 'run';

  @override
  final String description =
      'Start a Flutter run session with OODA loop control.';

  @override
  Future<int> run() async {
    final projectPath = argResults!['project'] as String;
    final deviceId = argResults!['device'] as String?;
    final target = argResults!['target'] as String?;
    final flavor = argResults!['flavor'] as String?;
    final doHotReload = argResults!['hot-reload'] as bool;
    final doScreenshot = argResults!['screenshot'] as bool;
    final screenshotOutput = argResults!['screenshot-output'] as String;
    final dumpWidgetTree = argResults!['widget-tree'] as bool;
    final interactive = argResults!['interactive'] as bool;

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
      stderr.writeln('Start an emulator or connect a device first.');
      return 1;
    }

    // Wait for device to be ready
    stdout.write('Waiting for device to be ready...');
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

    // Start Flutter session
    stdout.writeln('Starting Flutter run session...');
    final config = FlutterSessionConfig(
      projectPath: projectPath,
      deviceId: selectedDeviceId,
      target: target,
      flavor: flavor,
    );

    FlutterSession session;
    try {
      session = await FlutterSession.start(config);
    } on FlutterSessionException catch (e) {
      stderr.writeln('Error: $e');
      return 1;
    }

    // Set up event logging
    final logSubscription = session.client.logs.listen((log) {
      if (log.error) {
        stderr.writeln('FLUTTER: ${log.message}');
      }
    });

    // Wait for app to be ready
    stdout.write('Waiting for app to start...');
    final appBarrier = AppReadyBarrier(session: session);
    final appResult = await appBarrier.wait();
    if (!appResult.success) {
      stdout.writeln(' FAILED');
      stderr.writeln(appResult.diagnosticInfo);
      await session.stop();
      return 1;
    }
    stdout.writeln(' OK');

    final appInfo = appResult.value!;
    stdout.writeln('App running: ${appInfo.appId}');

    // Perform hot reload if requested
    if (doHotReload) {
      stdout.write('Performing hot reload...');
      try {
        final reloadResult = await session.hotReload();
        final success = reloadResult['code'] == 0;
        stdout.writeln(success ? ' OK' : ' FAILED');
      } catch (e) {
        stdout.writeln(' ERROR: $e');
      }
    }

    // Connect to VM service if needed
    VmServiceClient? vmClient;
    if (dumpWidgetTree || doScreenshot) {
      if (appInfo.vmServiceUri != null) {
        stdout.write('Connecting to VM service...');
        try {
          vmClient = await VmServiceClient.connect(appInfo.vmServiceUri!);
          stdout.writeln(' OK');
        } catch (e) {
          stdout.writeln(' FAILED: $e');
        }
      }
    }

    // Take screenshot if requested
    if (doScreenshot) {
      stdout.write('Taking screenshots...');
      try {
        // Device screenshot
        final deviceCamera = DeviceCamera(adb: adb, deviceId: selectedDeviceId);
        await deviceCamera.captureToFile(
          screenshotOutput.replaceAll('.png', '_device.png'),
        );
        stdout.write(' device');

        // Flutter screenshot (if VM service available)
        if (vmClient != null) {
          try {
            final flutterBytes = await vmClient.takeScreenshot();
            final flutterFile = File(
              screenshotOutput.replaceAll('.png', '_flutter.png'),
            );
            await flutterFile.writeAsBytes(flutterBytes);
            stdout.write(', flutter');
          } catch (e) {
            stdout.write(' (flutter failed: $e)');
          }
        }

        stdout.writeln(' OK');
        stdout.writeln('Screenshots saved to: $screenshotOutput');
      } catch (e) {
        stdout.writeln(' ERROR: $e');
      }
    }

    // Dump widget tree if requested
    if (dumpWidgetTree && vmClient != null) {
      stdout.writeln('');
      stdout.writeln('Widget Tree:');
      stdout.writeln('-' * 60);
      try {
        final tree = await vmClient.getWidgetTree();
        _printWidgetTree(tree, 0);
      } catch (e) {
        stderr.writeln('Failed to get widget tree: $e');
      }
      stdout.writeln('-' * 60);
    }

    // Interactive mode
    if (interactive) {
      stdout.writeln('');
      stdout.writeln('Interactive mode. Commands:');
      stdout.writeln('  r - Hot reload');
      stdout.writeln('  R - Hot restart');
      stdout.writeln('  s - Take screenshot');
      stdout.writeln('  w - Dump widget tree');
      stdout.writeln('  q - Quit');
      stdout.writeln('');

      await _runInteractive(
        session: session,
        vmClient: vmClient,
        deviceCamera: DeviceCamera(adb: adb, deviceId: selectedDeviceId),
        screenshotOutput: screenshotOutput,
      );
    }

    // Cleanup
    await vmClient?.close();
    await logSubscription.cancel();
    await session.stop();

    stdout.writeln('Session ended.');
    return 0;
  }

  Future<void> _runInteractive({
    required FlutterSession session,
    VmServiceClient? vmClient,
    required DeviceCamera deviceCamera,
    required String screenshotOutput,
  }) async {
    stdin.echoMode = false;
    stdin.lineMode = false;

    try {
      await for (final bytes in stdin) {
        final char = String.fromCharCodes(bytes).trim();

        switch (char) {
          case 'r':
            stdout.write('Hot reload...');
            try {
              await session.hotReload();
              stdout.writeln(' OK');
            } catch (e) {
              stdout.writeln(' FAILED: $e');
            }
            break;

          case 'R':
            stdout.write('Hot restart...');
            try {
              await session.hotRestart();
              stdout.writeln(' OK');
            } catch (e) {
              stdout.writeln(' FAILED: $e');
            }
            break;

          case 's':
            stdout.write('Screenshot...');
            try {
              final timestamp = DateTime.now().millisecondsSinceEpoch;
              await deviceCamera.captureToFile('screenshot_$timestamp.png');
              stdout.writeln(' saved');
            } catch (e) {
              stdout.writeln(' FAILED: $e');
            }
            break;

          case 'w':
            if (vmClient != null) {
              try {
                final tree = await vmClient.getWidgetTree();
                stdout.writeln('');
                _printWidgetTree(tree, 0);
              } catch (e) {
                stdout.writeln('Failed: $e');
              }
            } else {
              stdout.writeln('VM service not available');
            }
            break;

          case 'q':
          case 'Q':
            return;
        }
      }
    } finally {
      stdin.echoMode = true;
      stdin.lineMode = true;
    }
  }

  void _printWidgetTree(Map<String, dynamic> node, int indent) {
    final description = node['description'] ?? node['widgetRuntimeType'] ?? '?';
    final prefix = '  ' * indent;

    stdout.writeln('$prefix$description');

    final children = node['children'] as List<dynamic>?;
    if (children != null) {
      for (final child in children) {
        if (child is Map<String, dynamic>) {
          _printWidgetTree(child, indent + 1);
        }
      }
    }
  }
}
