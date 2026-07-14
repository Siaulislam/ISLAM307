import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/settings/app_settings.dart';
import 'core/database/user_database.dart';
import 'core/user/user_library_store.dart';
import 'core/tafsir/legacy_tafsir_cleanup.dart';
import 'core/theme/islam307_theme.dart';
import 'core/router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await LegacyTafsirCleanup.run();
  } catch (_) {
    // Retry occurs before the first Tafseer API request. Never reopen the
    // legacy database even if cleanup is temporarily blocked by the OS.
  }
  await UserDatabase.instance.open();
  await UserLibraryStore.instance.migrateLegacyJson();
  runApp(const ProviderScope(child: Islam307App()));
}

class Islam307App extends ConsumerWidget {
  const Islam307App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final settings = ref.watch(appSettingsProvider);
    return MaterialApp.router(
      title: 'ISLAM 307',
      debugShowCheckedModeBanner: false,
      theme: Islam307Theme.light,
      darkTheme: Islam307Theme.dark,
      themeMode: settings.themeMode,
      routerConfig: router,
    );
  }
}
