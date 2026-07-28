import 'dart:convert';
import 'dart:io';

import '../app_version.dart';
import 'update_check_service.dart';

Future<UpdateCheckResult> checkForUpdate({
  String currentVersion = kAppVersion,
  Duration timeout = const Duration(seconds: 10),
}) async {
  final client = HttpClient();
  client.connectionTimeout = timeout;

  try {
    final uri = Uri.parse(kGitHubLatestReleaseApiUrl);
    final request = await client.getUrl(uri).timeout(timeout);
    request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
    request.headers.set(HttpHeaders.userAgentHeader, 'Markread');

    final response = await request.close().timeout(timeout);
    final body = await response.transform(utf8.decoder).join().timeout(timeout);

    if (response.statusCode != 200) {
      return UpdateCheckResult(
        status: UpdateCheckStatus.failed,
        errorMessage: 'HTTP ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      return const UpdateCheckResult(
        status: UpdateCheckStatus.failed,
        errorMessage: 'Invalid response',
      );
    }

    final tagName = decoded['tag_name'];
    final htmlUrl = decoded['html_url'];
    if (tagName is! String ||
        tagName.isEmpty ||
        htmlUrl is! String ||
        htmlUrl.isEmpty) {
      return const UpdateCheckResult(
        status: UpdateCheckStatus.failed,
        errorMessage: 'Missing release fields',
      );
    }

    final normalized = normalizeVersion(tagName);
    if (normalized == null) {
      return const UpdateCheckResult(
        status: UpdateCheckStatus.failed,
        errorMessage: 'Invalid remote version',
      );
    }

    final latest = LatestRelease(
      tagName: tagName,
      version: normalized,
      htmlUrl: htmlUrl,
    );

    if (isRemoteNewer(currentVersion, tagName)) {
      return UpdateCheckResult(
        status: UpdateCheckStatus.updateAvailable,
        latest: latest,
      );
    }

    return UpdateCheckResult(
      status: UpdateCheckStatus.upToDate,
      latest: latest,
    );
  } catch (e) {
    return UpdateCheckResult(
      status: UpdateCheckStatus.failed,
      errorMessage: e.toString(),
    );
  } finally {
    client.close(force: true);
  }
}
