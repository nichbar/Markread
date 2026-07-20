/// Grammar-safe markdown block splitter for virtualized rendering.
///
/// Splits display content into [MarkdownBlock]s that respect gpt_markdown's
/// multi-line atomic constructs (fences, quotes, tables, display math) while
/// emitting one block per heading / list item / paragraph run so
/// [ListView.builder] can mount only the viewport.
library;

/// One virtualized markdown chunk with offsets into the (normalized) source.
class MarkdownBlock {
  /// Exact substring of the normalized display content.
  final String text;

  /// Inclusive start offset in the normalized input.
  final int startOffset;

  /// Exclusive end offset in the normalized input.
  final int endOffset;

  /// Global H1–H3 index matching [parseHeadings] order, if this block is one.
  final int? headingIndex;

  /// Whether one or more blank lines preceded this block at the top level.
  ///
  /// Matches gpt_markdown's [NewLines] behavior: any `\n\n+` collapses to a
  /// single paragraph gap. Leading blanks (before first content) are ignored.
  final bool hasPrecedingParagraphBreak;

  const MarkdownBlock({
    required this.text,
    required this.startOffset,
    required this.endOffset,
    this.headingIndex,
    this.hasPrecedingParagraphBreak = false,
  });

  @override
  String toString() =>
      'MarkdownBlock(start=$startOffset, end=$endOffset, '
      'headingIndex=$headingIndex, break=$hasPrecedingParagraphBreak, '
      'text=${text.length > 40 ? '${text.substring(0, 40)}…' : text})';
}

class _Line {
  final String content;
  final int start;
  final int endExclusive; // past last char of content (before \n if any)

  const _Line(this.content, this.start, this.endExclusive);

  String get trimmedLeft => content.trimLeft();
  bool get isBlank => content.trim().isEmpty;
}

/// Split [input] into grammar-safe blocks for virtualized markdown rendering.
///
/// Newlines are normalized to `\n` first; all offsets refer to that normalized
/// string. Does not full-document-trim (preserves offset fidelity).
List<MarkdownBlock> splitMarkdownBlocks(String input) {
  final text = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  if (text.isEmpty) return const [];

  final lines = _splitLines(text);
  if (lines.isEmpty) return const [];

  final blocks = <MarkdownBlock>[];
  var headingCounter = 0;
  var i = 0;
  // Consecutive top-level blank lines before the next content block.
  // Leading blanks are ignored (matches GptMarkdown(...).trim()).
  var blankCount = 0;
  var emittedAny = false;

  while (i < lines.length) {
    final line = lines[i];

    if (line.isBlank) {
      if (emittedAny) blankCount++;
      i++;
      continue;
    }

    // Only top-level blanks between content contribute to the gap flag.
    // Monolith NewLines collapses any \n\n+ to a single gap.
    final hasPrecedingBreak = emittedAny && blankCount >= 1;
    blankCount = 0;

    // Fenced code: open ``` … close ```
    if (_isFenceLine(line)) {
      var j = i + 1;
      while (j < lines.length && !_isFenceLine(lines[j])) {
        j++;
      }
      if (j < lines.length) j++; // include closing fence
      _emitRange(
        blocks: blocks,
        lines: lines,
        text: text,
        from: i,
        toExclusive: j,
        headingIndex: null,
        hasPrecedingParagraphBreak: hasPrecedingBreak,
      );
      emittedAny = true;
      i = j;
      continue;
    }

    // Block quote run
    if (_isQuoteLine(line)) {
      var j = i + 1;
      while (j < lines.length && _isQuoteLine(lines[j])) {
        j++;
      }
      _emitRange(
        blocks: blocks,
        lines: lines,
        text: text,
        from: i,
        toExclusive: j,
        headingIndex: null,
        hasPrecedingParagraphBreak: hasPrecedingBreak,
      );
      emittedAny = true;
      i = j;
      continue;
    }

    // Table run (pipe rows)
    if (_isTableRow(line)) {
      var j = i + 1;
      while (j < lines.length && _isTableRow(lines[j])) {
        j++;
      }
      _emitRange(
        blocks: blocks,
        lines: lines,
        text: text,
        from: i,
        toExclusive: j,
        headingIndex: null,
        hasPrecedingParagraphBreak: hasPrecedingBreak,
      );
      emittedAny = true;
      i = j;
      continue;
    }

    // Display math \[ … \]
    if (_isMathStart(line)) {
      var j = i;
      if (!_isMathEnd(line)) {
        j = i + 1;
        while (j < lines.length && !_isMathEnd(lines[j])) {
          j++;
        }
      }
      if (j < lines.length) j++; // include end line
      _emitRange(
        blocks: blocks,
        lines: lines,
        text: text,
        from: i,
        toExclusive: j,
        headingIndex: null,
        hasPrecedingParagraphBreak: hasPrecedingBreak,
      );
      emittedAny = true;
      i = j;
      continue;
    }

    // Single-line structured blocks
    final headingIndex = _headingIndexIfAny(line, headingCounter);
    if (headingIndex != null) {
      headingCounter = headingIndex + 1;
      _emitRange(
        blocks: blocks,
        lines: lines,
        text: text,
        from: i,
        toExclusive: i + 1,
        headingIndex: headingIndex,
        hasPrecedingParagraphBreak: hasPrecedingBreak,
      );
      emittedAny = true;
      i++;
      continue;
    }

    if (_isAtxHeading(line) ||
        _isOrderedItem(line) ||
        _isUnorderedItem(line) ||
        _isHrLine(line) ||
        _isCheckboxLine(line) ||
        _isRadioLine(line)) {
      _emitRange(
        blocks: blocks,
        lines: lines,
        text: text,
        from: i,
        toExclusive: i + 1,
        headingIndex: null,
        hasPrecedingParagraphBreak: hasPrecedingBreak,
      );
      emittedAny = true;
      i++;
      continue;
    }

    // Plain paragraph: merge consecutive non-blank, non-block lines.
    var j = i + 1;
    while (j < lines.length &&
        !lines[j].isBlank &&
        !_isBlockStart(lines[j])) {
      j++;
    }
    _emitRange(
      blocks: blocks,
      lines: lines,
      text: text,
      from: i,
      toExclusive: j,
      headingIndex: null,
      hasPrecedingParagraphBreak: hasPrecedingBreak,
    );
    emittedAny = true;
    i = j;
  }

  return blocks;
}

