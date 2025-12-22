import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:ooda_shared/ooda_shared.dart';
import 'package:path/path.dart' as p;

import '../adb/adb_client.dart';
import '../adb/device_manager.dart';
import '../barriers/app_ready_barrier.dart';
import '../barriers/device_ready_barrier.dart';
import '../runner/flutter_session.dart';
import '../scenes/scene_executor.dart';
import '../scenes/scene_parser.dart';

/// Command to execute a scene from a YAML file.
class SceneCommand extends Command<int> {
  SceneCommand() {
    argParser.addOption(
      'scene',
      abbr: 's',
      help: 'Path to the scene YAML file.',
      mandatory: true,
    );
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
      'output',
      abbr: 'o',
      help: 'Output directory for observation bundles.',
      defaultsTo: 'obs',
    );
    argParser.addFlag(
      'verbose',
      abbr: 'v',
      help: 'Show detailed execution logs.',
      defaultsTo: false,
    );
    argParser.addFlag(
      'keep-running',
      help: 'Keep the app running after scene execution.',
      defaultsTo: false,
    );
  }

  @override
  final String name = 'scene';

  @override
  final String description =
      'Execute a scene from a YAML file and capture observations.';

  @override
  Future<int> run() async {
    final sceneFile = File(argResults!['scene'] as String);
    final projectPath = argResults!['project'] as String;
    final deviceId = argResults!['device'] as String?;
    final outputPath = argResults!['output'] as String;
    final verbose = argResults!['verbose'] as bool;
    final keepRunning = argResults!['keep-running'] as bool;

    // Validate scene file
    if (!await sceneFile.exists()) {
      stderr.writeln('Error: Scene file not found: ${sceneFile.path}');
      return 1;
    }

    // Parse scene
    stdout.write('Parsing scene file...');
    final scene = await SceneParser.parseFile(sceneFile);
    stdout.writeln(' OK');
    stdout.writeln('Scene: ${scene.name}');
    if (scene.description != null) {
      stdout.writeln('Description: ${scene.description}');
    }
    stdout.writeln('Steps: ${scene.steps.length}');
    stdout.writeln('Checkpoints: ${scene.checkpoints.length}');
    stdout.writeln('');

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

    // Start Flutter session
    stdout.writeln('Starting Flutter app...');
    final config = FlutterSessionConfig(
      projectPath: projectPath,
      deviceId: selectedDeviceId,
    );

    FlutterSession? session;
    SceneExecutor? executor;

    try {
      session = await FlutterSession.start(config);

      // Wait for app ready
      stdout.write('Waiting for app...');
      final appBarrier = AppReadyBarrier(session: session);
      final appResult = await appBarrier.wait();
      if (!appResult.success) {
        stdout.writeln(' FAILED');
        stderr.writeln(appResult.diagnosticInfo);
        return 1;
      }
      stdout.writeln(' OK');

      // Create executor
      final outputDir = Directory(outputPath);
      await outputDir.create(recursive: true);

      executor = SceneExecutor(
        session: session,
        adb: adb,
        deviceId: selectedDeviceId,
        outputDir: outputDir,
      );

      // Subscribe to events early so we can capture VM service diagnostics
      late StreamSubscription<SceneEvent> eventSubscription;
      eventSubscription = executor.events.listen((event) {
        _handleEvent(event, verbose);
      });

      // Connect to VM service
      stdout.write('Connecting to VM service...');
      try {
        await executor.connectVmService();
        stdout.writeln(' OK');
      } catch (e) {
        stdout.writeln(' FAILED (continuing without Flutter camera)');
        if (verbose) {
          stderr.writeln('  $e');
        }
      }

      // Execute scene
      stdout.writeln('');
      stdout.writeln('Executing scene: ${scene.name}');
      stdout.writeln('=' * 60);

      final result = await executor.execute(scene);

      stdout.writeln('=' * 60);
      stdout.writeln('');

      // Print summary
      stdout.writeln('Scene Execution Summary:');
      stdout.writeln('-' * 40);
      stdout.writeln('Scene: ${result.sceneName}');
      stdout.writeln('Success: ${result.success}');
      stdout.writeln('Elapsed: ${result.elapsed.inSeconds}s');
      stdout.writeln('Observations: ${result.observations.length}');
      stdout.writeln('Errors: ${result.errors.length}');
      stdout.writeln('');

      if (result.observations.isNotEmpty) {
        stdout.writeln('Captured checkpoints:');
        for (final obs in result.observations) {
          stdout.writeln('  - ${obs.checkpointName}');
          stdout.writeln('    Overlay: ${obs.overlayPresent}');
          stdout.writeln(
            '    Path: ${p.join(outputPath, obs.sceneName, obs.checkpointName)}',
          );
        }
        stdout.writeln('');
      }

      if (result.errors.isNotEmpty) {
        stdout.writeln('Errors:');
        for (final error in result.errors) {
          stdout.writeln('  Step ${error.step}: ${error.message}');
        }
        stdout.writeln('');
      }

      await eventSubscription.cancel();

      // Keep running if requested
      if (keepRunning && result.success) {
        stdout.writeln('App is still running. Press Ctrl+C to stop.');
        await ProcessSignal.sigint.watch().first;
      }

      return result.success ? 0 : 1;
    } finally {
      await executor?.close();
      if (!keepRunning) {
        await session?.stop();
      }
    }
  }

  void _handleEvent(SceneEvent event, bool verbose) {
    switch (event) {
      case SceneStartedEvent(:final sceneName):
        if (verbose) stdout.writeln('[START] Scene: $sceneName');

      case SceneCompletedEvent(:final observationCount):
        stdout.writeln(
          '[DONE] Scene completed with $observationCount observations',
        );

      case SceneFailedEvent(:final error):
        stderr.writeln('[FAILED] Scene failed: $error');

      case SetupStartedEvent():
        if (verbose) stdout.writeln('[SETUP] Starting setup...');

      case SetupCompletedEvent():
        if (verbose) stdout.writeln('[SETUP] Setup complete');

      case StepStartedEvent(:final stepIndex, :final step):
        final desc = _stepDescription(step);
        stdout.write('  [$stepIndex] $desc...');

      case StepCompletedEvent():
        stdout.writeln(' OK');

      case StepFailedEvent(:final error):
        stdout.writeln(' FAILED');
        stderr.writeln('      Error: $error');

      case SceneCheckpointEvent(:final checkpointName, :final bundle):
        if (verbose) {
          stdout.writeln('      Checkpoint captured: $checkpointName');
          stdout.writeln('      Overlay: ${bundle.overlayPresent}');
        }

      case InteractionCompletedEvent(:final interaction):
        if (verbose) stdout.writeln('      Interaction: $interaction');

      case SceneLogEvent(:final message, :final severity):
        if (verbose || severity == RunnerEventSeverity.error) {
          final prefix = severity == RunnerEventSeverity.error
              ? 'ERROR'
              : 'LOG';
          stdout.writeln('      [$prefix] $message');
        }
    }
  }

  String _stepDescription(SceneStep step) {
    return switch (step) {
      CheckpointStep(:final checkpoint) => 'Checkpoint: ${checkpoint.name}',
      InteractionStep(:final interaction) => _interactionDescription(
        interaction,
      ),
    };
  }

  String _interactionDescription(Interaction interaction) {
    return switch (interaction) {
      TapInteraction(:final x, :final y) => 'Tap($x, $y)',
      TapByLabelInteraction(:final label) => 'TapLabel: "$label"',
      TextInputInteraction(:final text) =>
        'Input: "${text.length > 20 ? '${text.substring(0, 20)}...' : text}"',
      KeyEventInteraction(:final keyCode) => 'Key: $keyCode',
      SwipeInteraction() => 'Swipe',
      WaitInteraction(:final barrierType) => 'Wait: $barrierType',
    };
  }
}
