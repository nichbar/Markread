// lib/features/home/widgets/history_item_tile.dart
import 'package:flutter/material.dart';
import '../../../core/models/history_item.dart';

class HistoryItemTile extends StatelessWidget {
  final HistoryItem item;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const HistoryItemTile({
    super.key,
    required this.item,
    required this.onTap,
    required this.onRemove,
  });

  IconData _getIconForFileName(String name) {
    final lower = name.toLowerCase();
    final dotIndex = lower.lastIndexOf('.');
    if (dotIndex == -1) return Icons.insert_drive_file_outlined;
    final ext = lower.substring(dotIndex);

    if (const {'.md', '.markdown', '.mdown', '.mkd'}.contains(ext)) {
      return Icons.article_outlined;
    }
    if (const {
      '.dart', '.kt', '.kts', '.java', '.py', '.js', '.ts', '.swift',
      '.go', '.rs', '.c', '.cpp', '.cc', '.cxx', '.h', '.hpp', '.cs',
      '.rb', '.sql', '.yaml', '.yml', '.json', '.xml', '.html', '.css',
      '.sh', '.bash', '.zsh', '.mk', '.toml', '.gradle', '.groovy',
    }.contains(ext)) {
      return Icons.code;
    }
    if (ext == '.txt') {
      return Icons.text_snippet_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final parts = <String>[];
    if (item.formattedSize.isNotEmpty && item.formattedSize != '0 B') {
      parts.add(item.formattedSize);
    }
    parts.add(item.formattedLastOpened());
    if (item.progressPercent > 0) {
      parts.add('${item.progressPercent}% read');
    }
    final subtitleText = parts.join(' • ');

    return Dismissible(
      key: Key('history_dismiss_${item.filePath ?? item.fileName}_${item.lastOpenedMs}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: colorScheme.errorContainer,
        child: Icon(
          Icons.delete_outline,
          color: colorScheme.onErrorContainer,
        ),
      ),
      onDismissed: (_) => onRemove(),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.surfaceContainerHighest,
          child: Icon(
            _getIconForFileName(item.fileName),
            color: colorScheme.primary,
            size: 20,
          ),
        ),
        title: Text(
          item.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitleText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close, size: 18),
          tooltip: 'Remove from history',
          onPressed: onRemove,
        ),
        onTap: onTap,
      ),
    );
  }
}
