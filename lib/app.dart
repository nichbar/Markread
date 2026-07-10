// lib/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/models/user_preferences.dart';
import 'core/providers/preferences_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/home/screens/home_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/viewer/screens/viewer_screen.dart';

final _routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final loc = state.uri.toString();
      if (loc.startsWith('content://') || loc.startsWith('file://')) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/viewer',
        pageBuilder: (context, state) {
          final name = state.uri.queryParameters['name'] ?? 'Untitled';
          return CustomTransitionPage(
            key: state.pageKey,
            child: ViewerScreen(fileName: name),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 300),
          );
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});

class MarkReadApp extends ConsumerWidget {
  const MarkReadApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesProvider);
    final router = ref.watch(_routerProvider);

    return MaterialApp.router(
      title: 'MarkRead',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: switch (prefs.appThemeMode) {
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
        AppThemeMode.system => ThemeMode.system,
      },
      routerConfig: router,
    );
  }
}
