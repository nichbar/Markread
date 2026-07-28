// lib/features/settings/screens/settings_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/app_version.dart';
import '../../../core/models/user_preferences.dart';
import '../../../core/providers/preferences_provider.dart';
import '../../../core/services/update_check_service.dart';
import '../../../core/widgets/app_layout_body.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _checkingForUpdate = false;

  bool get _canCheckForUpdates =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(preferencesProvider);

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: const Text('Settings'),
      ),
      body: AppLayoutBody(
        child: ListView(
        children: [
          // -- Appearance --
          _SectionHeader(title: 'Appearance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<AppThemeMode>(
              segments: const [
                ButtonSegment(
                    value: AppThemeMode.system, label: Text('System')),
                ButtonSegment(
                    value: AppThemeMode.light, label: Text('Light')),
                ButtonSegment(value: AppThemeMode.dark, label: Text('Dark')),
              ],
              selected: {prefs.appThemeMode},
              onSelectionChanged: (selected) {
                ref
                    .read(preferencesProvider.notifier)
                    .setAppThemeMode(selected.first);
              },
            ),
          ),

          const Divider(),

          // -- Reader --
          _SectionHeader(title: 'Reader'),
          _buildDropdownTile(
            label: 'Markdown theme',
            value: prefs.markdownTheme,
            items: MarkdownTheme.values,
            display: _displayMarkdownTheme,
            onChanged: (v) =>
                ref.read(preferencesProvider.notifier).setMarkdownTheme(v),
          ),
          _buildDropdownTile(
            label: 'Render mode',
            value: prefs.markdownRenderMode,
            items: MarkdownRenderMode.values,
            display: _displayMarkdownRenderMode,
            onChanged: (v) => ref
                .read(preferencesProvider.notifier)
                .setMarkdownRenderMode(v),
          ),

          // -- Font Size --
          _SectionHeader(title: 'Font Size'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('Aa', style: TextStyle(fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: prefs.fontSize,
                    min: 12,
                    max: 24,
                    divisions: 12,
                    label: '${prefs.fontSize.round()}',
                    onChanged: (value) {
                      ref
                          .read(preferencesProvider.notifier)
                          .setFontSize(value);
                    },
                  ),
                ),
                const Text('Aa',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Center(
            child: Text(
              '${prefs.fontSize.round()} sp',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),

          // -- Line Height --
          _SectionHeader(title: 'Line Height'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('1.2'),
                Expanded(
                  child: Slider(
                    value: prefs.lineHeight,
                    min: 1.2,
                    max: 2.0,
                    divisions: 8,
                    label: prefs.lineHeight.toStringAsFixed(1),
                    onChanged: (value) {
                      ref
                          .read(preferencesProvider.notifier)
                          .setLineHeight(value);
                    },
                  ),
                ),
                const Text('2.0'),
              ],
            ),
          ),
          Center(
            child: Text(
              '${prefs.lineHeight.toStringAsFixed(1)}x',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),

          // -- Text Alignment --
          _SectionHeader(title: 'Text Alignment'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<ReadingTextAlign>(
              segments: const [
                ButtonSegment(
                    value: ReadingTextAlign.left, label: Text('Left')),
                ButtonSegment(
                    value: ReadingTextAlign.justified,
                    label: Text('Justified')),
              ],
              selected: {prefs.textAlignment},
              onSelectionChanged: (selected) {
                ref
                    .read(preferencesProvider.notifier)
                    .setTextAlignment(selected.first);
              },
            ),
          ),

          const Divider(),

          // -- About --
          _SectionHeader(title: 'About'),
          const ListTile(
            title: Text('Markread'),
            subtitle: Text('A minimal, read-only Markdown reader.'),
          ),
          ListTile(
            title: const Text('Version'),
            subtitle: const Text(kAppVersion),
            trailing: _canCheckForUpdates
                ? (_checkingForUpdate
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.system_update_alt))
                : null,
            onTap: _canCheckForUpdates ? _checkForUpdate : null,
          ),
          ListTile(
            title: const Text('Source code'),
            subtitle: const Text('github.com/nichbar/Markread'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _openGitHubRepo(context),
          ),
          const SizedBox(height: 32),
        ],
      ),
      ),
    );
  }

  Future<void> _checkForUpdate() async {
    if (_checkingForUpdate) return;

    setState(() => _checkingForUpdate = true);
    final result = await checkForUpdate();
    if (!mounted) return;
    setState(() => _checkingForUpdate = false);

    switch (result.status) {
      case UpdateCheckStatus.upToDate:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("You're up to date (v$kAppVersion)")),
        );
      case UpdateCheckStatus.updateAvailable:
        final latest = result.latest;
        if (latest == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not check for updates')),
          );
          return;
        }
        await _showUpdateAvailableDialog(latest);
      case UpdateCheckStatus.failed:
      case UpdateCheckStatus.unsupported:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not check for updates')),
        );
    }
  }

  Future<void> _showUpdateAvailableDialog(LatestRelease latest) async {
    final shouldDownload = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Update available'),
          content: Text(
            'A newer version is available.\n\n'
            'Current: v$kAppVersion\n'
            'Latest: v${latest.version}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Download'),
            ),
          ],
        );
      },
    );

    if (shouldDownload != true || !mounted) return;
    await _openReleasePage(latest.htmlUrl);
  }

  Future<void> _openReleasePage(String htmlUrl) async {
    final uri = Uri.tryParse(htmlUrl);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open release page')),
      );
      return;
    }

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open release page')),
      );
    }
  }

  Future<void> _openGitHubRepo(BuildContext context) async {
    final uri = Uri.parse(kGitHubRepoUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open GitHub repository')),
      );
    }
  }

  String _displayMarkdownTheme(MarkdownTheme t) => switch (t) {
        MarkdownTheme.standard => 'Default',
        MarkdownTheme.github => 'GitHub',
        MarkdownTheme.blueTopaz => 'Blue Topaz',
        MarkdownTheme.monospace => 'Monospace',
      };

  String _displayMarkdownRenderMode(MarkdownRenderMode m) => switch (m) {
        MarkdownRenderMode.auto => 'Auto (≥100KB performance)',
        MarkdownRenderMode.performance => 'Performance',
        MarkdownRenderMode.standard => 'Standard',
      };
}

Widget _buildDropdownTile<T extends Enum>({
  required String label,
  required T value,
  required List<T> items,
  required String Function(T) display,
  required ValueChanged<T> onChanged,
}) {
  return ListTile(
    title: Text(label),
    trailing: DropdownButton<T>(
      value: value,
      underline: const SizedBox.shrink(),
      items: items
          .map((item) => DropdownMenuItem(
                value: item,
                child: Text(display(item)),
              ))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
