import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/config/app_settings_service.dart';
import 'core/network/api_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiClient.init();
  await AppSettingsService.init();
  runApp(const ProviderScope(child: KomiVerseApp()));
}

class KomiVerseApp extends StatelessWidget {
  const KomiVerseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppSettingsService.themeModeNotifier,
      builder: (context, mode, _) {
        return MaterialApp.router(
          title: 'KomiVerse',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,
          routerConfig: appRouter,
        );
      },
    );
  }
}
