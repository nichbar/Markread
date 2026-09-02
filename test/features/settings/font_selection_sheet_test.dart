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
      expect(find.text('中文'), findsNWidgets(2)); // Noto Serif SC and MiSans
      expect(find.text('Monospace'), findsOneWidget); // Droid Sans Mono

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
  });
}
