import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:ooda_runner/src/commands/devices_command.dart';
import 'package:ooda_runner/src/commands/info_command.dart';
import 'package:ooda_runner/src/commands/observe_command.dart';
import 'package:ooda_runner/src/commands/run_command.dart';
import 'package:ooda_runner/src/commands/scene_command.dart';
import 'package:ooda_runner/src/commands/screenshot_command.dart';
import 'package:ooda_runner/src/commands/update_command.dart';
import 'package:ooda_runner/src/update_checker.dart';

void main(List<String> arguments) async {
  // Start update check in background (don't await - runs concurrently)
  final updateCheckFuture = stdout.hasTerminal ? checkForUpdate() : null;

  final runner =
      CommandRunner<int>(
          'ooda',
          'AI-driven Flutter OODA loop - control plane for automated UI testing.',
        )
        ..addCommand(DevicesCommand())
        ..addCommand(InfoCommand())
        ..addCommand(ObserveCommand())
        ..addCommand(RunCommand())
        ..addCommand(SceneCommand())
        ..addCommand(ScreenshotCommand())
        ..addCommand(UpdateCommand());

  try {
    final exitCode = await runner.run(arguments) ?? 0;
    await _showUpdateNotification(updateCheckFuture);
    exit(exitCode);
  } on UsageException catch (e) {
    stderr.writeln(e);
    await _showUpdateNotification(updateCheckFuture);
    exit(64);
  } catch (e, stackTrace) {
    stderr.writeln('Error: $e');
    stderr.writeln(stackTrace);
    await _showUpdateNotification(updateCheckFuture);
    exit(1);
  }
}

Future<void> _showUpdateNotification(
  Future<UpdateCheckResult?>? updateCheckFuture,
) async {
  if (updateCheckFuture == null) return;
  final result = await updateCheckFuture;
  if (result != null) {
    printUpdateNotification(result);
  }
}
