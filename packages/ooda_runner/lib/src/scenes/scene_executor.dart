import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:ooda_shared/ooda_shared.dart';

import '../adb/adb_client.dart';
import '../barriers/app_ready_barrier.dart';
import '../barriers/visual_stability_barrier.dart';
import '../daemon/vm_service_client.dart';
import '../interaction/interaction_controller.dart';
import '../observation/device_camera.dart';
import '../observation/flutter_camera.dart';
import '../observation/image_utils.dart';
import '../observation/observation_bundle.dart';
import '../runner/flutter_session.dart';

/// Executes scenes and captures observations at checkpoints.
class SceneExecutor {
  SceneExecutor({
    required this.session,
    required this.adb,
    required this.deviceId,
    required this.outputDir,
    this.resizeScreenshots = true,
    this.maxScreenshotDimension = ImageUtils.defaultMaxDimension,
  }) {
    _interactionController = InteractionController(
      adb: adb,
      deviceId: deviceId,
    );
    _deviceCamera = DeviceCamera(adb: adb, deviceId: deviceId);
  }

  final FlutterSession session;
  final AdbClient adb;
  final String deviceId;
  final Directory outputDir;

  /// Whether to resize screenshots for AI API compatibility.
  final bool resizeScreenshots;

  /// Maximum dimension for resized screenshots.
  final int maxScreenshotDimension;

  late final InteractionController _interactionController;
  late final DeviceCamera _deviceCamera;
  FlutterCamera? _flutterCamera;
  VmServiceClient? _vmClient;

  final _eventController = StreamController<SceneEvent>.broadcast();

  /// Stream of execution events.
  Stream<SceneEvent> get events => _eventController.stream;

  /// Connect to VM service for Flutter camera.
  Future<void> connectVmService() async {
    if (session.appInfo?.vmServiceUri != null && _vmClient == null) {
      _vmClient = await VmServiceClient.connect(session.appInfo!.vmServiceUri!);
      _flutterCamera = FlutterCamera(vmService: _vmClient!);

      // Log available extensions for diagnostics
      try {
        final extensions = await _vmClient!.listExtensions();
        _emit(SceneLogEvent(
          message: 'Available VM extensions: ${extensions.length}',
        ));
        // Log Flutter-specific extensions
        final flutterExtensions = extensions.where((e) => e.contains('flutter')).toList();
        if (flutterExtensions.isEmpty) {
          _emit(const SceneLogEvent(
            message: 'Warning: No Flutter extensions found - Flutter camera features will not work',
            severity: RunnerEventSeverity.warning,
          ));
        } else {
          _emit(SceneLogEvent(
            message: 'Flutter extensions: ${flutterExtensions.join(', ')}',
          ));
        }
      } catch (e) {
        _emit(SceneLogEvent(
          message: 'Failed to list extensions: $e',
          severity: RunnerEventSeverity.warning,
        ));
      }
    }
  }

  /// Execute a scene and return the results.
  Future<SceneResult> execute(SceneDefinition scene) async {
    _emit(SceneStartedEvent(scene.name));
    final stopwatch = Stopwatch()..start();
    final observations = <ObservationBundle>[];
    final errors = <SceneError>[];

    try {
      // Setup phase
      await _executeSetup(scene.setup);

      // Execute steps
      for (int i = 0; i < scene.steps.length; i++) {
        final step = scene.steps[i];
        _emit(StepStartedEvent(i, step));

        try {
          switch (step) {
            case CheckpointStep(:final checkpoint):
              final bundle = await _captureCheckpoint(
                scene: scene,
                checkpoint: checkpoint,
              );
              observations.add(bundle);
              _emit(SceneCheckpointEvent(checkpoint.name, bundle));

            case InteractionStep(:final interaction):
              await _executeInteraction(scene, interaction);
              _emit(InteractionCompletedEvent(interaction));
          }

          _emit(StepCompletedEvent(i, step));
        } catch (e, stackTrace) {
          final error = SceneError(
            step: i,
            message: e.toString(),
            stackTrace: stackTrace.toString(),
          );
          errors.add(error);
          _emit(StepFailedEvent(i, step, e.toString()));

          // Continue to next step on error
        }
      }

      _emit(SceneCompletedEvent(scene.name, observations.length));

      return SceneResult(
        sceneName: scene.name,
        observations: observations,
        errors: errors,
        elapsed: stopwatch.elapsed,
        success: errors.isEmpty,
      );
    } catch (e, stackTrace) {
      _emit(SceneFailedEvent(scene.name, e.toString()));

      return SceneResult(
        sceneName: scene.name,
        observations: observations,
        errors: [
          ...errors,
          SceneError(
            step: -1,
            message: e.toString(),
            stackTrace: stackTrace.toString(),
          ),
        ],
        elapsed: stopwatch.elapsed,
        success: false,
      );
    }
  }

