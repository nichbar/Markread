import '../app_version.dart';
import 'update_check_service.dart';

Future<UpdateCheckResult> checkForUpdate({
  String currentVersion = kAppVersion,
  Duration timeout = const Duration(seconds: 10),
}) async {
  return const UpdateCheckResult(status: UpdateCheckStatus.unsupported);
}
