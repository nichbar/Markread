// lib/core/services/file_service.dart
import 'dart:convert';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'file_io_helper.dart';

/// Thrown when an Android SAF URI cannot be written to because it is read-only
/// or write permissions were not granted by the originating app.
class ReadOnlyFileException implements Exception {
  final String message;
  const ReadOnlyFileException([this.message = 'The opened file is read-only.']);

  @override
  String toString() => 'ReadOnlyFileException: $message';
}

class FileService {
  static const _markdownExtensions = {'.md', '.markdown', '.mdown', '.mkd', '.txt'};

  static const _languageMap = {
    '.dart': 'dart',
    '.kt': 'kotlin',
    '.kts': 'kotlin',
    '.java': 'java',
    '.py': 'python',
    '.js': 'javascript',
    '.ts': 'typescript',
    '.swift': 'swift',
    '.go': 'go',
    '.rs': 'rust',
    '.c': 'c',
    '.cpp': 'cpp',
    '.cc': 'cpp',
    '.cxx': 'cpp',
    '.h': 'c',
    '.hpp': 'cpp',
    '.cs': 'csharp',
    '.rb': 'ruby',
    '.sql': 'sql',
    '.yaml': 'yaml',
    '.yml': 'yaml',
    '.json': 'json',
    '.xml': 'xml',
    '.html': 'html',
    '.css': 'css',
    '.sh': 'bash',
    '.bash': 'bash',
    '.zsh': 'bash',
    '.mk': 'makefile',
    '.toml': 'toml',
    '.tex': 'latex',
    '.gradle': 'groovy',
    '.groovy': 'groovy',
    '.scala': 'scala',
    '.svg': 'markup',
  };

  static const _channel = MethodChannel('now.link.markread/files');

  Future<PlatformFile?> pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;
    return result.files.first;
  }

  Future<Uint8List> readFileAsBytes(PlatformFile file) async {
    // 1. On Android, if an identifier (content:// URI) is available, try reading directly
    // to ensure live content from the external storage document is loaded.
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        file.identifier != null &&
        file.identifier!.startsWith('content://')) {
      try {
        final bytes = await readFileFromUri(file.identifier!);
        // Also refresh cached copy if path is present so cache stays consistent
        if (file.path != null && !file.path!.startsWith('content://')) {
          try {
            await FileIoHelper.writeBytesToFile(file.path!, bytes);
          } catch (_) {}
        }
        return bytes;
      } catch (_) {
        // Fall back to local cached copy or in-memory bytes if URI read fails
      }
    }

    if (file.bytes != null) {
      return file.bytes is Uint8List
          ? file.bytes as Uint8List
          : Uint8List.fromList(file.bytes!);
    }
    if (file.path != null) {
      final xfile = XFile(file.path!);
      return xfile.readAsBytes();
    }
    throw Exception('Unable to read file: no path or bytes available');
  }

  Future<String> readFileBytes(PlatformFile file) async {
    final bytes = await readFileAsBytes(file);
    return utf8.decode(bytes);
  }

  /// Takes persistable URI permission on Android Storage Access Framework URIs.
  Future<bool> takePersistableUriPermission(String uri) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final result = await _channel.invokeMethod<bool>(
        'takePersistableUriPermission',
        {'uri': uri},
      );
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Reads bytes from an Android SAF content:// URI via ContentResolver.
  Future<Uint8List> readFileFromUri(String uri) async {
    final result = await _channel.invokeMethod<Uint8List>(
      'readFileFromUri',
      {'uri': uri},
    );
    if (result == null) {
      throw Exception('Failed to read bytes from URI: $uri');
    }
    return result;
  }

  /// Saves content back to the original file.
  /// If [uri] is an Android content:// URI, writes through SAF ContentResolver.
  /// If [path] is present, updates the file or local cached copy.
  Future<void> saveFile({
    String? path,
    String? uri,
    required String content,
  }) async {
    final isAndroidSaf = !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        uri != null &&
        uri.startsWith('content://');

    if (isAndroidSaf) {
      try {
        await _channel.invokeMethod('saveContentToUri', {
          'uri': uri,
          'content': content,
        });
      } on PlatformException catch (e) {
        if (e.code == 'PERMISSION_DENIED') {
          throw ReadOnlyFileException(
            e.message ?? 'Permission denied when writing to file.',
          );
        }
        rethrow;
      }
    } else if (path != null && path.isNotEmpty) {
      await FileIoHelper.writeStringToFile(path, content);
    }

    // Keep cached local copy in sync if a separate local path exists
    if (path != null &&
        path.isNotEmpty &&
        !path.startsWith('content://') &&
        isAndroidSaf) {
      try {
        await FileIoHelper.writeStringToFile(path, content);
      } catch (_) {}
    }
  }

  Future<void> writeFile(String path, String content) async {
    await saveFile(path: path, content: content);
  }

  bool isMarkdownFile(String fileName) {
    final ext = fileName.toLowerCase();
    final dotIndex = ext.lastIndexOf('.');
    if (dotIndex == -1) return false;
    return _markdownExtensions.contains(ext.substring(dotIndex));
  }

  String? detectLanguage(String fileName) {
    final ext = fileName.toLowerCase();
    final dotIndex = ext.lastIndexOf('.');
    if (dotIndex == -1) return null;
    return _languageMap[ext.substring(dotIndex)];
  }

  /// Checks if text appears to be binary content.
  /// Returns true if the text contains null characters or has a high ratio
  /// of non-printable characters.
  bool isProbablyBinary(String text) {
    if (text.contains('\u0000')) return true;
    final sample = text.length > 2000 ? text.substring(0, 2000) : text;
    if (sample.isEmpty) return false;
    final nonPrintable =
        sample.codeUnits.where((c) => c < 32 && c != 10 && c != 13 && c != 9).length;
    return nonPrintable > sample.length / 20;
  }
}