  Future<void> _executeSetup(SceneSetup setup) async {
    _emit(const SetupStartedEvent());

    // Hot restart if requested
    if (setup.hotRestart) {
      _emit(const SceneLogEvent(message: 'Performing hot restart...'));
      await session.hotRestart();

      // Wait for hot restart to complete via daemon events
      _emit(const SceneLogEvent(message: 'Waiting for restart to complete...'));
      final reloadBarrier = HotReloadBarrier(session: session);
      final reloadResult = await reloadBarrier.wait();
      if (!reloadResult.success) {
        _emit(
          const SceneLogEvent(
            message: 'Warning: Hot restart may not have completed properly',
            severity: RunnerEventSeverity.warning,
          ),
        );
      }

      // Additional delay for app to fully initialize
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // Refresh VM service isolate reference (old isolate is garbage collected)
      if (_vmClient != null) {
        _emit(const SceneLogEvent(message: 'Refreshing VM service connection...'));
        await _vmClient!.refreshIsolate();

        // Wait for Flutter service extensions to be registered
        _emit(const SceneLogEvent(message: 'Waiting for Flutter extensions...'));
        final extensionsReady = await _vmClient!.waitForExtensions();
        if (!extensionsReady) {
          _emit(
            const SceneLogEvent(
              message: 'Warning: Flutter extensions not ready, some captures may fail',
              severity: RunnerEventSeverity.warning,
            ),
          );
        }
      }
    }

    // Navigate if requested via deep link
    if (setup.navigateTo != null) {
      _emit(SceneLogEvent(message: 'Navigating to: ${setup.navigateTo}'));

      // Build deep link URI: ooda://showcase/route
      final deepLink = 'ooda://showcase${setup.navigateTo}';
      await adb.sendDeepLink(deviceId, deepLink);

      // Wait for navigation to complete
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // Wait for visual stability after navigation
      final barrier = VisualStabilityBarrier(
        camera: _deviceCamera,
        timeout: const Duration(seconds: 5),
      );
      await barrier.wait();
    }

    // Setup delay
    if (setup.setupDelayMs != null) {
      await Future<void>.delayed(Duration(milliseconds: setup.setupDelayMs!));
    }

    _emit(const SetupCompletedEvent());
  }

  Future<void> _executeInteraction(
    SceneDefinition scene,
    Interaction interaction,
  ) async {
    if (interaction is WaitInteraction) {
      await _executeWait(scene, interaction);
    } else {
      final result = await _interactionController.execute(interaction);
      if (!result.success) {
        throw SceneExecutionException('Interaction failed: ${result.error}');
      }
    }
  }

  Future<void> _executeWait(SceneDefinition scene, WaitInteraction wait) async {
    final barrierConfig = scene.getBarrierConfig(wait.barrierType);
    final timeout = wait.timeoutMs != null
        ? Duration(milliseconds: wait.timeoutMs!)
        : Duration(milliseconds: barrierConfig.timeoutMs);

    switch (wait.barrierType) {
      case 'visual_stability':
        final barrier = VisualStabilityBarrier(
          camera: _deviceCamera,
          timeout: timeout,
          consecutiveMatches: barrierConfig.consecutiveMatches,
          pollingInterval: Duration(
            milliseconds: barrierConfig.pollingIntervalMs,
          ),
        );
        final result = await barrier.wait();
        if (!result.success) {
          _emit(
            SceneLogEvent(
              message: 'Visual stability timeout: ${result.diagnosticInfo}',
              severity: RunnerEventSeverity.warning,
            ),
          );
        }

      case 'delay':
        await Future<void>.delayed(timeout);

      default:
        _emit(
          SceneLogEvent(
            message: 'Unknown barrier type: ${wait.barrierType}',
            severity: RunnerEventSeverity.warning,
          ),
        );
    }
  }

