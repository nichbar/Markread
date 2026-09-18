// lib/features/viewer/services/markdown_checkbox_helper.dart

/// Information about a detected markdown task-list checkbox.
class MarkdownCheckboxInfo {
  /// Zero-based sequential index matching reader parse order.
  final int index;

  /// Zero-based line number in the source text where this checkbox appears.
  final int lineIndex;

  /// Character offset in the source text pointing to the `[` opening bracket.
  final int bracketOffset;

  /// Whether the checkbox is currently checked (`[x]` or `[X]`).
  final bool isChecked;

  /// The entire line text containing the checkbox.
  final String lineText;

  const MarkdownCheckboxInfo({
    required this.index,
    required this.lineIndex,
    required this.bracketOffset,
    required this.isChecked,
    required this.lineText,
  });

  @override
  String toString() =>
      'MarkdownCheckboxInfo(index=$index, line=$lineIndex, offset=$bracketOffset, checked=$isChecked)';
}

/// Helper service for scanning, indexing, and toggling markdown checkboxes.
class MarkdownCheckboxHelper {
  static const String checkboxTagStart = '\uE003';
  static const String checkboxTagEnd = '\uE004';

  /// Matches a task list item or standalone checkbox at the beginning of a line.
  /// Group 1: Leading indentation, blockquote markers (`>`), and bullet/number list markers.
  /// Group 2: The checkbox state character (` ` or `x` or `X`).
  static final RegExp _checkboxLinePattern = RegExp(
    r'^(\s*(?:>\s*)*(?:[-*+]|\d+\.)\s+|\s*(?:>\s*)*)\[([ xX])\](?:\s|$)',
  );

  /// Tags each detected checkbox in [content] with `\uE003{index}\uE004` directly before `[`.
  static String tagCheckboxes(String content) {
    final checkboxes = findCheckboxes(content);
    if (checkboxes.isEmpty) return content;

    final buffer = StringBuffer();
    var lastOffset = 0;

    for (final cb in checkboxes) {
      final offset = cb.bracketOffset;
      if (offset < lastOffset || offset > content.length) continue;

      buffer.write(content.substring(lastOffset, offset));
      buffer.write('$checkboxTagStart${cb.index}$checkboxTagEnd');
      lastOffset = offset;
    }

    buffer.write(content.substring(lastOffset));
    return buffer.toString();
  }

  /// Removes all checkbox tags `\uE003{index}\uE004` from [content].
  static String stripCheckboxTags(String content) {
    return content.replaceAll(
      RegExp('$checkboxTagStart\\d+$checkboxTagEnd'),
      '',
    );
  }

  /// Scans [content] and returns all checkboxes in document order.
  /// Checkboxes inside fenced code blocks (``` or ~~~) are excluded.
  static List<MarkdownCheckboxInfo> findCheckboxes(String content) {
    if (content.isEmpty) return const [];

    final result = <MarkdownCheckboxInfo>[];
    var lineIndex = 0;
    var inFence = false;
    String? fenceMarker;

    var i = 0;
    while (i < content.length) {
      final lineStart = i;
      while (i < content.length &&
          content.codeUnitAt(i) != 0x0A &&
          content.codeUnitAt(i) != 0x0D) {
        i++;
      }
      final lineEnd = i;
      // Handle \r\n or \n or \r
      if (i < content.length && content.codeUnitAt(i) == 0x0D) {
        i++;
        if (i < content.length && content.codeUnitAt(i) == 0x0A) {
          i++;
        }
      } else if (i < content.length && content.codeUnitAt(i) == 0x0A) {
        i++;
      }

      final lineContent = content.substring(lineStart, lineEnd);
      final trimmedLeft = lineContent.trimLeft();

      // Check for code fence start/end
      if (trimmedLeft.startsWith('```') || trimmedLeft.startsWith('~~~')) {
        final marker = trimmedLeft.substring(0, 3);
        if (!inFence) {
          inFence = true;
          fenceMarker = marker;
        } else if (marker == fenceMarker) {
          inFence = false;
          fenceMarker = null;
        }
      } else if (!inFence) {
        final match = _checkboxLinePattern.firstMatch(lineContent);
        if (match != null) {
          final prefix = match.group(1) ?? '';
          final stateChar = match.group(2) ?? ' ';
          final bracketOffset = lineStart + prefix.length;
          final isChecked = stateChar.toLowerCase() == 'x';

          result.add(
            MarkdownCheckboxInfo(
              index: result.length,
              lineIndex: lineIndex,
              bracketOffset: bracketOffset,
              isChecked: isChecked,
              lineText: lineContent,
            ),
          );
        }
      }

      lineIndex++;
    }

    return result;
  }

  /// Counts the number of checkboxes in a list of lines, assuming they are not in a code fence.
  static int countCheckboxesInLines(List<String> lines) {
    var count = 0;
    for (final line in lines) {
      if (_checkboxLinePattern.hasMatch(line)) {
        count++;
      }
    }
    return count;
  }

  /// Toggles the checkbox at [targetIndex] in [content] to [newValue].
  ///
  /// Returns the modified content if successful. If [targetIndex] is out of bounds
  /// or the characters at the target offset are not a checkbox bracket (`[ ]`, `[x]`, `[X]`),
  /// returns [content] unmodified.
  static String toggleCheckbox(
    String content, {
    required int targetIndex,
    required bool newValue,
  }) {
    final checkboxes = findCheckboxes(content);
    if (targetIndex < 0 || targetIndex >= checkboxes.length) {
      return content;
    }

    final target = checkboxes[targetIndex];
    final offset = target.bracketOffset;

    if (offset + 3 > content.length) {
      return content;
    }

    final targetBracket = content.substring(offset, offset + 3);
    if (targetBracket != '[ ]' &&
        targetBracket != '[x]' &&
        targetBracket != '[X]') {
      return content;
    }

    final replacement = newValue ? '[x]' : '[ ]';
    return content.replaceRange(offset, offset + 3, replacement);
  }
}
