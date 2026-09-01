// test/features/home/home_screen_history_test.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markread/core/models/history_item.dart';
import 'package:markread/core/services/history_service.dart';
import 'package:markread/core/theme/app_theme.dart';
import 'package:markread/features/home/screens/home_screen.dart';
import 'package:markread/features/home/widgets/history_item_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = null;
  });

  Widget buildTestApp() {
    return ProviderScope(
      child: MaterialApp(
        theme: buildLightTheme(),
        home: const HomeScreen(),
      ),
    );
  }

  group('HomeScreen History Display', () {
    testWidgets('renders empty state when history is empty on Android', (tester) async {
      try {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        expect(find.byType(SvgPicture), findsOneWidget);
        expect(find.text('Markread'), findsOneWidget);
        expect(find.text('A clean markdown reader'), findsOneWidget);
        expect(find.text('Recent Files'), findsNothing);
        expect(find.byType(HistoryItemTile), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('renders empty state when on non-Android platform even if prefs contain items', (tester) async {
      try {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

        final items = [
          const HistoryItem(
            fileName: 'notes.md',
            filePath: '/path/notes.md',
            byteLength: 2048,
            lastOpenedMs: 1700000000000,
          ),
        ];
        SharedPreferences.setMockInitialValues({
          HistoryService.prefsKey: jsonEncode(items.map((e) => e.toJson()).toList()),
        });

        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        expect(find.byType(SvgPicture), findsOneWidget);
        expect(find.text('Recent Files'), findsNothing);
        expect(find.byType(HistoryItemTile), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('renders populated history list on Android', (tester) async {
      try {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        final items = [
          const HistoryItem(
            fileName: 'chapter1.md',
            filePath: '/path/chapter1.md',
            byteLength: 46284,
            lastOpenedMs: 1700000000000,
            charOffset: 20000,
          ),
          const HistoryItem(
            fileName: 'main.dart',
            filePath: '/path/main.dart',
            byteLength: 1024,
            lastOpenedMs: 1690000000000,
            charOffset: 0,
          ),
        ];
        SharedPreferences.setMockInitialValues({
          HistoryService.prefsKey: jsonEncode(items.map((e) => e.toJson()).toList()),
        });

        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // Top logo is restored above history
        expect(find.byType(SvgPicture), findsOneWidget);
        expect(find.text('Markread'), findsOneWidget);
        expect(find.text('A clean markdown reader'), findsOneWidget);
        expect(find.text('Browse device for Markdown or text files'), findsNothing);

        // Section header and count
        expect(find.text('Recent Files'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);

        // Item titles and tiles
        expect(find.byType(HistoryItemTile), findsNWidgets(2));
        expect(find.text('chapter1.md'), findsOneWidget);
        expect(find.text('main.dart'), findsOneWidget);

        // Progress string in chapter1.md
        expect(find.textContaining('43% read'), findsOneWidget);

        // FAB is present
        expect(find.byType(FloatingActionButton), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('removing item via tile close button removes it from list', (tester) async {
      try {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        final items = [
          const HistoryItem(
            fileName: 'doc_to_keep.md',
            filePath: '/path/doc_to_keep.md',
            byteLength: 100,
            lastOpenedMs: 2000,
          ),
          const HistoryItem(
            fileName: 'doc_to_remove.md',
            filePath: '/path/doc_to_remove.md',
            byteLength: 100,
            lastOpenedMs: 1000,
          ),
        ];
        SharedPreferences.setMockInitialValues({
          HistoryService.prefsKey: jsonEncode(items.map((e) => e.toJson()).toList()),
        });

        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        expect(find.text('doc_to_remove.md'), findsOneWidget);

        // Tap remove icon on the second tile
        final removeButtons = find.byTooltip('Remove from history');
        expect(removeButtons, findsNWidgets(2));

        await tester.tap(removeButtons.last);
        await tester.pumpAndSettle();

        expect(find.text('doc_to_remove.md'), findsNothing);
        expect(find.text('doc_to_keep.md'), findsOneWidget);
        expect(find.text('1'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('swiping item dismisses and removes it from list', (tester) async {
      try {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        final items = [
          const HistoryItem(
            fileName: 'swipe_me.md',
            filePath: '/path/swipe_me.md',
            byteLength: 100,
            lastOpenedMs: 1000,
          ),
        ];
        SharedPreferences.setMockInitialValues({
          HistoryService.prefsKey: jsonEncode(items.map((e) => e.toJson()).toList()),
        });

        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        expect(find.text('swipe_me.md'), findsOneWidget);

        // Swipe left to dismiss
        await tester.drag(find.text('swipe_me.md'), const Offset(-500, 0));
        await tester.pumpAndSettle();

        // Now history is empty → transitions back to empty state with SVG logo
        expect(find.text('swipe_me.md'), findsNothing);
        expect(find.byType(SvgPicture), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('clear history confirmation dialog cancels when Cancel is pressed', (tester) async {
      try {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        final items = [
          const HistoryItem(
            fileName: 'doc.md',
            filePath: '/path/doc.md',
            byteLength: 100,
            lastOpenedMs: 1000,
          ),
        ];
        SharedPreferences.setMockInitialValues({
          HistoryService.prefsKey: jsonEncode(items.map((e) => e.toJson()).toList()),
        });

        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        expect(find.text('doc.md'), findsOneWidget);

        // Tap clear history action in app bar
        await tester.tap(find.byTooltip('Clear history'));
        await tester.pumpAndSettle();

        expect(find.text('Clear History'), findsOneWidget);
        expect(
          find.text('Are you sure you want to remove all items from your reading history?'),
          findsOneWidget,
        );

        // Tap Cancel
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // Item should still be present
        expect(find.text('doc.md'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('clear history confirmation dialog clears all history when Clear is pressed', (tester) async {
      try {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        final items = [
          const HistoryItem(
            fileName: 'doc.md',
            filePath: '/path/doc.md',
            byteLength: 100,
            lastOpenedMs: 1000,
          ),
        ];
        SharedPreferences.setMockInitialValues({
          HistoryService.prefsKey: jsonEncode(items.map((e) => e.toJson()).toList()),
        });

        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // Tap clear history action in app bar
        await tester.tap(find.byTooltip('Clear history'));
        await tester.pumpAndSettle();

        // Tap Clear
        await tester.tap(find.text('Clear'));
        await tester.pumpAndSettle();

        // Should transition back to empty state
        expect(find.byType(SvgPicture), findsOneWidget);
        expect(find.text('doc.md'), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('tapping unavailable history item shows SnackBar with Remove action', (tester) async {
      try {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        final items = [
          const HistoryItem(
            fileName: 'missing.md',
            filePath: '/non/existent/path/missing.md',
            byteLength: 100,
            lastOpenedMs: 1000,
          ),
        ];
        SharedPreferences.setMockInitialValues({
          HistoryService.prefsKey: jsonEncode(items.map((e) => e.toJson()).toList()),
        });

        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // Tap the history item
        await tester.tap(find.text('missing.md'));
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // SnackBar should appear
        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.text("Could not open 'missing.md'. File may have been moved or deleted."),
          findsOneWidget,
        );

        // Tap Remove action on the SnackBar
        await tester.tap(find.text('Remove'));
        await tester.pumpAndSettle();

        // Missing item is removed, back to empty state
        expect(find.text('missing.md'), findsNothing);
        expect(find.byType(SvgPicture), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
