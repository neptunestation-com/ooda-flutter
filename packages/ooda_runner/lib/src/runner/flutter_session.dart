import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../daemon/flutter_daemon_client.dart';
import '../daemon/json_rpc_protocol.dart';

/// Configuration for a Flutter session.
class FlutterSessionConfig {
  const FlutterSessionConfig({
    required this.projectPath,
    this.deviceId,
    this.flavor,
    this.target,
    this.additionalArgs = const [],
    this.flutterPath = 'flutter',
    this.workingDirectory,
    this.environment,
  });

  /// Path to the Flutter project directory.
  final String projectPath;

  /// Device ID to run on.
  final String? deviceId;

  /// Flavor to use (if applicable).
  final String? flavor;

  /// Target file (defaults to lib/main.dart).
  final String? target;

  /// Additional arguments to pass to flutter run.
  final List<String> additionalArgs;

  /// Path to the Flutter executable.
  final String flutterPath;

  /// Working directory (defaults to projectPath).
  final String? workingDirectory;

  /// Environment variables.
  final Map<String, String>? environment;

  /// Build the command-line arguments for flutter run.
  List<String> buildArgs() {
    return [
      'run',
      '--machine',
      if (deviceId != null) ...['-d', deviceId!],
      if (flavor != null) ...['--flavor', flavor!],
      if (target != null) ...['-t', target!],
      ...additionalArgs,
    ];
  }
}

/// State of a Flutter session.
enum FlutterSessionState {
  /// Session is being created.
  starting,

  /// App is running and ready.
  running,

  /// Session is being stopped.
  stopping,

  /// Session has stopped.
  stopped,

  /// Session encountered an error.
  error,
}

/// Information about the running app.
class AppInfo {
  AppInfo({
    required this.appId,
    required this.deviceId,
    this.directory,
    this.supportsRestart = true,
    this.vmServiceUri,
  });

  /// The app ID assigned by Flutter.
  final String appId;

  /// The device ID the app is running on.
  final String deviceId;

  /// The directory of the Flutter project.
  final String? directory;

  /// Whether the app supports hot restart.
  final bool supportsRestart;

  /// URI of the VM service (for debugging).
  final Uri? vmServiceUri;

  @override
  String toString() => 'AppInfo(appId: $appId, device: $deviceId)';
}

/// Manages a Flutter run session.
///
/// This class handles:
/// - Starting `flutter run --machine`
/// - Communicating with the daemon via JSON-RPC
/// - Tracking app state and lifecycle events
/// - Hot reload/restart operations
class FlutterSession {
  FlutterSession._({
    required this.config,
    required FlutterDaemonClient client,
  }) : _client = client {
    _eventSubscription = _client.events.listen(_handleEvent);
  }

  final FlutterSessionConfig config;
  final FlutterDaemonClient _client;

  FlutterSessionState _state = FlutterSessionState.starting;
  AppInfo? _appInfo;
  int _reloadCount = 0;

  final _stateController = StreamController<FlutterSessionState>.broadcast();
  final _eventController = StreamController<DaemonEvent>.broadcast();

  late final StreamSubscription<DaemonEvent> _eventSubscription;

  /// Current session state.
  FlutterSessionState get state => _state;

  /// Stream of state changes.
  Stream<FlutterSessionState> get stateChanges => _stateController.stream;

  /// Stream of daemon events.
  Stream<DaemonEvent> get events => _eventController.stream;

  /// Information about the running app (null until app.started).
  AppInfo? get appInfo => _appInfo;

  /// Whether the app is running and ready.
  bool get isRunning => _state == FlutterSessionState.running;

  /// The daemon client for advanced operations.
  FlutterDaemonClient get client => _client;

  /// Number of reloads performed in this session.
  int get reloadCount => _reloadCount;

  void _handleEvent(DaemonEvent event) {
    _eventController.add(event);

    switch (event.event) {
      case DaemonEvents.appStarted:
        _handleAppStarted(event);
        break;
      case DaemonEvents.appDebugPort:
        _handleDebugPort(event);
        break;
      case DaemonEvents.appStop:
        _handleAppStop(event);
        break;
    }
  }

  void _handleAppStarted(DaemonEvent event) {
    final appId = event.get<String>('appId');
    final deviceId = event.get<String>('deviceId');
    final directory = event.get<String>('directory');
    final supportsRestart = event.get<bool>('supportsRestart') ?? true;

    if (appId != null && deviceId != null) {
      _appInfo = AppInfo(
        appId: appId,
        deviceId: deviceId,
        directory: directory,
        supportsRestart: supportsRestart,
        vmServiceUri: _appInfo?.vmServiceUri,
      );
      _setState(FlutterSessionState.running);
    }
  }

