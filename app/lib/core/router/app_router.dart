import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/welcome/welcome_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/quran/quran_hub_screen.dart';
import '../../features/quran/quran_surah_list_screen.dart';
import '../../features/quran/quran_ruku_list_screen.dart';
import '../../features/quran/quran_reader_screen.dart';
import '../../features/hadith/hadith_screen.dart';
import '../../features/hadith/hadith_book_screen.dart';
import '../../features/hadith/hadith_detail_screen.dart';
import '../../features/hadith/narrator_profile_screen.dart';
import '../../features/tafsir/tafsir_screen.dart';
import '../../features/tafsir/tafsir_reader_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/about/about_screen.dart';
import '../../features/ai/ai_assistant_screen.dart';
import '../../features/namaz/namaz_tracker_screen.dart';
import '../../features/tasbeeh/tasbeeh_counter_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
      GoRoute(path: '/ai', builder: (_, __) => const AiAssistantScreen()),
      GoRoute(path: '/namaz', builder: (_, __) => const NamazTrackerScreen()),
      GoRoute(
        path: '/tasbeeh',
        builder: (_, __) => const TasbeehCounterScreen(),
      ),
      GoRoute(path: '/about', builder: (_, __) => const AboutScreen()),
      GoRoute(path: '/about/licenses', builder: (_, __) => const DataSourcesLicensesScreen()),
      GoRoute(path: '/quran', builder: (_, __) => const QuranHubScreen()),
      GoRoute(path: '/quran/surahs', builder: (_, __) => const QuranSurahListScreen()),
      GoRoute(path: '/quran/rukus', builder: (_, __) => const QuranRukuListScreen()),
      GoRoute(
        path: '/quran/ruku/:ruku',
        builder: (_, state) {
          final ruku = int.parse(state.pathParameters['ruku']!);
          return QuranReaderScreen(rukuNumber: ruku);
        },
      ),
      GoRoute(
        path: '/quran/read/:surah/:ayah',
        builder: (_, state) {
          final surah = int.parse(state.pathParameters['surah']!);
          final ayah = int.parse(state.pathParameters['ayah'] ?? '1');
          return QuranReaderScreen(surahNumber: surah, startAyah: ayah);
        },
      ),
      GoRoute(path: '/hadith', builder: (_, __) => const HadithScreen()),
      GoRoute(
        path: '/hadith/book/:bookId',
        builder: (_, state) {
          final bookId = int.parse(state.pathParameters['bookId']!);
          return HadithBookScreen(bookId: bookId);
        },
      ),
      GoRoute(
        path: '/hadith/read/:bookId/:hadithNumber',
        builder: (_, state) {
          final bookId = int.parse(state.pathParameters['bookId']!);
          final hadithNumber = int.parse(state.pathParameters['hadithNumber']!);
          final chapterId = int.tryParse(state.uri.queryParameters['chapterId'] ?? '');
          final unassigned = state.uri.queryParameters['unassigned'] == '1';
          return HadithDetailScreen(
            bookId: bookId,
            hadithNumber: hadithNumber,
            chapterId: chapterId,
            unassigned: unassigned,
          );
        },
      ),
      GoRoute(
        path: '/narrator',
        builder: (_, state) {
          final id = int.tryParse(state.uri.queryParameters['id'] ?? '');
          final slug = state.uri.queryParameters['slug'];
          final name = state.uri.queryParameters['name'];
          final bookSlug = state.uri.queryParameters['book'];
          final hadithNumber = int.tryParse(state.uri.queryParameters['n'] ?? '');
          final lang = state.uri.queryParameters['lang'] ?? 'en';
          return NarratorProfileScreen(
            narratorId: id,
            slug: slug,
            displayName: name,
            bookSlug: bookSlug,
            hadithNumber: hadithNumber,
            lang: lang,
          );
        },
      ),
      GoRoute(path: '/tafsir', builder: (_, __) => const TafsirScreen()),
      GoRoute(
        path: '/tafsir/:slug/:surah/:ayah',
        builder: (_, state) {
          final slug = state.pathParameters['slug']!;
          final surah =
              int.tryParse(state.pathParameters['surah'] ?? '') ?? 0;
          final ayah = int.tryParse(state.pathParameters['ayah'] ?? '') ?? 0;
          return TafsirReaderScreen(sourceSlug: slug, surah: surah, ayah: ayah);
        },
      ),
    ],
  );
});
