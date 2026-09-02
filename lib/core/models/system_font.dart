// lib/core/models/system_font.dart
import 'package:flutter/foundation.dart';

/// Represents a system font available on the device.
@immutable
class SystemFont {
  /// Font family display and identifier name (e.g. 'Noto Serif SC', 'MiSans', 'monospace').
  final String name;

  /// Absolute file path on disk (e.g. '/system/fonts/NotoSerifCJK-Regular.ttc'),
  /// or null if this is a built-in platform alias (e.g. 'serif', 'sans-serif').
  final String? path;

  /// Whether this font provides Chinese / CJK glyph coverage.
  final bool hasChinese;

  /// Whether this font is a monospace / fixed-width typeface (for code font selection).
  final bool isMonospace;

  const SystemFont({
    required this.name,
    this.path,
    this.hasChinese = false,
    this.isMonospace = false,
  });

  /// Creates a [SystemFont] instance from a Map (e.g. from MethodChannel).
  factory SystemFont.fromMap(Map<dynamic, dynamic> map) {
    final rawName = map['name'] as String?;
    final rawPath = map['path'] as String?;
    final name = rawName?.trim() ?? '';
    final path = (rawPath != null && rawPath.trim().isNotEmpty) ? rawPath.trim() : null;
    final hasChinese = map['hasChinese'] as bool? ?? false;
    final isMonospace = map['isMonospace'] as bool? ?? false;

    return SystemFont(
      name: name,
      path: path,
      hasChinese: hasChinese,
      isMonospace: isMonospace,
    );
  }

  /// Converts this [SystemFont] to a Map representation.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'path': path,
      'hasChinese': hasChinese,
      'isMonospace': isMonospace,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SystemFont &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          path == other.path &&
          hasChinese == other.hasChinese &&
          isMonospace == other.isMonospace;

  @override
  int get hashCode => Object.hash(name, path, hasChinese, isMonospace);

  @override
  String toString() =>
      'SystemFont(name: $name, path: $path, hasChinese: $hasChinese, isMonospace: $isMonospace)';
}
