import 'dart:async';
import 'dart:convert';

/// A JSON-RPC 2.0 request.
class JsonRpcRequest {
  JsonRpcRequest({required this.method, this.params, this.id});

  final String method;
  final dynamic params;
  final dynamic id;

  Map<String, dynamic> toJson() {
    return {
      'jsonrpc': '2.0',
      'method': method,
      if (params != null) 'params': params,
      if (id != null) 'id': id,
    };
  }

  String encode() => jsonEncode(toJson());
}

/// A JSON-RPC 2.0 response.
class JsonRpcResponse {
  JsonRpcResponse({this.id, this.result, this.error});

  factory JsonRpcResponse.fromJson(Map<String, dynamic> json) {
    return JsonRpcResponse(
      id: json['id'],
      result: json['result'],
      error: json['error'] != null
          ? JsonRpcError.fromJson(json['error'] as Map<String, dynamic>)
          : null,
    );
  }

  final dynamic id;
  final dynamic result;
  final JsonRpcError? error;

  bool get isError => error != null;
  bool get isSuccess => error == null;

  @override
  String toString() {
    if (isError) {
      return 'JsonRpcResponse.error(id: $id, error: $error)';
    }
    return 'JsonRpcResponse.success(id: $id, result: $result)';
  }
}

/// A JSON-RPC 2.0 error.
class JsonRpcError {
  JsonRpcError({required this.code, required this.message, this.data});

  factory JsonRpcError.fromJson(Map<String, dynamic> json) {
    return JsonRpcError(
      code: json['code'] as int,
      message: json['message'] as String,
      data: json['data'],
    );
  }

  final int code;
  final String message;
  final dynamic data;

  @override
  String toString() => 'JsonRpcError($code: $message)';
}

/// An event from the Flutter daemon.
class DaemonEvent {
  DaemonEvent({required this.event, required this.params});

  factory DaemonEvent.fromJson(Map<String, dynamic> json) {
    return DaemonEvent(
      event: json['event'] as String,
      params: (json['params'] as Map<String, dynamic>?) ?? {},
    );
  }

  /// The event name (e.g., "app.started", "app.log").
  final String event;

  /// The event parameters.
  final Map<String, dynamic> params;

  /// Get a parameter value.
  T? get<T>(String key) => params[key] as T?;

  @override
  String toString() => 'DaemonEvent($event, $params)';
}

/// Parses JSON-RPC messages from the Flutter daemon.
///
/// The daemon sends newline-delimited JSON messages on stdout.
/// Messages can be:
/// - Responses to requests (have "id" field)
/// - Events/notifications (have "event" field)
/// - Log messages (have "log" field)
class DaemonMessageParser {
  final _eventController = StreamController<DaemonEvent>.broadcast();
  final _responseController = StreamController<JsonRpcResponse>.broadcast();
  final _logController = StreamController<DaemonLog>.broadcast();
  final _rawController = StreamController<Map<String, dynamic>>.broadcast();

  /// Stream of daemon events.
  Stream<DaemonEvent> get events => _eventController.stream;

  /// Stream of RPC responses.
  Stream<JsonRpcResponse> get responses => _responseController.stream;

  /// Stream of log messages.
  Stream<DaemonLog> get logs => _logController.stream;

  /// Stream of all raw messages.
  Stream<Map<String, dynamic>> get rawMessages => _rawController.stream;

  /// Parse a line of output from the daemon.
  ///
  /// Returns true if the line was valid JSON-RPC, false otherwise.
  bool parseLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return false;

    // Skip non-JSON lines (Flutter sometimes outputs plain text)
    if (!trimmed.startsWith('[') && !trimmed.startsWith('{')) {
      return false;
    }

    try {
      final dynamic decoded = jsonDecode(trimmed);

      // Flutter daemon wraps messages in an array
      if (decoded is List && decoded.isNotEmpty) {
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            _handleMessage(item);
          }
        }
        return true;
      } else if (decoded is Map<String, dynamic>) {
        _handleMessage(decoded);
        return true;
      }
    } catch (e) {
      // Not valid JSON, ignore
    }

    return false;
  }

  void _handleMessage(Map<String, dynamic> message) {
    _rawController.add(message);

    if (message.containsKey('event')) {
      // This is an event notification
      _eventController.add(DaemonEvent.fromJson(message));
    } else if (message.containsKey('id') &&
        (message.containsKey('result') || message.containsKey('error'))) {
      // This is a response
      _responseController.add(JsonRpcResponse.fromJson(message));
    } else if (message.containsKey('log')) {
      // This is a log message
      _logController.add(DaemonLog.fromJson(message));
    }
  }

  /// Close all streams.
  Future<void> close() async {
    await _eventController.close();
    await _responseController.close();
    await _logController.close();
    await _rawController.close();
  }
}

/// A log message from the daemon.
class DaemonLog {
  DaemonLog({required this.message, this.error = false, this.stackTrace});

  factory DaemonLog.fromJson(Map<String, dynamic> json) {
    return DaemonLog(
      message: json['log'] as String,
      error: json['error'] as bool? ?? false,
      stackTrace: json['stackTrace'] as String?,
    );
  }

  final String message;
  final bool error;
  final String? stackTrace;

  @override
  String toString() => error ? 'ERROR: $message' : message;
}
