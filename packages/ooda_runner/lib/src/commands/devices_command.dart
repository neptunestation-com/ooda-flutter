import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:ooda_shared/ooda_shared.dart';

import '../adb/adb_client.dart';
import '../adb/device_manager.dart';

/// Command to list connected Android devices.
class DevicesCommand extends Command<int> {
  DevicesCommand() {
    argParser.addFlag(
      'ready-only',
      abbr: 'r',
      help: 'Only show devices that are ready for use.',
      defaultsTo: false,
    );
    argParser.addFlag(
      'emulators-only',
      abbr: 'e',
      help: 'Only show emulators.',
      defaultsTo: false,
    );
    argParser.addFlag(
      'json',
      abbr: 'j',
      help: 'Output in JSON format.',
      defaultsTo: false,
    );
  }

  @override
  final String name = 'devices';

  @override
  final String description = 'List connected Android devices.';

  @override
  Future<int> run() async {
    final readyOnly = argResults!['ready-only'] as bool;
    final emulatorsOnly = argResults!['emulators-only'] as bool;
    final jsonOutput = argResults!['json'] as bool;

    final manager = DeviceManager(adbClient: AdbClient());

    try {
      var devices = await manager.listDevices();

      if (readyOnly) {
        devices = devices.where((d) => d.isReady).toList();
      }

      if (emulatorsOnly) {
        devices = devices.where((d) => d.isEmulator).toList();
      }

      if (jsonOutput) {
        _printJson(devices);
      } else {
        _printTable(devices);
      }

      return 0;
    } on AdbException catch (e) {
      stderr.writeln('Error: $e');
      return 1;
    }
  }

  void _printTable(List<AdbDevice> devices) {
    if (devices.isEmpty) {
      stdout.writeln('No devices found.');
      stdout.writeln('');
      stdout.writeln('To start an emulator:');
      stdout.writeln('  emulator -list-avds');
      stdout.writeln('  emulator -avd <avd_name>');
      return;
    }

    stdout.writeln('');
    stdout.writeln('Connected devices:');
    stdout.writeln('');

    // Calculate column widths
    int idWidth = 'ID'.length;
    int stateWidth = 'STATE'.length;
    int modelWidth = 'MODEL'.length;

    for (final device in devices) {
      idWidth = idWidth > device.id.length ? idWidth : device.id.length;
      stateWidth = stateWidth > device.state.name.length
          ? stateWidth
          : device.state.name.length;
      final model = device.model ?? '';
      modelWidth = modelWidth > model.length ? modelWidth : model.length;
    }

    // Print header
    stdout.writeln(
      '  ${'ID'.padRight(idWidth)}  ${'STATE'.padRight(stateWidth)}  ${'MODEL'.padRight(modelWidth)}  TYPE',
    );
    stdout.writeln(
      '  ${'-' * idWidth}  ${'-' * stateWidth}  ${'-' * modelWidth}  ----',
    );

    // Print devices
    for (final device in devices) {
      final type = device.isEmulator ? 'emulator' : 'physical';
      stdout.writeln(
        '  ${device.id.padRight(idWidth)}  ${device.state.name.padRight(stateWidth)}  ${(device.model ?? '').padRight(modelWidth)}  $type',
      );
    }

    stdout.writeln('');
  }

  void _printJson(List<AdbDevice> devices) {
    final json = devices
        .map(
          (d) => {
            'id': d.id,
            'state': d.state.name,
            'model': d.model,
            'product': d.product,
            'is_emulator': d.isEmulator,
            'is_ready': d.isReady,
          },
        )
        .toList();

    stdout.writeln('[');
    for (int i = 0; i < json.length; i++) {
      final item = json[i];
      stdout.write('  {');
      stdout.write('"id": "${item['id']}", ');
      stdout.write('"state": "${item['state']}", ');
      stdout.write(
        '"model": ${item['model'] != null ? '"${item['model']}"' : 'null'}, ',
      );
      stdout.write('"is_emulator": ${item['is_emulator']}, ');
      stdout.write('"is_ready": ${item['is_ready']}');
      stdout.write('}');
      if (i < json.length - 1) stdout.write(',');
      stdout.writeln();
    }
    stdout.writeln(']');
  }
}
