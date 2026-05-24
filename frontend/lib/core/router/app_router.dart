import 'package:go_router/go_router.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/splash/onboarding_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/manga/screens/manga_list_screen.dart';
import '../../features/manga/screens/manga_detail_screen.dart';
import '../../features/manga/screens/manga_reader_screen.dart';
import '../../features/manga/models/manga_model.dart';
import '../../features/anime/screens/anime_list_screen.dart';
import '../../features/anime/screens/anime_detail_screen.dart';
import '../../features/anime/screens/anime_watch_screen.dart';
import '../../features/anime/models/anime_model.dart';
import '../../features/novel/screens/novel_screen.dart';
import '../../features/novel/screens/novel_detail_screen.dart';
import '../../features/novel/screens/novel_reader_screen.dart';
import '../../features/history/screens/history_screen.dart';
import '../../features/extensions/screens/extensions_screen.dart';
import '../../features/more/screens/more_screen.dart';
import '../../features/more/screens/repositories_screen.dart';
import '../../features/more/screens/settings_screen.dart';
import '../../features/more/screens/migration_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (c, s) => const SplashScreen()),
    GoRoute(path: '/onboarding', builder: (c, s) => const OnboardingScreen()),
    ShellRoute(
      builder: (context, state, child) => HomeScreen(child: child),
      routes: [
        GoRoute(path: '/', builder: (c, s) => const MangaListScreen()),
        GoRoute(path: '/anime', builder: (c, s) => const AnimeListScreen()),
        GoRoute(path: '/novel', builder: (c, s) => const NovelScreen()),
        GoRoute(path: '/history', builder: (c, s) => const HistoryScreen()),
        GoRoute(
          path: '/extensions',
          builder: (c, s) => const ExtensionsScreen(),
        ),
        GoRoute(path: '/more', builder: (c, s) => const MoreScreen()),
      ],
    ),
    GoRoute(
      path: '/manga/detail',
      builder: (c, s) {
        final extra = s.extra is Map<String, dynamic>
            ? s.extra as Map<String, dynamic>
            : null;
        final source =
            s.uri.queryParameters['source'] ??
            extra?['source']?.toString() ??
            '';
        final id =
            s.uri.queryParameters['id'] ?? extra?['id']?.toString() ?? '';
        final preloadedRaw = extra == null ? null : extra['manga'];
        final preloaded = preloadedRaw is MangaModel ? preloadedRaw : null;

        return MangaDetailScreen(source: source, id: id, preloaded: preloaded);
      },
    ),
    GoRoute(
      path: '/manga/read',
      builder: (c, s) {
        final extra = s.extra is Map<String, dynamic>
            ? s.extra as Map<String, dynamic>
            : null;
        final source =
            s.uri.queryParameters['source'] ??
            extra?['source']?.toString() ??
            '';
        final id =
            s.uri.queryParameters['id'] ?? extra?['id']?.toString() ?? '';
        final mangaId =
            s.uri.queryParameters['mangaId'] ??
            extra?['mangaId']?.toString() ??
            '';
        final chapterTitle =
            s.uri.queryParameters['title'] ??
            extra?['title']?.toString() ??
            'Chapter';
        final mangaTitle =
            s.uri.queryParameters['mangaTitle'] ??
            extra?['mangaTitle']?.toString() ??
            '';

        return MangaReaderScreen(
          source: source,
          id: id,
          mangaId: mangaId,
          chapterTitle: chapterTitle,
          mangaTitle: mangaTitle,
        );
      },
    ),
    GoRoute(
      path: '/anime/detail',
      builder: (c, s) {
        final extra = s.extra is Map<String, dynamic>
            ? s.extra as Map<String, dynamic>
            : null;
        final source =
            s.uri.queryParameters['source'] ??
            extra?['source']?.toString() ??
            '';
        final id =
            s.uri.queryParameters['id'] ?? extra?['id']?.toString() ?? '';
        final preloadedRaw = extra == null ? null : extra['anime'];
        final preloaded = preloadedRaw is AnimeModel ? preloadedRaw : null;

        return AnimeDetailScreen(source: source, id: id, preloaded: preloaded);
      },
    ),
    GoRoute(
      path: '/anime/watch',
      builder: (c, s) {
        final extra = s.extra is Map<String, dynamic>
            ? s.extra as Map<String, dynamic>
            : null;
        final source =
            s.uri.queryParameters['source'] ??
            extra?['source']?.toString() ??
            '';
        final id =
            s.uri.queryParameters['id'] ?? extra?['id']?.toString() ?? '';
        final animeId =
            s.uri.queryParameters['animeId'] ??
            extra?['animeId']?.toString() ??
            id;
        final title =
            s.uri.queryParameters['title'] ??
            extra?['title']?.toString() ??
            'Episode';
        final animeTitle =
            s.uri.queryParameters['animeTitle'] ??
            extra?['animeTitle']?.toString() ??
            '';
        final index =
            int.tryParse(
              s.uri.queryParameters['index'] ??
                  extra?['index']?.toString() ??
                  '0',
            ) ??
            0;

        return AnimeWatchScreen(
          source: source,
          id: id,
          animeId: animeId,
          title: title,
          animeTitle: animeTitle,
          index: index,
        );
      },
    ),
    GoRoute(
      path: '/novel/detail',
      builder: (c, s) {
        final extra = s.extra is Map<String, dynamic>
            ? s.extra as Map<String, dynamic>
            : null;
        return NovelDetailScreen(
          source:
              s.uri.queryParameters['source'] ??
              extra?['source']?.toString() ??
              '',
          id: s.uri.queryParameters['id'] ?? extra?['id']?.toString() ?? '',
          title:
              s.uri.queryParameters['title'] ??
              extra?['title']?.toString() ??
              '',
          coverUrl:
              s.uri.queryParameters['coverUrl'] ??
              extra?['coverUrl']?.toString() ??
              '',
        );
      },
    ),
    GoRoute(
      path: '/novel/read',
      builder: (c, s) {
        final extra = s.extra is Map<String, dynamic>
            ? s.extra as Map<String, dynamic>
            : null;
        return NovelReaderScreen(
          source:
              s.uri.queryParameters['source'] ??
              extra?['source']?.toString() ??
              '',
          novelId:
              s.uri.queryParameters['novelId'] ??
              extra?['novelId']?.toString() ??
              '',
          id: s.uri.queryParameters['id'] ?? extra?['id']?.toString() ?? '',
          chapterTitle:
              s.uri.queryParameters['title'] ??
              extra?['title']?.toString() ??
              'Chapter',
          novelTitle:
              s.uri.queryParameters['novelTitle'] ??
              extra?['novelTitle']?.toString() ??
              '',
        );
      },
    ),
    GoRoute(
      path: '/more/repositories',
      builder: (c, s) => const RepositoriesScreen(),
    ),
    GoRoute(path: '/more/settings', builder: (c, s) => const SettingsScreen()),
    GoRoute(
      path: '/more/migration',
      builder: (c, s) => const MigrationScreen(),
    ),
  ],
);
