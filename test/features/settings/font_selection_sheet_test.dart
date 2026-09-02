// test/features/settings/font_selection_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markread/core/models/system_font.dart';
import 'package:markread/core/providers/system_fonts_provider.dart';
import 'package:markread/core/services/dynamic_font_loader.dart';
import 'package:markread/features/settings/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleFonts = <SystemFont>[
    const SystemFont(name: 'Roboto', hasChinese: false, isMonospace: false),
    const SystemFont(
      name: 'Noto Serif SC',
      path: '/system/fonts/NotoSerifCJK-Regular.ttc',
      hasChinese: true,
      isMonospace: false,
    ),
    const SystemFont(
      name: 'Droid Sans Mono',
      path: '/system/fonts/DroidSansMono.ttf',
      hasChinese: false,
      isMonospace: true,
    ),
    const SystemFont(
      name: 'MiSans',
      path: '/product/fonts/MiSans-Regular.ttf',
      hasChinese: true,
      isMonospace: false,
    ),
  ];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DynamicFontLoader.resetForTesting();
  });

  Widget buildTestApp({List<SystemFont>? fonts}) {
    return ProviderScope(
      overrides: [
        systemFontsProvider.overrideWith((ref) async => fonts ?? sampleFonts),
      ],
      child: const MaterialApp(
        home: SettingsScreen(),
      ),
    );
  }

  group('Font Selection in SettingsScreen', () {
    testWidgets('shows Content font and Code font tiles when fonts are available',
        (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Content font'), findsOneWidget);
      expect(find.text('Code font'), findsOneWidget);
      expect(find.text('System default'), findsOneWidget);
      expect(find.text('System default (Monospace)'), findsOneWidget);
    });

    testWidgets('opens content font sheet with badges and selects a font',
        (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Tap Content font tile
      await tester.tap(find.widgetWithText(ListTile, 'Content font'));
      await tester.pumpAndSettle();

      // Verify bottom sheet title and items
      expect(find.text('Content Font'), findsOneWidget);
      expect(find.text('Noto Serif SC'), findsOneWidget);
      expect(find.text('MiSans'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(ListTile), matching: find.text('中文')),
        findsNWidgets(2),
      ); // Noto Serif SC and MiSans
      expect(
        find.descendant(
            of: find.byType(ListTile), matching: find.text('Monospace')),
        findsOneWidget,
      ); // Droid Sans Mono

      // Select Noto Serif SC
      await tester.tap(find.widgetWithText(ListTile, 'Noto Serif SC'));
      await tester.pumpAndSettle();

      // Sheet should be closed and Content font subtitle updated
      expect(find.text('Noto Serif SC'), findsOneWidget);
    });

    testWidgets('code font sheet prioritizes monospace fonts', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Tap Code font tile
      await tester.tap(find.widgetWithText(ListTile, 'Code font'));
      await tester.pumpAndSettle();

      expect(find.text('Code Font'), findsOneWidget);

      // Verify Droid Sans Mono appears
      expect(find.text('Droid Sans Mono'), findsOneWidget);

      // Select Droid Sans Mono
      await tester.tap(find.widgetWithText(ListTile, 'Droid Sans Mono'));
      await tester.pumpAndSettle();

      expect(find.text('Droid Sans Mono'), findsOneWidget);
    });

    testWidgets('search filtering works in font sheet', (tester) async {
      final manyFonts = List.generate(
        15,
        (i) => SystemFont(
          name: 'CustomFont $i',
          hasChinese: i % 2 == 0,
          isMonospace: i % 3 == 0,
        ),
      );

      await tester.pumpWidget(buildTestApp(fonts: manyFonts));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ListTile, 'Content font'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);

      // Enter search query
      await tester.enterText(find.byType(TextField), 'CustomFont 12');
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ListTile, 'CustomFont 12'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'CustomFont 1'), findsNothing);
    });

    testWidgets('selecting System default clears selection', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // First set a font
      await tester.tap(find.widgetWithText(ListTile, 'Content font'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'MiSans'));
      await tester.pumpAndSettle();
      expect(find.text('MiSans'), findsOneWidget);

      // Open sheet again and select System default
      await tester.tap(find.widgetWithText(ListTile, 'Content font'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Use default typography'));
      await tester.pumpAndSettle();

      expect(find.text('System default'), findsOneWidget);
    });

    testWidgets('filter chips filter fonts and hide system default',
        (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ListTile, 'Content font'));
      await tester.pumpAndSettle();

      // Verify all 3 chips exist and "All" is selected
      final allChip = find.widgetWithText(ChoiceChip, 'All');
      final chineseChip = find.widgetWithText(ChoiceChip, '中文');
      final monoChip = find.widgetWithText(ChoiceChip, 'Monospace');

      expect(allChip, findsOneWidget);
      expect(chineseChip, findsOneWidget);
      expect(monoChip, findsOneWidget);

      final allChipWidget = tester.widget<ChoiceChip>(allChip);
      expect(allChipWidget.selected, isTrue);

      // Filter by 中文
      await tester.tap(chineseChip);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ListTile, 'Noto Serif SC'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'MiSans'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Roboto'), findsNothing);
      expect(find.widgetWithText(ListTile, 'Droid Sans Mono'), findsNothing);
      expect(find.text('Use default typography'), findsNothing);

      // Filter by Monospace
      await tester.tap(monoChip);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ListTile, 'Droid Sans Mono'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Noto Serif SC'), findsNothing);
      expect(find.widgetWithText(ListTile, 'MiSans'), findsNothing);
      expect(find.widgetWithText(ListTile, 'Roboto'), findsNothing);
      expect(find.text('Use default typography'), findsNothing);

      // Restore All
      await tester.tap(allChip);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ListTile, 'Noto Serif SC'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'MiSans'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Droid Sans Mono'), findsOneWidget);
      expect(find.text('Use default typography'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.widgetWithText(ListTile, 'Roboto'),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.widgetWithText(ListTile, 'Roboto'), findsOneWidget);
    });

    testWidgets('combining filter chip with search query works',
        (tester) async {
      final manyFonts = List.generate(
        15,
        (i) => SystemFont(
          name: 'CustomFont $i',
          hasChinese: i % 2 == 0,
          isMonospace: i % 3 == 0,
        ),
      );

      await tester.pumpWidget(buildTestApp(fonts: manyFonts));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ListTile, 'Content font'));
      await tester.pumpAndSettle();

      // Select Chinese filter chip (even indices: 0, 2, 4, 6, 8, 10, 12, 14)
      await tester.tap(find.widgetWithText(ChoiceChip, '中文'));
      await tester.pumpAndSettle();

      // Enter search query '1' (should match CustomFont 10, 12, 14 among Chinese fonts)
      await tester.enterText(find.byType(TextField), '1');
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ListTile, 'CustomFont 10'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'CustomFont 12'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'CustomFont 14'), findsOneWidget);
      // CustomFont 1, 11, 13 are odd, so hasChinese == false -> should not be shown
      expect(find.widgetWithText(ListTile, 'CustomFont 11'), findsNothing);
      expect(find.widgetWithText(ListTile, 'CustomFont 13'), findsNothing);
    });
  });
}
