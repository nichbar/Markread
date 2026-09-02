// lib/core/services/file_io_helper_stub.dart

/// Web & non-IO stub implementation of file writing.
class FileIoHelper {
  const FileIoHelper._();

  /// Throws unsupported error on Web / platforms without direct file system access.
  static Future<void> writeStringToFile(String path, String content) async {
    throw UnsupportedError('File writing is not supported on this platform');
  }
}
