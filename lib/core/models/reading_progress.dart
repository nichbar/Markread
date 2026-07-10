// lib/core/models/reading_progress.dart

class ReadingProgress {
  final String fileName;
  final int byteLength;
  final int charOffset;
  final int updatedAtMs;

  const ReadingProgress({
    required this.fileName,
    required this.byteLength,
    required this.charOffset,
    required this.updatedAtMs,
  });

  Map<String, dynamic> toJson() => {
        'fileName': fileName,
        'byteLength': byteLength,
        'charOffset': charOffset,
        'updatedAtMs': updatedAtMs,
      };

  factory ReadingProgress.fromJson(Map<String, dynamic> json) {
    return ReadingProgress(
      fileName: json['fileName'] as String? ?? '',
      byteLength: (json['byteLength'] as num?)?.toInt() ?? 0,
      charOffset: (json['charOffset'] as num?)?.toInt() ?? 0,
      updatedAtMs: (json['updatedAtMs'] as num?)?.toInt() ?? 0,
    );
  }
}
