import 'package:ooda_runner/src/daemon/json_rpc_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('JsonRpcRequest', () {
    test('creates request with method only', () {
      final request = JsonRpcRequest(method: 'test.method');
      final json = request.toJson();

      expect(json['jsonrpc'], '2.0');
      expect(json['method'], 'test.method');
      expect(json.containsKey('params'), isFalse);
      expect(json.containsKey('id'), isFalse);
    });

    test('creates request with params and id', () {
      final request = JsonRpcRequest(
        method: 'app.restart',
        params: {'fullRestart': true},
        id: 42,
      );
      final json = request.toJson();

      expect(json['method'], 'app.restart');
      expect(json['params'], {'fullRestart': true});
      expect(json['id'], 42);
    });

    test('encodes to JSON string', () {
      final request = JsonRpcRequest(method: 'test', id: 1);
      final encoded = request.encode();

      expect(encoded, contains('"method":"test"'));
      expect(encoded, contains('"id":1'));
    });
  });

  group('JsonRpcResponse', () {
    test('parses success response', () {
      final json = {
        'jsonrpc': '2.0',
        'id': 1,
        'result': {'success': true},
      };
      final response = JsonRpcResponse.fromJson(json);

      expect(response.isSuccess, isTrue);
      expect(response.isError, isFalse);
      expect(response.id, 1);
      expect(response.result, {'success': true});
    });

    test('parses error response', () {
      final json = {
        'jsonrpc': '2.0',
        'id': 1,
        'error': {'code': -32600, 'message': 'Invalid request'},
      };
      final response = JsonRpcResponse.fromJson(json);

      expect(response.isSuccess, isFalse);
      expect(response.isError, isTrue);
      expect(response.error!.code, -32600);
      expect(response.error!.message, 'Invalid request');
    });
  });

  group('JsonRpcError', () {
    test('parses from JSON', () {
      final json = {
        'code': -32601,
        'message': 'Method not found',
        'data': 'Additional info',
      };
      final error = JsonRpcError.fromJson(json);

      expect(error.code, -32601);
      expect(error.message, 'Method not found');
      expect(error.data, 'Additional info');
    });

    test('toString includes code and message', () {
      final error = JsonRpcError(code: -1, message: 'Test error');
      expect(error.toString(), contains('-1'));
      expect(error.toString(), contains('Test error'));
    });
  });

  group('DaemonEvent', () {
    test('parses from JSON', () {
      final json = {
        'event': 'app.started',
        'params': {'appId': 'test-app', 'deviceId': 'emulator-5554'},
      };
      final event = DaemonEvent.fromJson(json);

      expect(event.event, 'app.started');
      expect(event.get<String>('appId'), 'test-app');
      expect(event.get<String>('deviceId'), 'emulator-5554');
    });

    test('handles missing params', () {
      final json = {'event': 'test.event'};
      final event = DaemonEvent.fromJson(json);

      expect(event.event, 'test.event');
      expect(event.params, isEmpty);
    });

    test('get returns null for missing key', () {
      final event = DaemonEvent(event: 'test', params: {});
      expect(event.get<String>('missing'), isNull);
    });
  });

  group('DaemonMessageParser', () {
    late DaemonMessageParser parser;

    setUp(() {
      parser = DaemonMessageParser();
    });

    tearDown(() {
      parser.close();
    });

    test('parses event message', () async {
      final events = <DaemonEvent>[];
      parser.events.listen(events.add);

      final parsed = parser.parseLine(
        '[{"event":"app.started","params":{"appId":"test"}}]',
      );

      expect(parsed, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(1));
      expect(events.first.event, 'app.started');
    });

    test('parses response message', () async {
      final responses = <JsonRpcResponse>[];
      parser.responses.listen(responses.add);

      final parsed = parser.parseLine('[{"id":1,"result":{"success":true}}]');

      expect(parsed, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(responses, hasLength(1));
      expect(responses.first.isSuccess, isTrue);
    });

    test('parses log message', () async {
      final logs = <DaemonLog>[];
      parser.logs.listen(logs.add);

      final parsed = parser.parseLine('[{"log":"Test log message"}]');

      expect(parsed, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(logs, hasLength(1));
      expect(logs.first.message, 'Test log message');
    });

    test('ignores non-JSON lines', () {
      expect(parser.parseLine(''), isFalse);
      expect(parser.parseLine('Not JSON'), isFalse);
      expect(parser.parseLine('Launching lib/main.dart...'), isFalse);
    });

    test('ignores invalid JSON', () {
      expect(parser.parseLine('{invalid json}'), isFalse);
    });

    test('handles multiple messages in array', () async {
      final events = <DaemonEvent>[];
      parser.events.listen(events.add);

      parser.parseLine(
        '[{"event":"event1","params":{}},{"event":"event2","params":{}}]',
      );

      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(2));
    });
  });

  group('DaemonLog', () {
    test('parses normal log', () {
      final log = DaemonLog.fromJson({'log': 'Info message'});

      expect(log.message, 'Info message');
      expect(log.error, isFalse);
    });

    test('parses error log', () {
      final log = DaemonLog.fromJson({
        'log': 'Error message',
        'error': true,
        'stackTrace': 'at line 1',
      });

      expect(log.message, 'Error message');
      expect(log.error, isTrue);
      expect(log.stackTrace, 'at line 1');
    });

    test('toString for error', () {
      final log = DaemonLog(message: 'test', error: true);
      expect(log.toString(), 'ERROR: test');
    });

    test('toString for normal', () {
      final log = DaemonLog(message: 'test');
      expect(log.toString(), 'test');
    });
  });
}