  void _handleDebugPort(DaemonEvent event) {
    final wsUri = event.get<String>('wsUri');
    if (wsUri != null && _appInfo != null) {
      _appInfo = AppInfo(
        appId: _appInfo!.appId,
        deviceId: _appInfo!.deviceId,
        directory: _appInfo!.directory,
        supportsRestart: _appInfo!.supportsRestart,
        vmServiceUri: Uri.parse(wsUri),
      );
    } else if (wsUri != null) {
      // Debug port came before app.started, store for later
      _appInfo = AppInfo(
        appId: '',
        deviceId: '',
        vmServiceUri: Uri.parse(wsUri),
      );
    }
  }

  void _handleAppStop(DaemonEvent event) {
    _setState(FlutterSessionState.stopped);
  }

  void _setState(FlutterSessionState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
    }
  }

  /// Trigger a hot reload.
  ///
  /// Returns the reload result from the daemon.
  Future<Map<String, dynamic>> hotReload() async {
    if (!isRunning) {
      throw StateError('Cannot reload: app is not running');
    }

    final result = await _client.hotReload(appId: _appInfo?.appId);
    _reloadCount++;
    return result;
  }

  /// Trigger a hot restart.
  ///
  /// Returns the restart result from the daemon.
  Future<Map<String, dynamic>> hotRestart() async {
    if (!isRunning) {
      throw StateError('Cannot restart: app is not running');
    }

    final result = await _client.hotRestart(appId: _appInfo?.appId);
    _reloadCount++;
    return result;
  }

  /// Call a service extension.
  Future<dynamic> callServiceExtension(
    String method, {
    Map<String, dynamic>? params,
  }) async {
    if (!isRunning) {
      throw StateError('Cannot call service extension: app is not running');
    }

    return await _client.callServiceExtension(
      method,
      appId: _appInfo?.appId,
      params: params,
    );
  }

  /// Wait for the app to be ready.
  Future<AppInfo> waitForAppReady({
    Duration timeout = const Duration(minutes: 2),
  }) async {
    if (isRunning && _appInfo != null) {
      return _appInfo!;
    }

    final completer = Completer<AppInfo>();

    late StreamSubscription<DaemonEvent> subscription;
    subscription = events.listen((event) {
      if (event.event == DaemonEvents.appStarted && _appInfo != null) {
        subscription.cancel();
        if (!completer.isCompleted) {
          completer.complete(_appInfo);
        }
      }
    });

    // Set up timeout
    final timer = Timer(timeout, () {
      subscription.cancel();
      if (!completer.isCompleted) {
        completer.completeError(
          TimeoutException('App did not start within $timeout'),
        );
      }
    });

    try {
      return await completer.future;
    } finally {
      timer.cancel();
    }
  }

  /// Stop the session and terminate the Flutter process.
  Future<int> stop() async {
    if (_state == FlutterSessionState.stopped) {
      return 0;
    }

    _setState(FlutterSessionState.stopping);

    try {
      // Try to stop gracefully via daemon
      await _client.stop(appId: _appInfo?.appId).timeout(
            const Duration(seconds: 5),
            onTimeout: () {},
          );
    } catch (_) {
      // Ignore errors during graceful stop
    }

    await _eventSubscription.cancel();
    await _stateController.close();
    await _eventController.close();

    final exitCode = await _client.close();
    _setState(FlutterSessionState.stopped);

    return exitCode;
  }

  /// Start a new Flutter session.
  static Future<FlutterSession> start(FlutterSessionConfig config) async {
    final args = config.buildArgs();
    final workDir = config.workingDirectory ?? config.projectPath;

    // Verify project exists
    final pubspecFile = File(p.join(config.projectPath, 'pubspec.yaml'));
    if (!await pubspecFile.exists()) {
      throw FlutterSessionException(
        'Not a Flutter project: ${config.projectPath}',
      );
    }

    // Start flutter run --machine
    final process = await Process.start(
      config.flutterPath,
      args,
      workingDirectory: workDir,
      environment: config.environment,
    );

    final client = FlutterDaemonClient.fromProcess(process);

    return FlutterSession._(
      config: config,
      client: client,
    );
  }
}

/// Exception thrown when a Flutter session operation fails.
class FlutterSessionException implements Exception {
  FlutterSessionException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() {
    if (cause != null) {
      return 'FlutterSessionException: $message\nCaused by: $cause';
    }
    return 'FlutterSessionException: $message';
  }
}
