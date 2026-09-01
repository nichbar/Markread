// test/features/home/home_screen_logo_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markread/core/theme/app_theme.dart';
import 'package:markread/features/home/screens/home_screen.dart';

void main() {
  testWidgets('HomeScreen uses light logo in light mode', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildLightTheme(),
          themeMode: ThemeMode.light,
          home: const HomeScreen(),
        ),
      ),
    );

    final svgFinder = find.byType(SvgPicture);
    expect(svgFinder, findsOneWidget);

    final svgWidget = tester.widget<SvgPicture>(svgFinder);
    final bytesLoader = svgWidget.bytesLoader;
    expect(bytesLoader, isA<SvgAssetLoader>());
    expect(
      (bytesLoader as SvgAssetLoader).assetName,
      'assets/logo/markread_logo.svg',
    );
  });

  testWidgets('HomeScreen uses dark logo in dark mode', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildDarkTheme(),
          themeMode: ThemeMode.dark,
          home: const HomeScreen(),
        ),
      ),
    );

    final svgFinder = find.byType(SvgPicture);
    expect(svgFinder, findsOneWidget);

    final svgWidget = tester.widget<SvgPicture>(svgFinder);
    final bytesLoader = svgWidget.bytesLoader;
    expect(bytesLoader, isA<SvgAssetLoader>());
    expect(
      (bytesLoader as SvgAssetLoader).assetName,
      'assets/logo/markread_logo_dark.svg',
    );
  });
}
