// lib/features/home/screens/home_screen.dart
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/file_service.dart';
import '../../../core/services/intent_file_service.dart';
import '../../../core/widgets/app_layout_body.dart';
import '../../../main.dart';
import '../../viewer/providers/viewer_provider.dart';

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
    _intentSubscription = intentFileService.onFileReceived.listen(_handleIntentFile);
  }

  @override
  void dispose() {
    _intentSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkPendingIntent() async {
    final intentFile = await intentFileService.getPendingFile();
    if (intentFile != null && mounted) {
      _openIntentFile(intentFile);
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
    ref.read(viewerProvider.notifier).loadFile(file, fileService);
    if (mounted) {
      context.go('/viewer?name=${Uri.encodeComponent(intentFile.name)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        title: const Text('MarkRead'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
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
              Icon(
                Icons.auto_stories,
                size: 80,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'MarkRead',
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
                onPressed: () => _openFile(),
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

  Future<void> _openFile() async {
    final fileService = FileService();
    final file = await fileService.pickFile();
    if (file == null) return;

    if (mounted) {
      ref.read(viewerProvider.notifier).loadFile(file, fileService);
      context.go('/viewer?name=${Uri.encodeComponent(file.name)}');
    }
  }
}
