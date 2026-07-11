import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/welcome/welcome_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/quran/quran_screen.dart';
import '../../features/quran/quran_reader_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/quran', builder: (_, __) => const QuranScreen()),
      GoRoute(
        path: '/quran/read/:surah/:ayah',
        builder: (_, state) {
          final surah = int.parse(state.pathParameters['surah']!);
          final ayah = int.parse(state.pathParameters['ayah'] ?? '1');
          return QuranReaderScreen(surahNumber: surah, startAyah: ayah);
        },
      ),
    ],
  );
});
