// lib/core/providers/reading_progress_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/reading_progress_service.dart';

final readingProgressProvider = Provider<ReadingProgressService>(
  (ref) => ReadingProgressService(),
);
