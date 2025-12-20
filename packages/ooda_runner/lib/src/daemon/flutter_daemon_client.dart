import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'json_rpc_protocol.dart';

/// Exception thrown when a daemon operation fails.
class DaemonException implements Exception {
  DaemonException(this.message, {this.rpcError});

  final String message;
  final JsonRpcError? rpcError;

  @override
  String toString() {
    if (rpcError != null) {
      return 'DaemonException: $message (${rpcError!.code}: ${rpcError!.message})';
    }
    return 'DaemonException: $message';
  }
}

/// Client for communicating with the Flutter daemon.
///
/// The Flutter daemon is started via `flutter run --machine` and communicates
/// using JSON-RPC 2.0 over stdin/stdout.
class FlutterDaemonClient {
  FlutterDaemonClient._(this._process)
      : _parser = DaemonMessageParser() {
    // Listen to stdout for JSON-RPC messages
    _stdoutSubscription = _process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_handleStdoutLine);

    // Listen to stderr for error messages
    _stderrSubscription = _process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      _stderrController.add(line);
    });

    // Forward events from parser
    _parser.events.listen((event) {
      if (!_isClosed) {
        _eventController.add(event);
      }
    });

    _parser.logs.listen((log) {
      if (!_isClosed) {
        _logController.add(log);
      }
    });

    // Handle responses
    _parser.responses.listen((response) {
      final id = response.id;
      if (id != null && _pendingRequests.containsKey(id)) {
        _pendingRequests.remove(id)!.complete(response);
      }
    });
  }

  final Process _process;
  final DaemonMessageParser _parser;
  final Map<int, Completer<JsonRpcResponse>> _pendingRequests = {};
  int _nextId = 1;

  late final StreamSubscription<String> _stdoutSubscription;
  late final StreamSubscription<String> _stderrSubscription;

  final _eventController = StreamController<DaemonEvent>.broadcast();
  final _logController = StreamController<DaemonLog>.broadcast();
  final _stderrController = StreamController<String>.broadcast();

  bool _isClosed = false;

  /// Stream of daemon events.
  Stream<DaemonEvent> get events => _eventController.stream;

  /// Stream of daemon log messages.
  Stream<DaemonLog> get logs => _logController.stream;

  /// Stream of stderr output.
  Stream<String> get stderr => _stderrController.stream;

  /// The process ID of the Flutter daemon.
  int get pid => _process.pid;

  /// Whether the client has been closed.
  bool get isClosed => _isClosed;

  void _handleStdoutLine(String line) {
    _parser.parseLine(line);
  }

  /// Send a JSON-RPC request and wait for the response.
  Future<JsonRpcResponse> request(
    String method, [
    Map<String, dynamic>? params,
  ]) async {
    if (_isClosed) {
      throw DaemonException('Client is closed');
    }

    final id = _nextId++;
    final request = JsonRpcRequest(
      method: method,
      params: params,
      id: id,
    );

    final completer = Completer<JsonRpcResponse>();
    _pendingRequests[id] = completer;

    // Send request to daemon
    final message = '[${request.encode()}]\n';
    _process.stdin.write(message);
    await _process.stdin.flush();

    return completer.future;
  }

  /// Send a request and return the result, throwing on error.
  Future<dynamic> call(
    String method, [
    Map<String, dynamic>? params,
  ]) async {
    final response = await request(method, params);
    if (response.isError) {
      throw DaemonException(
        'Request failed: $method',
        rpcError: response.error,
      );
    }
    return response.result;
  }

  /// Trigger a hot reload.
  Future<Map<String, dynamic>> hotReload({
    String? appId,
    bool pause = false,
  }) async {
    final result = await call('app.restart', {
      if (appId != null) 'appId': appId,
      'fullRestart': false,
      'pause': pause,
    });
    return result as Map<String, dynamic>;
  }

  /// Trigger a hot restart.
  Future<Map<String, dynamic>> hotRestart({
    String? appId,
    bool pause = false,
  }) async {
    final result = await call('app.restart', {
      if (appId != null) 'appId': appId,
      'fullRestart': true,
      'pause': pause,
    });
    return result as Map<String, dynamic>;
  }

  /// Stop the running application.
  Future<void> stop({String? appId}) async {
    await call('app.stop', {
      if (appId != null) 'appId': appId,
    });
  }

  /// Call a service extension on the VM service.
  Future<dynamic> callServiceExtension(
    String method, {
    String? appId,
    String? isolateId,
    Map<String, dynamic>? params,
  }) async {
    return await call('app.callServiceExtension', {
      if (appId != null) 'appId': appId,
      'methodName': method,
      if (isolateId != null) 'isolateId': isolateId,
      if (params != null) 'params': params,
    });
  }

  /// Detach from the running application (keeps it running).
  Future<void> detach({String? appId}) async {
    await call('app.detach', {
      if (appId != null) 'appId': appId,
    });
  }

  /// Close the daemon client and terminate the process.
  Future<int> close() async {
    if (_isClosed) return 0;
    _isClosed = true;

    // Cancel pending requests
    for (final completer in _pendingRequests.values) {
      completer.completeError(DaemonException('Client closed'));
    }
    _pendingRequests.clear();

    // Close streams
    await _stdoutSubscription.cancel();
    await _stderrSubscription.cancel();
    await _parser.close();
    await _eventController.close();
    await _logController.close();
    await _stderrController.close();

    // Close stdin and terminate
    await _process.stdin.close();

    // Give the process a chance to exit gracefully
    final exitCode = await _process.exitCode.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        _process.kill();
        return -1;
      },
    );

    return exitCode;
  }

  /// Create a new daemon client from a process.
  static FlutterDaemonClient fromProcess(Process process) {
    return FlutterDaemonClient._(process);
  }
}

/// Known daemon event types.
abstract class DaemonEvents {
  /// App has started running.
  static const appStarted = 'app.started';

  /// App debug port is available.
  static const appDebugPort = 'app.debugPort';

  /// App has been stopped.
  static const appStop = 'app.stop';

  /// Progress update for an operation.
  static const appProgress = 'app.progress';

  /// Log message from the app.
  static const appLog = 'app.log';

  /// Web launch URL available.
  static const appWebLaunchUrl = 'app.webLaunchUrl';

  /// Daemon connected notification.
  static const daemonConnected = 'daemon.connected';

  /// Daemon log output.
  static const daemonLogMessage = 'daemon.logMessage';

  /// Device added.
  static const deviceAdded = 'device.added';

  /// Device removed.
  static const deviceRemoved = 'device.removed';
}
