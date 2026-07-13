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
import '../../features/tafsir/tafsir_screen.dart';
import '../../features/tafsir/tafsir_reader_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/qibla/qibla_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
      GoRoute(path: '/qibla', builder: (_, __) => const QiblaScreen()),
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
          return HadithDetailScreen(bookId: bookId, hadithNumber: hadithNumber);
        },
      ),
      GoRoute(path: '/tafsir', builder: (_, __) => const TafsirScreen()),
      GoRoute(
        path: '/tafsir/:slug/:surah/:ayah',
        builder: (_, state) {
          final slug = state.pathParameters['slug']!;
          final surah = int.parse(state.pathParameters['surah']!);
          final ayah = int.parse(state.pathParameters['ayah']!);
          return TafsirReaderScreen(sourceSlug: slug, surah: surah, ayah: ayah);
        },
      ),
    ],
  );
});
