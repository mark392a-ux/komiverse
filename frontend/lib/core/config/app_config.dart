class AppConfig {
  /// Optional compile-time override:
  /// flutter run --dart-define=BACKEND_BASE_URL=http://192.168.1.50:8081
  static const String compileTimeBackendBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: '',
  );

  /// Primary mobile-friendly default (works with Android physical device
  /// when using `adb reverse tcp:8081 tcp:8081`).
  static const String adbReverseBackendBaseUrl = 'http://127.0.0.1:8081';

  /// Android emulator host alias.
  static const String emulatorBackendBaseUrl = 'http://10.0.2.2:8081';

  /// Candidate URLs that the app probes at startup when no URL was saved yet.
  static const List<String> backendCandidates = [
    compileTimeBackendBaseUrl,
    adbReverseBackendBaseUrl,
    emulatorBackendBaseUrl,
  ];

  /// API prefix used by every route.
  static const String apiPrefix = '/api';

  /// SharedPreferences keys
  static const String backendUrlKey = 'backend_url';
  static const String onboardingDoneKey = 'onboarding_done';
  static const String themeModeKey = 'theme_mode';
  static const String readingDirectionKey = 'reading_direction';
  static const String defaultMangaSourceKey = 'default_source_manga';
  static const String defaultAnimeSourceKey = 'default_source_anime';
  static const String defaultNovelSourceKey = 'default_source_novel';

  /// Source defaults used when no user preference exists yet.
  static const String defaultMangaSourceId = 'thunderscans';
  static const String defaultAnimeSourceId = 'animepahe';
  static const String defaultNovelSourceId = 'novelbin';

  /// Whether to show verbose debug info in UI.
  static const bool debugMode = false;
}
