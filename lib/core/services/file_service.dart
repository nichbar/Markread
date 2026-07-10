// lib/core/services/file_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';

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

  Future<PlatformFile?> pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;
    return result.files.first;
  }

  Future<Uint8List> readFileAsBytes(PlatformFile file) async {
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
