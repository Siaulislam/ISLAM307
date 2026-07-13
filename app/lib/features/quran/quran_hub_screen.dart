import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/islam307_theme.dart';

class QuranHubScreen extends ConsumerWidget {
  const QuranHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Al-Quran', style: TextStyle(fontWeight: FontWeight.w800)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => context.pop()),
        actions: [
          IconButton(
            tooltip: 'Search',
            onPressed: () => context.push('/search'),
            icon: const Icon(Icons.search_rounded),
          ),
          IconButton(
            tooltip: 'Theme',
            onPressed: () => ref.read(appSettingsProvider.notifier).toggleTheme(),
            icon: Icon(settings.themeMode == ThemeMode.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          Text(
            'How would you like to browse?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Islam307Theme.emeraldDeep,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose Surah or Ruku. Translations and tafsir stay authentic — never AI-generated.',
            style: TextStyle(color: Theme.of(context).hintColor, height: 1.5),
          ),
          const SizedBox(height: 24),
          _ChoiceCard(
            icon: Icons.menu_book_rounded,
            title: 'Browse by Surah',
            subtitle: '114 chapters · Arabic + translation',
            onTap: () => context.push('/quran/surahs'),
          ),
          const SizedBox(height: 14),
          _ChoiceCard(
            icon: Icons.view_day_rounded,
            title: 'Browse by Ruku',
            subtitle: '558 sections · continuous reading units',
            onTap: () => context.push('/quran/rukus'),
          ),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border(
              top: const BorderSide(color: Islam307Theme.gold, width: 3),
              left: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.35)),
              right: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.35)),
              bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.35)),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: Islam307Theme.emeraldSoft, borderRadius: BorderRadius.circular(16)),
                child: Icon(icon, color: Islam307Theme.emerald),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: Islam307Theme.textMuted)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Islam307Theme.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
