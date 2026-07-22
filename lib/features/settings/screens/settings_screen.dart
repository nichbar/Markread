// lib/features/settings/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/user_preferences.dart';
import '../../../core/providers/preferences_provider.dart';
import '../../../core/widgets/app_layout_body.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
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
            label: 'Reader light theme',
            value: prefs.readerLightTheme,
            items: ReaderLightTheme.values,
            display: _displayReaderLightTheme,
            onChanged: (v) =>
                ref.read(preferencesProvider.notifier).setReaderLightTheme(v),
          ),
          _buildDropdownTile(
            label: 'Reader dark theme',
            value: prefs.readerDarkTheme,
            items: ReaderDarkTheme.values,
            display: _displayReaderDarkTheme,
            onChanged: (v) =>
                ref.read(preferencesProvider.notifier).setReaderDarkTheme(v),
          ),
          _buildDropdownTile(
            label: 'Markdown theme',
            value: prefs.markdownTheme,
            items: MarkdownTheme.values,
            display: _displayMarkdownTheme,
            onChanged: (v) =>
                ref.read(preferencesProvider.notifier).setMarkdownTheme(v),
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
            title: Text('MarkRead'),
            subtitle: Text('A clean markdown reader'),
          ),
          const ListTile(
            title: Text('Version'),
            subtitle: Text('1.0.5'),
          ),
          const SizedBox(height: 32),
        ],
      ),
      ),
    );
  }

  String _displayReaderLightTheme(ReaderLightTheme t) => switch (t) {
        ReaderLightTheme.light => 'Light',
        ReaderLightTheme.sepia => 'Sepia',
      };

  String _displayReaderDarkTheme(ReaderDarkTheme t) => switch (t) {
        ReaderDarkTheme.dark => 'Dark',
        ReaderDarkTheme.amoled => 'AMOLED',
      };

  String _displayMarkdownTheme(MarkdownTheme t) => switch (t) {
        MarkdownTheme.standard => 'Default',
        MarkdownTheme.github => 'GitHub',
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
