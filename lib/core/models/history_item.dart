// lib/core/models/history_item.dart

class HistoryItem {
  final String fileName;
  final String? filePath;
  final int byteLength;
  final int lastOpenedMs;
  final int charOffset;

  const HistoryItem({
    required this.fileName,
    this.filePath,
    this.byteLength = 0,
    required this.lastOpenedMs,
    this.charOffset = 0,
  });

  /// Formatted human-readable file size (e.g. "512 B", "45.2 KB", "1.4 MB").
  String get formattedSize {
    if (byteLength <= 0) return '0 B';
    if (byteLength < 1024) return '$byteLength B';
    if (byteLength < 1024 * 1024) {
      return '${(byteLength / 1024).toStringAsFixed(1)} KB';
    }
    if (byteLength < 1024 * 1024 * 1024) {
      return '${(byteLength / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(byteLength / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Relative formatted time (e.g. "Just now", "5m ago", "2h ago", "Yesterday", "3d ago", "2026-08-15").
  String formattedLastOpened([DateTime? nowOverride]) {
    final now = nowOverride ?? DateTime.now();
    final openedAt = DateTime.fromMillisecondsSinceEpoch(lastOpenedMs);
    final diff = now.difference(openedAt);

    if (diff.isNegative || diff.inMinutes < 1) {
      return 'Just now';
    }
    if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    }
    if (diff.inDays == 1) {
      return 'Yesterday';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    }

    final year = openedAt.year.toString();
    final month = openedAt.month.toString().padLeft(2, '0');
    final day = openedAt.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Progress percentage (0 - 100) based on character offset and byte length.
  int get progressPercent {
    if (byteLength <= 0 || charOffset <= 0) return 0;
    return (charOffset / byteLength * 100).round().clamp(0, 100);
  }

  Map<String, dynamic> toJson() => {
        'fileName': fileName,
        'filePath': filePath,
        'byteLength': byteLength,
        'lastOpenedMs': lastOpenedMs,
        'charOffset': charOffset,
      };

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      fileName: json['fileName'] as String? ?? '',
      filePath: json['filePath'] as String?,
      byteLength: (json['byteLength'] as num?)?.toInt() ?? 0,
      lastOpenedMs: (json['lastOpenedMs'] as num?)?.toInt() ?? 0,
      charOffset: (json['charOffset'] as num?)?.toInt() ?? 0,
    );
  }

  HistoryItem copyWith({
    String? fileName,
    String? filePath,
    bool clearFilePath = false,
    int? byteLength,
    int? lastOpenedMs,
    int? charOffset,
  }) {
    return HistoryItem(
      fileName: fileName ?? this.fileName,
      filePath: clearFilePath ? null : (filePath ?? this.filePath),
      byteLength: byteLength ?? this.byteLength,
      lastOpenedMs: lastOpenedMs ?? this.lastOpenedMs,
      charOffset: charOffset ?? this.charOffset,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HistoryItem &&
          runtimeType == other.runtimeType &&
          fileName == other.fileName &&
          filePath == other.filePath &&
          byteLength == other.byteLength &&
          lastOpenedMs == other.lastOpenedMs &&
          charOffset == other.charOffset;

  @override
  int get hashCode =>
      fileName.hashCode ^
      filePath.hashCode ^
      byteLength.hashCode ^
      lastOpenedMs.hashCode ^
      charOffset.hashCode;
}