  Future<ObservationBundle> _captureCheckpoint({
    required SceneDefinition scene,
    required CheckpointDefinition checkpoint,
  }) async {
    _emit(SceneLogEvent(message: 'Capturing checkpoint: ${checkpoint.name}'));

    // Wait for visual stability
    final stabilityBarrier = VisualStabilityBarrier(
      camera: _deviceCamera,
      timeout: const Duration(seconds: 5),
    );
    final stabilityResult = await stabilityBarrier.wait();

    final builder = ObservationBundleBuilder()
        .scene(scene.name)
        .checkpoint(checkpoint.name, description: checkpoint.description)
        .device(deviceId)
        .reload(session.reloadCount)
        .stability(stabilityResult.success ? 'stable' : 'unstable');

    // Capture device screenshot
    if (checkpoint.captureDeviceScreenshot) {
      try {
        var screenshot =
            stabilityResult.value?.screenshot ?? await _deviceCamera.capture();
        screenshot = _maybeResize(screenshot);
        builder.deviceScreenshot(screenshot);
      } catch (e) {
        _emit(
          SceneLogEvent(
            message: 'Failed to capture device screenshot: $e',
            severity: RunnerEventSeverity.error,
          ),
        );
      }
    }

    // Capture Flutter data if available
    if (_flutterCamera != null) {
      // Flutter screenshot
      if (checkpoint.captureFlutterScreenshot) {
        try {
          var screenshot = await _flutterCamera!.captureScreenshot();
          screenshot = _maybeResize(screenshot);
          builder.flutterScreenshot(screenshot);
        } catch (e) {
          _emit(
            SceneLogEvent(
              message: 'Failed to capture Flutter screenshot: $e',
              severity: RunnerEventSeverity.warning,
            ),
          );
        }
      }

      // Widget tree
      if (checkpoint.captureWidgetTree) {
        try {
          final tree = await _flutterCamera!.getWidgetTree();
          builder.widgetTree(tree);
        } catch (e) {
          _emit(
            SceneLogEvent(
              message: 'Failed to capture widget tree: $e',
              severity: RunnerEventSeverity.warning,
            ),
          );
        }
      }

      // Semantics tree
      if (checkpoint.captureSemanticsTree) {
        try {
          final tree = await _flutterCamera!.getSemanticsTree();
          builder.semanticsTree(tree);
        } catch (e) {
          _emit(
            SceneLogEvent(
              message: 'Failed to capture semantics tree: $e',
              severity: RunnerEventSeverity.warning,
            ),
          );
        }
      }
    }

    // Capture logs
    if (checkpoint.captureLogs) {
      try {
        final logcat = await adb.logcat(deviceId, lines: 50);
        builder.addLogs(logcat.split('\n'));
      } catch (e) {
        _emit(
          SceneLogEvent(
            message: 'Failed to capture logs: $e',
            severity: RunnerEventSeverity.warning,
          ),
        );
      }
    }

    final bundle = builder.build();

    // Write to disk
    await bundle.write(outputDir);

    return bundle;
  }

  void _emit(SceneEvent event) {
    _eventController.add(event);
  }

  /// Resize a screenshot if resizing is enabled.
  Uint8List _maybeResize(Uint8List screenshot) {
    if (!resizeScreenshots) return screenshot;
    return ImageUtils.resizeToFit(
          screenshot,
          maxDimension: maxScreenshotDimension,
        ) ??
        screenshot;
  }

  /// Close resources.
  Future<void> close() async {
    await _vmClient?.close();
    await _eventController.close();
  }
}

/// Result of executing a scene.
class SceneResult {
  SceneResult({
    required this.sceneName,
    required this.observations,
    required this.errors,
    required this.elapsed,
    required this.success,
  });

  final String sceneName;
  final List<ObservationBundle> observations;
  final List<SceneError> errors;
  final Duration elapsed;
  final bool success;

  @override
  String toString() {
    return 'SceneResult(scene: $sceneName, observations: ${observations.length}, '
        'errors: ${errors.length}, elapsed: $elapsed, success: $success)';
  }
}

/// An error that occurred during scene execution.
class SceneError {
  SceneError({required this.step, required this.message, this.stackTrace});

  final int step;
  final String message;
  final String? stackTrace;

  @override
  String toString() => 'SceneError(step: $step, message: $message)';
}

/// Exception thrown during scene execution.
class SceneExecutionException implements Exception {
  SceneExecutionException(this.message);

  final String message;

  @override
  String toString() => 'SceneExecutionException: $message';
}

// Scene Events

/// Base class for scene execution events.
sealed class SceneEvent {
  const SceneEvent();
}

class SceneStartedEvent extends SceneEvent {
  const SceneStartedEvent(this.sceneName);
  final String sceneName;
}

class SceneCompletedEvent extends SceneEvent {
  const SceneCompletedEvent(this.sceneName, this.observationCount);
  final String sceneName;
  final int observationCount;
}

class SceneFailedEvent extends SceneEvent {
  const SceneFailedEvent(this.sceneName, this.error);
  final String sceneName;
  final String error;
}

class SetupStartedEvent extends SceneEvent {
  const SetupStartedEvent();
}

class SetupCompletedEvent extends SceneEvent {
  const SetupCompletedEvent();
}

class StepStartedEvent extends SceneEvent {
  const StepStartedEvent(this.stepIndex, this.step);
  final int stepIndex;
  final SceneStep step;
}

class StepCompletedEvent extends SceneEvent {
  const StepCompletedEvent(this.stepIndex, this.step);
  final int stepIndex;
  final SceneStep step;
}

class StepFailedEvent extends SceneEvent {
  const StepFailedEvent(this.stepIndex, this.step, this.error);
  final int stepIndex;
  final SceneStep step;
  final String error;
}

class SceneCheckpointEvent extends SceneEvent {
  const SceneCheckpointEvent(this.checkpointName, this.bundle);
  final String checkpointName;
  final ObservationBundle bundle;
}

class InteractionCompletedEvent extends SceneEvent {
  const InteractionCompletedEvent(this.interaction);
  final Interaction interaction;
}

class SceneLogEvent extends SceneEvent {
  const SceneLogEvent({
    required this.message,
    this.severity = RunnerEventSeverity.info,
  });

  final String message;
  final RunnerEventSeverity severity;
}
