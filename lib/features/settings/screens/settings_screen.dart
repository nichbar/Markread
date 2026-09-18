// lib/features/settings/screens/settings_screen.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/app_version.dart';
import '../../../core/models/system_font.dart';
import '../../../core/models/user_preferences.dart';
import '../../../core/providers/preferences_provider.dart';
import '../../../core/providers/system_fonts_provider.dart';
import '../../../core/services/dynamic_font_loader.dart';
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
    final systemFontsAsync = ref.watch(systemFontsProvider);

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
        child: ListTileTheme.merge(
          titleTextStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
          subtitleTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
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
          systemFontsAsync.when(
            data: (fonts) {
              if (fonts.isEmpty) return const SizedBox.shrink();
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('Content font'),
                    subtitle: Text(prefs.fontFamily ?? 'System default'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showFontSelectionSheet(
                      context,
                      title: 'Content Font',
                      defaultLabel: 'System default',
                      fonts: fonts,
                      selectedFont: prefs.fontFamily,
                      isCodeFont: false,
                      onFontSelected: (font) {
                        ref
                            .read(preferencesProvider.notifier)
                            .setFontFamily(font);
                      },
                    ),
                  ),
                  ListTile(
                    title: const Text('Code font'),
                    subtitle: Text(
                      prefs.codeFontFamily ?? 'System default (Monospace)',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showFontSelectionSheet(
                      context,
                      title: 'Code Font',
                      defaultLabel: 'System default (Monospace)',
                      fonts: fonts,
                      selectedFont: prefs.codeFontFamily,
                      isCodeFont: true,
                      onFontSelected: (font) {
                        ref
                            .read(preferencesProvider.notifier)
                            .setCodeFontFamily(font);
                      },
                    ),
                  ),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (error, stackTrace) => const SizedBox.shrink(),
          ),
          SwitchListTile(
            title: const Text(
              'Toggle checkboxes in reader',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: const Text(
              'Allow checking or unchecking task list items while reading and save to file',
            ),
            value: prefs.toggleCheckboxesInReadOnly,
            onChanged: (v) => ref
                .read(preferencesProvider.notifier)
                .setToggleCheckboxesInReadOnly(v),
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
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),

          // -- Line Height --
          _SectionHeader(title: 'Line Height'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '1.2',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
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
                Text(
                  '2.0',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: Text(
              '${prefs.lineHeight.toStringAsFixed(1)}x',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
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
          ListTile(
            title: Text(
              'Markread',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            subtitle: const Text('A minimal, read-focused Markdown reader.'),
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

  Future<void> _showFontSelectionSheet(
    BuildContext context, {
    required String title,
    required String defaultLabel,
    required List<SystemFont> fonts,
    required String? selectedFont,
    bool isCodeFont = false,
    required ValueChanged<String?> onFontSelected,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (bottomSheetContext) {
        return _FontSelectionSheet(
          title: title,
          defaultLabel: defaultLabel,
          fonts: fonts,
          selectedFont: selectedFont,
          isCodeFont: isCodeFont,
          onFontSelected: onFontSelected,
        );
      },
    );
  }

  String _displayMarkdownTheme(MarkdownTheme t) => switch (t) {
        MarkdownTheme.standard => 'Default',
        MarkdownTheme.github => 'GitHub',
        MarkdownTheme.blueTopaz => 'Blue Topaz',
        MarkdownTheme.monospace => 'Monospace',
      };

  String _displayMarkdownRenderMode(MarkdownRenderMode m) => switch (m) {
        MarkdownRenderMode.auto => 'Auto',
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
                child: Text(
                  display(item),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
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
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

enum _FontFilter {
  all,
  chinese,
  monospace,
}

class _FontSelectionSheet extends StatefulWidget {
  final String title;
  final String defaultLabel;
  final List<SystemFont> fonts;
  final String? selectedFont;
  final bool isCodeFont;
  final ValueChanged<String?> onFontSelected;

  const _FontSelectionSheet({
    this.title = 'Font Family',
    this.defaultLabel = 'System default',
    required this.fonts,
    required this.selectedFont,
    this.isCodeFont = false,
    required this.onFontSelected,
  });

  @override
  State<_FontSelectionSheet> createState() => _FontSelectionSheetState();
}

class _FontSelectionSheetState extends State<_FontSelectionSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _FontFilter _selectedFilter = _FontFilter.all;

  late final List<SystemFont> _baseSortedFonts;
  late List<SystemFont> _filteredFonts;

  Animation<double>? _routeAnimation;
  bool _isAnimationComplete = false;
  Timer? _fallbackAnimationTimer;

  @override
  void initState() {
    super.initState();
    _initSortedFonts();
    _searchController.addListener(_onSearchChanged);

    // Fallback: Ensure font loading is unlocked even if route animation listener does not fire
    _fallbackAnimationTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted && !_isAnimationComplete) {
        setState(() {
          _isAnimationComplete = true;
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    if (_routeAnimation != animation) {
      _routeAnimation?.removeStatusListener(_onAnimationStatusChanged);
      _routeAnimation = animation;
      if (animation != null) {
        if (animation.isCompleted) {
          _isAnimationComplete = true;
        } else {
          animation.addStatusListener(_onAnimationStatusChanged);
        }
      }
    }
    if (animation == null) {
      _isAnimationComplete = true;
    }
  }

  void _onAnimationStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _routeAnimation?.removeStatusListener(_onAnimationStatusChanged);
      _fallbackAnimationTimer?.cancel();
      if (mounted) {
        setState(() {
          _isAnimationComplete = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _fallbackAnimationTimer?.cancel();
    _routeAnimation?.removeStatusListener(_onAnimationStatusChanged);
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _initSortedFonts() {
    if (widget.isCodeFont) {
      final mono = widget.fonts.where((f) => f.isMonospace).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      final nonMono = widget.fonts.where((f) => !f.isMonospace).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      _baseSortedFonts = List.unmodifiable([...mono, ...nonMono]);
    } else {
      _baseSortedFonts = List.unmodifiable(
        widget.fonts.toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
      );
    }
    _updateFilteredFonts();
  }

  void _updateFilteredFonts() {
    var list = _baseSortedFonts;

    switch (_selectedFilter) {
      case _FontFilter.chinese:
        list = list.where((f) => f.hasChinese).toList();
        break;
      case _FontFilter.monospace:
        list = list.where((f) => f.isMonospace).toList();
        break;
      case _FontFilter.all:
        break;
    }

    if (_searchQuery.isNotEmpty) {
      list = list
          .where((f) => f.name.toLowerCase().contains(_searchQuery))
          .toList();
    }

    _filteredFonts = list;
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    if (query != _searchQuery) {
      setState(() {
        _searchQuery = query;
        _updateFilteredFonts();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final showSystemDefault = _selectedFilter == _FontFilter.all &&
        (_searchQuery.isEmpty ||
            widget.defaultLabel.toLowerCase().contains(_searchQuery) ||
            'system default'.contains(_searchQuery));

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            if (widget.fonts.length > 8)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search fonts...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _selectedFilter == _FontFilter.all,
                    onSelected: (selected) {
                      if (selected && _selectedFilter != _FontFilter.all) {
                        setState(() {
                          _selectedFilter = _FontFilter.all;
                          _updateFilteredFonts();
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('中文'),
                    selected: _selectedFilter == _FontFilter.chinese,
                    onSelected: (selected) {
                      if (selected && _selectedFilter != _FontFilter.chinese) {
                        setState(() {
                          _selectedFilter = _FontFilter.chinese;
                          _updateFilteredFonts();
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Monospace'),
                    selected: _selectedFilter == _FontFilter.monospace,
                    onSelected: (selected) {
                      if (selected && _selectedFilter != _FontFilter.monospace) {
                        setState(() {
                          _selectedFilter = _FontFilter.monospace;
                          _updateFilteredFonts();
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _filteredFonts.length + (showSystemDefault ? 1 : 0),
                itemBuilder: (context, index) {
                  if (showSystemDefault && index == 0) {
                    final isSelected = widget.selectedFont == null ||
                        widget.selectedFont!.isEmpty;
                    return ListTile(
                      title: Text(
                        widget.defaultLabel,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: const Text('Use default typography'),
                      trailing: isSelected
                          ? Icon(
                              Icons.check,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                      onTap: () {
                        widget.onFontSelected(null);
                        Navigator.of(context).pop();
                      },
                    );
                  }

                  final fontIndex = showSystemDefault ? index - 1 : index;
                  final font = _filteredFonts[fontIndex];
                  final isSelected = widget.selectedFont == font.name;

                  return _FontListTile(
                    key: ValueKey(font.name),
                    font: font,
                    isSelected: isSelected,
                    canLoad: _isAnimationComplete,
                    onTap: () {
                      if (font.path != null) {
                        unawaited(DynamicFontLoader.loadFont(font.name, font.path));
                      }
                      widget.onFontSelected(font.name);
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FontListTile extends StatefulWidget {
  final SystemFont font;
  final bool isSelected;
  final bool canLoad;
  final VoidCallback onTap;

  const _FontListTile({
    super.key,
    required this.font,
    required this.isSelected,
    required this.canLoad,
    required this.onTap,
  });

  @override
  State<_FontListTile> createState() => _FontListTileState();
}

class _FontListTileState extends State<_FontListTile> {
  bool _isLoaded = false;
  Timer? _loadDebounceTimer;

  @override
  void initState() {
    super.initState();
    _checkAndLoad();
  }

  @override
  void didUpdateWidget(covariant _FontListTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.canLoad && !oldWidget.canLoad) ||
        widget.font.name != oldWidget.font.name ||
        widget.font.path != oldWidget.font.path) {
      _checkAndLoad();
    }
  }

  void _checkAndLoad() {
    final fontName = widget.font.name;
    if (DynamicFontLoader.isPlatformSystemFont(fontName) ||
        DynamicFontLoader.isFontLoaded(fontName)) {
      _isLoaded = true;
      return;
    }

    _loadDebounceTimer?.cancel();

    if (!widget.canLoad || widget.font.path == null) {
      return;
    }

    // Small debounce (60ms) so rapid list flings don't trigger disk reads
    _loadDebounceTimer = Timer(const Duration(milliseconds: 60), () {
      if (!mounted) return;
      DynamicFontLoader.loadFont(fontName, widget.font.path).then((loaded) {
        if (loaded && mounted) {
          setState(() {
            _isLoaded = true;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _loadDebounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final font = widget.font;
    final fontToUse = _isLoaded ? font.name : null;

    return ListTile(
      title: Row(
        children: [
          Flexible(
            child: Text(
              font.name,
              style: TextStyle(
                fontFamily: fontToUse,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (font.hasChinese) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '中文',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context)
                      .colorScheme
                      .onPrimaryContainer,
                ),
              ),
            ),
          ],
          if (font.isMonospace) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .secondaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Monospace',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context)
                      .colorScheme
                      .onSecondaryContainer,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        'Quick brown fox · 敏捷的棕狐',
        style: TextStyle(
          fontFamily: fontToUse,
          fontSize: 13.5,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: widget.isSelected
          ? Icon(
              Icons.check,
              color: Theme.of(context).colorScheme.primary,
            )
          : null,
      onTap: widget.onTap,
    );
  }
}
