import 'dart:async';

/// Transforms a character or token stream into buffered text chunks.
class StreamSplitTransformer extends StreamTransformerBase<String, String> {
  const StreamSplitTransformer({
    this.chunkSize = 1,
    this.splitOnWords = false,
  });

  final int chunkSize;
  final bool splitOnWords;

  @override
  Stream<String> bind(Stream<String> stream) async* {
    if (!splitOnWords) {
      await for (final chunk in stream) {
        if (chunk.isEmpty) continue;
        if (chunkSize <= 1) {
          yield chunk;
        } else {
          for (int i = 0; i < chunk.length; i += chunkSize) {
            final end = (i + chunkSize < chunk.length) ? i + chunkSize : chunk.length;
            yield chunk.substring(i, end);
          }
        }
      }
      return;
    }

    // Word-based chunking
    final buffer = StringBuffer();
    await for (final chunk in stream) {
      buffer.write(chunk);
      final text = buffer.toString();
      final lastSpace = text.lastIndexOf(RegExp(r'\s'));
      if (lastSpace != -1) {
        yield text.substring(0, lastSpace + 1);
        buffer.clear();
        buffer.write(text.substring(lastSpace + 1));
      }
    }
    if (buffer.isNotEmpty) {
      yield buffer.toString();
    }
  }
}
