import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';

import 'version.dart';

/// Result of checking for updates.
class UpdateCheckResult {
  const UpdateCheckResult({
    required this.updateAvailable,
    this.latestVersion,
    required this.currentVersion,
  });

  final bool updateAvailable;
  final String? latestVersion;
  final String currentVersion;
}

/// Checks GitHub for the latest release.
///
/// Returns null if the check fails (network error, rate limited, etc.).
/// This is designed to fail silently so it doesn't disrupt normal CLI usage.
Future<UpdateCheckResult?> checkForUpdate({Duration? timeout}) async {
  try {
    final client = HttpClient();
    client.connectionTimeout = timeout ?? const Duration(seconds: 2);

    final request = await client.getUrl(
      Uri.parse(
        'https://api.github.com/repos/neptunestation-com/ooda-flutter/releases/latest',
      ),
    );
    request.headers.set('Accept', 'application/vnd.github.v3+json');
    request.headers.set('User-Agent', 'ooda-cli/$version');

    final response = await request.close().timeout(
      timeout ?? const Duration(seconds: 3),
    );

    if (response.statusCode != 200) {
      await response.drain<void>();
      return null;
    }

    final body = await response.transform(utf8.decoder).join();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final tagName = json['tag_name'] as String?;

    if (tagName == null) {
      return null;
    }

    // Strip 'v' prefix if present (e.g., 'v0.2.0' -> '0.2.0')
    final latestVersion = tagName.startsWith('v') ? tagName.substring(1) : tagName;

    final updateAvailable = isNewerVersion(latestVersion, version);

    return UpdateCheckResult(
      updateAvailable: updateAvailable,
      latestVersion: latestVersion,
      currentVersion: version,
    );
  } catch (_) {
    // Fail silently - network issues, parsing errors, etc. shouldn't break the CLI
    return null;
  }
}

/// Compares semantic versions. Returns true if [latest] is newer than [current].
@visibleForTesting
bool isNewerVersion(String latest, String current) {
  final latestParts = parseVersion(latest);
  final currentParts = parseVersion(current);

  if (latestParts == null || currentParts == null) {
    return false;
  }

  for (var i = 0; i < 3; i++) {
    if (latestParts[i] > currentParts[i]) return true;
    if (latestParts[i] < currentParts[i]) return false;
  }

  return false;
}

/// Parses a semantic version string into [major, minor, patch].
@visibleForTesting
List<int>? parseVersion(String version) {
  // Handle versions like "0.1.0", "1.2.3", "0.1.0-beta"
  final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)').firstMatch(version);
  if (match == null) return null;

  return [
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  ];
}

/// Prints an update notification to stderr if an update is available.
///
/// Only prints if stdout is a TTY (to avoid polluting script output).
void printUpdateNotification(UpdateCheckResult result) {
  if (!result.updateAvailable) return;
  if (!stdout.hasTerminal) return;

  stderr.writeln('');
  stderr.writeln(
    'A new version of ooda is available: '
    '${result.currentVersion} -> ${result.latestVersion}',
  );
  stderr.writeln('Run `ooda update` to update.');
  stderr.writeln('');
}
