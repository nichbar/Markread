// test/features/settings/checkbox_setting_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markread/core/providers/preferences_provider.dart';
import 'package:markread/core/providers/system_fonts_provider.dart';
import 'package:markread/features/settings/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('SettingsScreen has checkbox toggle switch and updates preference', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        systemFontsProvider.overrideWith((ref) async => const []),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final switchFinder = find.widgetWithText(
      SwitchListTile,
      'Toggle checkboxes in reader',
    );
    expect(switchFinder, findsOneWidget);
    expect(
      container.read(preferencesProvider).toggleCheckboxesInReadOnly,
      isFalse,
    );

    // Tap switch to toggle it on
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(
      container.read(preferencesProvider).toggleCheckboxesInReadOnly,
      isTrue,
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('toggleCheckboxesInReadOnly'), isTrue);
  });
}
