// lib/features/editor/screens/edit_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/preferences_provider.dart';
import '../../../core/widgets/app_layout_body.dart';
import '../../viewer/providers/viewer_provider.dart';

class EditScreen extends ConsumerStatefulWidget {
  final String fileName;

  const EditScreen({super.key, required this.fileName});

  @override
  ConsumerState<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends ConsumerState<EditScreen> {
  late final TextEditingController _controller;
  late final String _initialContent;
  bool _isDirty = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final viewerState = ref.read(viewerProvider).value;
    _initialContent = viewerState?.fileContent ?? '';
    _controller = TextEditingController(text: _initialContent);
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final changed = _controller.text != _initialContent;
    if (changed != _isDirty) {
      setState(() {
        _isDirty = changed;
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<bool> _showDiscardDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard unsaved changes?'),
        content: const Text(
          'You have unsaved changes. Are you sure you want to discard them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _popOrGoHome(GoRouter router) {
    if (router.canPop()) {
      router.pop();
    } else {
      router.go('/');
    }
  }

  Future<void> _handleBack() async {
    final router = GoRouter.of(context);
    if (!_isDirty) {
      _popOrGoHome(router);
      return;
    }

    final discard = await _showDiscardDialog();
    if (!mounted) return;
    if (discard) {
      _popOrGoHome(router);
    }
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    final router = GoRouter.of(context);
    setState(() {
      _isSaving = true;
    });

    try {
      await ref.read(viewerProvider.notifier).saveContent(_controller.text);
      if (mounted) {
        _isDirty = false;
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Saved successfully'),
            duration: Duration(seconds: 2),
          ),
        );
        _popOrGoHome(router);
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preferences = ref.watch(preferencesProvider);
    final viewerState = ref.watch(viewerProvider).value;
    final titleName = (viewerState?.fileName.isNotEmpty ?? false)
        ? viewerState!.fileName
        : widget.fileName;

    final codeFont = preferences.codeFontFamily ?? 'monospace';

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final router = GoRouter.of(context);
        final discard = await _showDiscardDialog();
        if (!mounted) return;
        if (discard) {
          _popOrGoHome(router);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
            onPressed: _handleBack,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titleName,
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'EDIT SOURCE',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _isSaving ? null : _handleSave,
          icon: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: const Text('Save'),
        ),
        body: AppLayoutBody(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: TextField(
              controller: _controller,
              expands: true,
              maxLines: null,
              minLines: null,
              textAlignVertical: TextAlignVertical.top,
              scrollPadding: const EdgeInsets.only(bottom: 80),
              keyboardType: TextInputType.multiline,
              style: TextStyle(
                fontFamily: codeFont,
                fontSize: preferences.fontSize,
                height: preferences.lineHeight,
                color: theme.colorScheme.onSurface,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: 'Enter text...',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
