import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/theme.dart';
import 'providers/settings_provider.dart';
import 'ui/screens/dashboard_screen.dart';

import 'core/notifications.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize notifications
  try {
    final notificationService = NotificationService();
    await notificationService.init().timeout(const Duration(seconds: 3));
  } catch (e) {
    debugPrint('Notification initialization failed or timed out: $e');
  }

  // Handle Flutter errors globally
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Scaffold(
      body: Center(
        child: Text(
          'Error: ${details.exception}',
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  };
  
  runApp(
    const ProviderScope(
      child: MattioliOSApp(),
    ),
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
    ],
  );
});

class MattioliOSApp extends ConsumerWidget {
  const MattioliOSApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final router = ref.watch(routerProvider);

    // Safety fallback for accentColor to avoid Null subtype errors during hot reload
    final Color effectiveAccentColor = settings.accentColor;

    return MaterialApp.router(
      title: 'Mattioli.OS',
      theme: AppTheme.darkTheme(effectiveAccentColor),
      themeMode: settings.themeMode == 'dark' ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
