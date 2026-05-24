import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_config.dart';

enum ReaderDirectionPreference { ltr, rtl }

class AppSettingsService {
  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.dark);

  static final ValueNotifier<ReaderDirectionPreference>
  readingDirectionNotifier = ValueNotifier<ReaderDirectionPreference>(
    ReaderDirectionPreference.ltr,
  );

  static final ValueNotifier<Map<String, String>> defaultSourcesNotifier =
      ValueNotifier<Map<String, String>>({
        'manga': AppConfig.defaultMangaSourceId,
        'anime': AppConfig.defaultAnimeSourceId,
        'novel': AppConfig.defaultNovelSourceId,
      });

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    final themeRaw = prefs.getString(AppConfig.themeModeKey) ?? 'dark';
    themeModeNotifier.value = _themeFromString(themeRaw);

    final directionRaw =
        prefs.getString(AppConfig.readingDirectionKey) ?? 'ltr';
    readingDirectionNotifier.value = directionRaw == 'rtl'
        ? ReaderDirectionPreference.rtl
        : ReaderDirectionPreference.ltr;

    defaultSourcesNotifier.value = {
      'manga':
          prefs.getString(AppConfig.defaultMangaSourceKey) ??
          AppConfig.defaultMangaSourceId,
      'anime':
          prefs.getString(AppConfig.defaultAnimeSourceKey) ??
          AppConfig.defaultAnimeSourceId,
      'novel':
          prefs.getString(AppConfig.defaultNovelSourceKey) ??
          AppConfig.defaultNovelSourceId,
    };
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConfig.themeModeKey, _themeToString(mode));
  }

  static Future<void> setReadingDirection(
    ReaderDirectionPreference direction,
  ) async {
    readingDirectionNotifier.value = direction;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      AppConfig.readingDirectionKey,
      direction == ReaderDirectionPreference.rtl ? 'rtl' : 'ltr',
    );
  }

  static String defaultSourceForType(String type) {
    return defaultSourcesNotifier.value[type] ?? '';
  }

  static Future<void> setDefaultSourceForType(String type, String sourceId) async {
    if (sourceId.trim().isEmpty) {
      return;
    }

    final next = Map<String, String>.from(defaultSourcesNotifier.value);
    next[type] = sourceId.trim();
    defaultSourcesNotifier.value = next;

    final prefs = await SharedPreferences.getInstance();
    switch (type) {
      case 'anime':
        await prefs.setString(AppConfig.defaultAnimeSourceKey, sourceId.trim());
        break;
      case 'novel':
        await prefs.setString(AppConfig.defaultNovelSourceKey, sourceId.trim());
        break;
      case 'manga':
      default:
        await prefs.setString(AppConfig.defaultMangaSourceKey, sourceId.trim());
        break;
    }
  }

  static ThemeMode _themeFromString(String raw) {
    switch (raw) {
      case 'system':
        return ThemeMode.system;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.dark;
    }
  }

  static String _themeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'system';
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
    }
  }
}
