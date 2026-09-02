// lib/features/home/screens/home_screen.dart
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/history_item.dart';
import '../../../core/providers/history_provider.dart';
import '../../../core/services/file_service.dart';
import '../../../core/services/intent_file_service.dart';
import '../../../core/widgets/app_layout_body.dart';
import '../../../main.dart';
import '../../viewer/providers/viewer_provider.dart';
import '../widgets/history_item_tile.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  StreamSubscription<IntentFile>? _intentSubscription;

  @override
  void initState() {
    super.initState();
    _checkPendingIntent();
    _intentSubscription =
        intentFileService.onFileReceived.listen(_handleIntentFile);
  }

  @override
  void dispose() {
    _intentSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkPendingIntent() async {
    try {
      final intentFile = await intentFileService.getPendingFile();
      if (intentFile != null && mounted) {
        _openIntentFile(intentFile);
      }
    } catch (_) {
      // Platform channel not available (e.g. non-supported platform or tests).
    }
  }

  void _handleIntentFile(IntentFile intentFile) {
    _openIntentFile(intentFile);
  }

  void _openIntentFile(IntentFile intentFile) {
    final fileService = FileService();
    final file = PlatformFile(
      name: intentFile.name,
      path: intentFile.path,
      size: 0,
    );

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      unawaited(
        ref.read(historyProvider.notifier).recordFileOpen(
              fileName: intentFile.name,
              filePath: intentFile.path,
              byteLength: 0,
            ),
      );
    }

    final notifier = ref.read(viewerProvider.notifier);
    notifier.beginLoad(fileName: intentFile.name, filePath: intentFile.path);
    if (mounted) {
      // ACTION_VIEW / external share: replace stack so system back leaves the app.
      context.go('/viewer?name=${Uri.encodeComponent(intentFile.name)}');
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifier.completeLoad(file, fileService);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final historyItems = ref.watch(historyProvider).value ?? const [];
    final hasHistory = isAndroid && historyItems.isNotEmpty;

    if (!hasHistory) {
      return Scaffold(
        appBar: AppBar(
          surfaceTintColor: Colors.transparent,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Settings',
              onPressed: () => context.push('/settings'),
            ),
          ],
        ),
        body: AppLayoutBody(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    isDark
                        ? 'assets/logo/markread_logo_dark.svg'
                        : 'assets/logo/markread_logo.svg',
                    width: 132,
                    height: 72,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Markread',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A clean markdown reader',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: _openFile,
                    icon: const Icon(Icons.file_open),
                    label: const Text('Open File'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear history',
            onPressed: _confirmClearHistory,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openFile,
        icon: const Icon(Icons.file_open),
        label: const Text('Open File'),
      ),
      body: AppLayoutBody(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: 88, // Space for FAB
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight > 96
                      ? constraints.maxHeight - 96
                      : 0,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset(
                            isDark
                                ? 'assets/logo/markread_logo_dark.svg'
                                : 'assets/logo/markread_logo.svg',
                            width: 110,
                            height: 60,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Markread',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'A clean markdown reader',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent Files',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${historyItems.length}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (var i = 0; i < historyItems.length; i++) ...[
                      HistoryItemTile(
                        item: historyItems[i],
                        onTap: () => _openHistoryFile(historyItems[i]),
                        onRemove: () {
                          ref
                              .read(historyProvider.notifier)
                              .removeItem(historyItems[i]);
                        },
                      ),
                      if (i < historyItems.length - 1)
                        Divider(
                          height: 1,
                          indent: 72,
                          endIndent: 16,
                          color: theme.colorScheme.outlineVariant
                              .withValues(alpha: 0.3),
                        ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openFile() async {
    final fileService = FileService();
    final file = await fileService.pickFile();
    if (file == null || !mounted) return;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      unawaited(
        ref.read(historyProvider.notifier).recordFileOpen(
              fileName: file.name,
              filePath: file.path,
              byteLength: file.size,
            ),
      );
    }

    final notifier = ref.read(viewerProvider.notifier);
    notifier.beginLoad(fileName: file.name, filePath: file.path);
    // push keeps Home under the viewer so system/app-bar back works.
    context.push('/viewer?name=${Uri.encodeComponent(file.name)}');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifier.completeLoad(file, fileService);
    });
  }

  Future<void> _openHistoryFile(HistoryItem item) async {
    final fileService = FileService();
    final file = PlatformFile(
      name: item.fileName,
      path: item.filePath,
      size: item.byteLength,
    );

    // Verify file accessibility before attempting navigation
    try {
      await fileService.readFileAsBytes(file);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Could not open '${item.fileName}'. File may have been moved or deleted.",
            ),
            action: SnackBarAction(
              label: 'Remove',
              onPressed: () {
                ref.read(historyProvider.notifier).removeItem(item);
              },
            ),
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    unawaited(
      ref.read(historyProvider.notifier).recordFileOpen(
            fileName: item.fileName,
            filePath: item.filePath,
            byteLength: item.byteLength,
            charOffset: item.charOffset,
          ),
    );

    final notifier = ref.read(viewerProvider.notifier);
    notifier.beginLoad(fileName: item.fileName, filePath: item.filePath);
    context.push('/viewer?name=${Uri.encodeComponent(item.fileName)}');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifier.completeLoad(file, fileService);
    });
  }

  Future<void> _confirmClearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text(
          'Are you sure you want to remove all items from your reading history?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(historyProvider.notifier).clearAll();
    }
  }
}
