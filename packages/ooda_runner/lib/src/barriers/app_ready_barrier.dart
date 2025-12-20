import 'dart:async';

import 'package:ooda_shared/ooda_shared.dart';

import '../daemon/flutter_daemon_client.dart';
import '../daemon/json_rpc_protocol.dart';
import '../runner/flutter_session.dart';
import 'barrier.dart';

/// Barrier that waits for the Flutter app to start.
///
/// Listens for the `app.started` event from the Flutter daemon.
class AppReadyBarrier extends EventBarrier<AppInfo> {
  AppReadyBarrier({
    required FlutterSession session,
    super.timeout = const Duration(minutes: 2),
  }) : _session = session;

  @override
  final String name = 'AppReady';

  final FlutterSession _session;
  AppInfo? _appInfo;

  @override
  Stream<dynamic> get eventStream => _session.events;

  @override
  bool matchesEvent(dynamic event) {
    if (event is DaemonEvent && event.event == DaemonEvents.appStarted) {
      final appId = event.get<String>('appId');
      final deviceId = event.get<String>('deviceId');
      if (appId != null && deviceId != null) {
        _appInfo = AppInfo(
          appId: appId,
          deviceId: deviceId,
          directory: event.get<String>('directory'),
          supportsRestart: event.get<bool>('supportsRestart') ?? true,
        );
        return true;
      }
    }
    return false;
  }

  @override
  AppInfo? extractValue(dynamic event) => _appInfo;

  @override
  Future<bool> check() async {
    // Check if already running
    return _session.isRunning && _session.appInfo != null;
  }

  @override
  Future<BarrierResult<AppInfo>> wait() async {
    // First check if already running
    if (await check()) {
      return BarrierResult.success(
        value: _session.appInfo,
        elapsed: Duration.zero,
      );
    }

    // Otherwise wait for the event
    return super.wait();
  }

  @override
  Future<String> collectDiagnostics() async {
    final buffer = StringBuffer();
    buffer.writeln('App Ready Barrier Timeout Diagnostics');
    buffer.writeln('');
    buffer.writeln('Session state: ${_session.state}');
    buffer.writeln('App info: ${_session.appInfo}');
    buffer.writeln('');

    // Collect stderr output if available
    buffer.writeln('Recent daemon logs:');
    await for (final log in _session.client.logs.take(10)) {
      buffer.writeln('  $log');
    }

    buffer.writeln('');
    buffer.writeln('Possible causes:');
    buffer.writeln('  - Flutter project failed to compile');
    buffer.writeln('  - Device not connected or not ready');
    buffer.writeln('  - Missing dependencies (run flutter pub get)');
    buffer.writeln('  - Gradle sync issues (Android)');

    return buffer.toString();
  }
}

/// Barrier that waits for a hot reload to complete.
///
/// Listens for the `app.progress` event with progressId containing "reload".
class HotReloadBarrier extends EventBarrier<Duration> {
  HotReloadBarrier({
    required FlutterSession session,
    super.timeout = const Duration(seconds: 30),
  })  : _session = session,
        _startTime = DateTime.now();

  @override
  final String name = 'HotReload';

  final FlutterSession _session;
  final DateTime _startTime;
  String? _progressId;

  @override
  Stream<dynamic> get eventStream => _session.events;

  @override
  bool matchesEvent(dynamic event) {
    if (event is! DaemonEvent) return false;

    if (event.event == DaemonEvents.appProgress) {
      final progressId = event.get<String>('progressId') ?? '';
      final finished = event.get<bool>('finished') ?? false;

      // Track the reload progress
      if (progressId.contains('reload') || progressId.contains('restart')) {
        if (finished) {
          return true;
        } else {
          _progressId = progressId;
        }
      }
    }

    return false;
  }

  @override
  Duration? extractValue(dynamic event) {
    return DateTime.now().difference(_startTime);
  }

  @override
  Future<String> collectDiagnostics() async {
    final buffer = StringBuffer();
    buffer.writeln('Hot Reload Barrier Timeout Diagnostics');
    buffer.writeln('');
    buffer.writeln('Session state: ${_session.state}');
    buffer.writeln('Progress ID: $_progressId');
    buffer.writeln('Reload count: ${_session.reloadCount}');
    buffer.writeln('');
    buffer.writeln('Possible causes:');
    buffer.writeln('  - Compilation errors in the code');
    buffer.writeln('  - Device disconnected during reload');
    buffer.writeln('  - Hot reload not supported for this change');

    return buffer.toString();
  }
}

/// Barrier that waits for the VM service to be available.
class VmServiceReadyBarrier extends EventBarrier<Uri> {
  VmServiceReadyBarrier({
    required FlutterSession session,
    super.timeout = const Duration(seconds: 30),
  }) : _session = session;

  @override
  final String name = 'VmServiceReady';

  final FlutterSession _session;
  Uri? _vmServiceUri;

  @override
  Stream<dynamic> get eventStream => _session.events;

  @override
  bool matchesEvent(dynamic event) {
    if (event is DaemonEvent && event.event == DaemonEvents.appDebugPort) {
      final wsUri = event.get<String>('wsUri');
      if (wsUri != null) {
        _vmServiceUri = Uri.parse(wsUri);
        return true;
      }
    }
    return false;
  }

  @override
  Uri? extractValue(dynamic event) => _vmServiceUri;

  @override
  Future<bool> check() async {
    return _session.appInfo?.vmServiceUri != null;
  }

  @override
  Future<BarrierResult<Uri>> wait() async {
    // First check if already available
    final existingUri = _session.appInfo?.vmServiceUri;
    if (existingUri != null) {
      return BarrierResult.success(
        value: existingUri,
        elapsed: Duration.zero,
      );
    }

    // Otherwise wait for the event
    return super.wait();
  }

  @override
  Future<String> collectDiagnostics() async {
    final buffer = StringBuffer();
    buffer.writeln('VM Service Ready Barrier Timeout Diagnostics');
    buffer.writeln('');
    buffer.writeln('Session state: ${_session.state}');
    buffer.writeln('App info: ${_session.appInfo}');
    buffer.writeln('');
    buffer.writeln('The VM service URI is needed for:');
    buffer.writeln('  - Widget tree inspection');
    buffer.writeln('  - Flutter screenshots');
    buffer.writeln('  - Semantics tree access');

    return buffer.toString();
  }
}
