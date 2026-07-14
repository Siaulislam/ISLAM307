import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/welcome/welcome_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/quran/quran_hub_screen.dart';
import '../../features/quran/quran_surah_list_screen.dart';
import '../../features/quran/quran_reader_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/about/about_screen.dart';
import '../../features/ai/ai_assistant_screen.dart';
import '../../features/library/feature_library_screen.dart';
import '../../features/library/user_library_screen.dart';
import '../../features/placeholders/licensed_feature_placeholder_screen.dart';
import '../../features/utilities/offline_utility_screen.dart';
import '../../features/settings/content_updates_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
      GoRoute(path: '/ai', builder: (_, __) => const AiAssistantScreen()),
      GoRoute(path: '/about', builder: (_, __) => const AboutScreen()),
      GoRoute(path: '/about/licenses', builder: (_, __) => const DataSourcesLicensesScreen()),
      GoRoute(path: '/updates', builder: (_, __) => const ContentUpdatesScreen()),
      GoRoute(path: '/library', builder: (_, __) => const FeatureLibraryScreen()),
      GoRoute(
        path: '/library/:section',
        builder: (_, state) => UserLibraryScreen(
          section: state.pathParameters['section'] ?? '',
        ),
      ),
      GoRoute(
        path: '/feature/:id',
        builder: (_, state) => LicensedFeaturePlaceholderScreen(
          featureId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: '/utilities/:id',
        builder: (_, state) => OfflineUtilityScreen(
          utility: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(path: '/quran', builder: (_, __) => const QuranHubScreen()),
      GoRoute(path: '/quran/surahs', builder: (_, __) => const QuranSurahListScreen()),
      GoRoute(
        path: '/quran/rukus',
        builder: (_, __) => const LicensedFeaturePlaceholderScreen(
          featureId: 'quran-structure',
        ),
      ),
      GoRoute(
        path: '/quran/ruku/:ruku',
        builder: (_, __) => const LicensedFeaturePlaceholderScreen(
          featureId: 'quran-structure',
        ),
      ),
      GoRoute(
        path: '/quran/read/:surah/:ayah',
        builder: (_, state) {
          final surah = int.parse(state.pathParameters['surah']!);
          final ayah = int.parse(state.pathParameters['ayah'] ?? '1');
          return QuranReaderScreen(surahNumber: surah, startAyah: ayah);
        },
      ),
      GoRoute(
        path: '/hadith',
        builder: (_, __) =>
            const LicensedFeaturePlaceholderScreen(featureId: 'hadith'),
      ),
      GoRoute(
        path: '/hadith/book/:bookId',
        builder: (_, __) =>
            const LicensedFeaturePlaceholderScreen(featureId: 'hadith'),
      ),
      GoRoute(
        path: '/hadith/read/:bookId/:hadithNumber',
        builder: (_, __) =>
            const LicensedFeaturePlaceholderScreen(featureId: 'hadith'),
      ),
      GoRoute(
        path: '/narrator',
        builder: (_, __) => const LicensedFeaturePlaceholderScreen(
          featureId: 'narrators',
        ),
      ),
      GoRoute(
        path: '/tafsir',
        builder: (_, __) =>
            const LicensedFeaturePlaceholderScreen(featureId: 'tafsir'),
      ),
      GoRoute(
        path: '/tafsir/:slug/:surah/:ayah',
        builder: (_, __) =>
            const LicensedFeaturePlaceholderScreen(featureId: 'tafsir'),
      ),
    ],
  );
});
