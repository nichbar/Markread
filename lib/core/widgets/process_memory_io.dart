// VM process RSS sampler (Android/iOS/desktop). Avoids unconditional dart:io
// in files that may be compiled for web.
import 'dart:io';

/// Current process resident set size in bytes, or null if unavailable.
int? sampleProcessRssBytes() {
  try {
    return ProcessInfo.currentRss;
  } catch (_) {
    return null;
  }
}
