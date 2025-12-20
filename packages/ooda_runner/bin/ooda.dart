import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:ooda_runner/src/commands/devices_command.dart';
import 'package:ooda_runner/src/commands/info_command.dart';
import 'package:ooda_runner/src/commands/observe_command.dart';
import 'package:ooda_runner/src/commands/run_command.dart';
import 'package:ooda_runner/src/commands/scene_command.dart';
import 'package:ooda_runner/src/commands/screenshot_command.dart';

void main(List<String> arguments) async {
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
        ..addCommand(ScreenshotCommand());

  try {
    final exitCode = await runner.run(arguments) ?? 0;
    exit(exitCode);
  } on UsageException catch (e) {
    stderr.writeln(e);
    exit(64);
  } catch (e, stackTrace) {
    stderr.writeln('Error: $e');
    stderr.writeln(stackTrace);
    exit(1);
  }
}
