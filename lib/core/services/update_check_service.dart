import '../app_version.dart';
import 'update_check_service_stub.dart'
    if (dart.library.io) 'update_check_service_io.dart' as impl;

class LatestRelease {
  final String tagName;
  final String version;
  final String htmlUrl;

  const LatestRelease({
    required this.tagName,
    required this.version,
    required this.htmlUrl,
  });
}

enum UpdateCheckStatus { upToDate, updateAvailable, unsupported, failed }

class UpdateCheckResult {
  final UpdateCheckStatus status;
  final LatestRelease? latest;
  final String? errorMessage;

  const UpdateCheckResult({
    required this.status,
    this.latest,
    this.errorMessage,
  });
}

/// Normalize a version/tag string to `x.y.z`.
///
/// Strips a leading `v`/`V`, build (`+…`) and prerelease (`-…`) metadata.
/// Pads missing minor/patch with `0`. Returns null if not numeric.
String? normalizeVersion(String raw) {
  var value = raw.trim();
  if (value.isEmpty) return null;

  if (value.startsWith('v') || value.startsWith('V')) {
    value = value.substring(1);
  }

  final plusIndex = value.indexOf('+');
  if (plusIndex != -1) {
    value = value.substring(0, plusIndex);
  }

  final dashIndex = value.indexOf('-');
  if (dashIndex != -1) {
    value = value.substring(0, dashIndex);
  }

  value = value.trim();
  if (value.isEmpty) return null;

  final parts = value.split('.');
  if (parts.isEmpty || parts.length > 3) return null;

  final segments = <int>[];
  for (final part in parts) {
    if (part.isEmpty || int.tryParse(part) == null) return null;
    segments.add(int.parse(part));
  }

  while (segments.length < 3) {
    segments.add(0);
  }

  return '${segments[0]}.${segments[1]}.${segments[2]}';
}

/// True when [remote] is strictly newer than [current] after normalization.
bool isRemoteNewer(String current, String remote) {
  final currentNorm = normalizeVersion(current);
  final remoteNorm = normalizeVersion(remote);
  if (currentNorm == null || remoteNorm == null) return false;

  final currentParts = currentNorm.split('.').map(int.parse).toList();
  final remoteParts = remoteNorm.split('.').map(int.parse).toList();

  for (var i = 0; i < 3; i++) {
    if (remoteParts[i] > currentParts[i]) return true;
    if (remoteParts[i] < currentParts[i]) return false;
  }
  return false;
}

Future<UpdateCheckResult> checkForUpdate({
  String currentVersion = kAppVersion,
  Duration timeout = const Duration(seconds: 10),
}) {
  return impl.checkForUpdate(
    currentVersion: currentVersion,
    timeout: timeout,
  );
}
