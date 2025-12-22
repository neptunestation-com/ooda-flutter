import 'dart:io';

import 'package:args/command_runner.dart';

/// Command to update ooda to the latest version from git.
class UpdateCommand extends Command<int> {
  UpdateCommand() {
    argParser.addFlag(
      'ssh',
      help: 'Use SSH URL instead of HTTPS (for users with SSH keys configured).',
    );
    argParser.addOption(
      'ref',
      help: 'Git ref to install (branch, tag, or commit). Defaults to main.',
    );
    argParser.addFlag(
      'dry-run',
      help: 'Show the command that would be run without executing it.',
    );
  }

  @override
  final String name = 'update';

  @override
  final String description = 'Update ooda to the latest version from GitHub.';

  static const _httpsUrl = 'https://github.com/neptunestation-com/ooda-flutter.git';
  static const _sshUrl = 'git@github.com:neptunestation-com/ooda-flutter.git';
  static const _gitPath = 'packages/ooda_runner';

  @override
  Future<int> run() async {
    final useSsh = argResults!['ssh'] as bool;
    final ref = argResults!['ref'] as String?;
    final dryRun = argResults!['dry-run'] as bool;

    final url = useSsh ? _sshUrl : _httpsUrl;

    final args = [
      'pub',
      'global',
      'activate',
      '--source',
      'git',
      url,
      '--git-path',
      _gitPath,
    ];

    if (ref != null) {
      args.addAll(['--git-ref', ref]);
    }

    final command = 'dart ${args.join(' ')}';

    if (dryRun) {
      stdout.writeln('Would run: $command');
      return 0;
    }

    stdout.writeln('Updating ooda from ${useSsh ? 'SSH' : 'HTTPS'}...');
    stdout.writeln('Running: $command');
    stdout.writeln('');

    final process = await Process.start(
      'dart',
      args,
      mode: ProcessStartMode.inheritStdio,
    );

    final exitCode = await process.exitCode;

    if (exitCode == 0) {
      stdout.writeln('');
      stdout.writeln('ooda updated successfully.');
    } else {
      stderr.writeln('');
      stderr.writeln('Update failed with exit code $exitCode.');
      if (useSsh) {
        stderr.writeln('Hint: If SSH fails, try without --ssh to use HTTPS.');
      } else {
        stderr.writeln('Hint: If HTTPS fails, try --ssh if you have SSH keys configured.');
      }
    }

    return exitCode;
  }
}