List<_Line> _splitLines(String text) {
  final lines = <_Line>[];
  var start = 0;
  for (var i = 0; i < text.length; i++) {
    if (text.codeUnitAt(i) == 0x0A) {
      // \n
      lines.add(_Line(text.substring(start, i), start, i));
      start = i + 1;
    }
  }
  // Final line (possibly empty when text ends with \n — still track it).
  if (start < text.length || text.isEmpty) {
    lines.add(_Line(text.substring(start), start, text.length));
  } else if (start == text.length && text.endsWith('\n')) {
    // Trailing empty line after final newline.
    lines.add(_Line('', start, text.length));
  }
  return lines;
}

void _emitRange({
  required List<MarkdownBlock> blocks,
  required List<_Line> lines,
  required String text,
  required int from,
  required int toExclusive,
  required int? headingIndex,
  bool hasPrecedingParagraphBreak = false,
}) {
  if (from >= toExclusive || from < 0 || toExclusive > lines.length) return;
  final start = lines[from].start;
  final end = lines[toExclusive - 1].endExclusive;
  // Prefer including a single trailing newline when present so chunk boundaries
  // stay close to source layout; GptMarkdown trims edge whitespace per chunk.
  final endWithNl =
      end < text.length && text.codeUnitAt(end) == 0x0A ? end + 1 : end;
  final slice = text.substring(start, endWithNl);
  if (slice.trim().isEmpty) return;
  blocks.add(
    MarkdownBlock(
      text: slice,
      startOffset: start,
      endOffset: endWithNl,
      headingIndex: headingIndex,
      hasPrecedingParagraphBreak: hasPrecedingParagraphBreak,
    ),
  );
}

bool _isBlockStart(_Line line) {
  return _isFenceLine(line) ||
      _isQuoteLine(line) ||
      _isTableRow(line) ||
      _isMathStart(line) ||
      _isAtxHeading(line) ||
      _isOrderedItem(line) ||
      _isUnorderedItem(line) ||
      _isHrLine(line) ||
      _isCheckboxLine(line) ||
      _isRadioLine(line);
}

bool _isFenceLine(_Line line) {
  return line.trimmedLeft.startsWith('```');
}

bool _isQuoteLine(_Line line) {
  // Match gpt_markdown BlockQuote: optional spaces then >
  return RegExp(r'^\s*>').hasMatch(line.content);
}

bool _isTableRow(_Line line) {
  final t = line.content.trim();
  if (t.isEmpty) return false;
  // Pipe table rows used by TableMd: start with | and contain another |
  if (!t.startsWith('|')) return false;
  return t.indexOf('|', 1) >= 1;
}

bool _isMathStart(_Line line) => line.content.contains(r'\[');

bool _isMathEnd(_Line line) => line.content.contains(r'\]');

bool _isAtxHeading(_Line line) {
  final t = line.trimmedLeft;
  if (!t.startsWith('#')) return false;
  final space = t.indexOf(' ');
  return space >= 1 && space <= 6;
}

/// Returns the next heading index when this line is an H1–H3 with non-empty
/// title (mirrors [parseHeadings]); otherwise null.
int? _headingIndexIfAny(_Line line, int nextIndex) {
  final t = line.trimmedLeft;
  if (!t.startsWith('#')) return null;
  final level = t.indexOf(' ');
  if (level < 1 || level > 3) return null;
  final title = t.substring(level + 1).trim();
  if (title.isEmpty) return null;
  return nextIndex;
}

bool _isOrderedItem(_Line line) {
  // gpt_markdown: ([0-9]+)\.\ ([^\n]+)$
  return RegExp(r'^\s*\d+\.\s+\S').hasMatch(line.content);
}

bool _isUnorderedItem(_Line line) {
  // gpt_markdown: (?:\-|\*)\ ([^\n]+)$
  return RegExp(r'^\s*[-*]\s+\S').hasMatch(line.content);
}

bool _isHrLine(_Line line) {
  final t = line.content.trim();
  if (t == '⸻') return true;
  return RegExp(r'^--[-]+$').hasMatch(t);
}

bool _isCheckboxLine(_Line line) {
  // [x] / [ ] title
  return RegExp(r'^\s*\[[ x]\]\s+\S').hasMatch(line.content);
}

bool _isRadioLine(_Line line) {
  // (x) / ( ) title
  return RegExp(r'^\s*\([ x]\)\s+\S').hasMatch(line.content);
}
