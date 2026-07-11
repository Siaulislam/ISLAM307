import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/islam307_theme.dart';
import 'core/router/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: Islam307App()));
}

class Islam307App extends ConsumerWidget {
  const Islam307App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'ISLAM 307',
      debugShowCheckedModeBanner: false,
      theme: Islam307Theme.light,
      darkTheme: Islam307Theme.dark,
      routerConfig: router,
    );
  }
}
