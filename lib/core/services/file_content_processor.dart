import 'dart:convert';
import 'dart:typed_data';

import 'file_service.dart';

/// Isolate-sendable view mode (maps to viewer ViewMode on UI isolate).
enum ProcessedViewMode { rendered, raw }

class ProcessedHeading {
  final String text;
  final int level;
  final int offset;

  const ProcessedHeading({
    required this.text,
    required this.level,
    required this.offset,
  });
}

/// Plain data only — safe for Isolate.run return values.
class ProcessedFileContent {
  final String fileName;
  final String fileContent;
  final bool isSourceCode;
  final String? codeLanguage;
  final bool isBinary;
  final ProcessedViewMode viewMode;
  final String? warningMessage;
  final List<ProcessedHeading> headings;

  const ProcessedFileContent({
    required this.fileName,
    required this.fileContent,
    required this.isSourceCode,
    required this.codeLanguage,
    required this.isBinary,
    required this.viewMode,
    required this.warningMessage,
    required this.headings,
  });
}

/// Top-level entry for Isolate.run / unit tests.
ProcessedFileContent processFileContent({
  required String fileName,
  required Uint8List bytes,
}) {
  final fileService = FileService();
  // Prefer STRICT utf8.decode to match existing FileService/notifier behavior
  // (do NOT use allowMalformed: true unless tests require it).
  final content = utf8.decode(bytes);

  final isMarkdown = fileService.isMarkdownFile(fileName);
  String? codeLanguage;
  var isSourceCode = false;

  if (!isMarkdown) {
    codeLanguage = fileService.detectLanguage(fileName);
    if (codeLanguage != null) {
      isSourceCode = true;
    }
  }

  final isBinary = fileService.isProbablyBinary(content);
  var viewMode = ProcessedViewMode.rendered;
  String? warningMessage;
  List<ProcessedHeading> headings = const [];

  if (isBinary) {
    viewMode = ProcessedViewMode.raw;
    warningMessage =
        'This file looks binary or malformed. Showing raw text.';
  } else if (isSourceCode) {
    viewMode = ProcessedViewMode.rendered;
  } else {
    headings = parseHeadings(content);
  }

  return ProcessedFileContent(
    fileName: fileName,
    fileContent: content,
    isSourceCode: isSourceCode,
    codeLanguage: codeLanguage,
    isBinary: isBinary,
    viewMode: viewMode,
    warningMessage: warningMessage,
    headings: headings,
  );
}

List<ProcessedHeading> parseHeadings(String markdown) {
  final headings = <ProcessedHeading>[];
  final lines = markdown.split('\n');
  var offset = 0;
  for (final line in lines) {
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('#')) {
      final level = trimmed.indexOf(' ');
      if (level >= 1 && level <= 3) {
        final text = trimmed.substring(level + 1).trim();
        if (text.isNotEmpty) {
          headings.add(ProcessedHeading(
            text: text,
            level: level,
            offset: offset,
          ));
        }
      }
    }
    offset += line.length + 1;
  }
  return headings;
}
