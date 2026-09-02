// lib/core/services/file_io_helper_io.dart
import 'dart:io';

/// Mobile/Desktop IO implementation of file writing.
class FileIoHelper {
  const FileIoHelper._();

  static Future<void> writeStringToFile(String path, String content) async {
    final file = File(path);
    await file.writeAsString(content, flush: true);
  }
}
