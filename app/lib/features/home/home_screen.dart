import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/branding/islam307_logo.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/islam307_theme.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _quick = [
    ('Quran', Icons.menu_book_rounded, '/quran'),
    ('Hadith', Icons.auto_stories_rounded, '/hadith'),
    ('Tafsir', Icons.library_books_rounded, '/tafsir'),
    ('Search', Icons.search_rounded, '/search'),
    ('AI', Icons.auto_awesome_rounded, '/ai'),
    ('About', Icons.info_outline_rounded, '/about'),
    ('Prayer', Icons.mosque_rounded, '/feature/prayer-guide'),
    ('Qibla', Icons.explore_rounded, '/utilities/qibla'),
    ('Azkar', Icons.favorite_rounded, '/feature/adhkar'),
    ('Duas', Icons.volunteer_activism_rounded, '/feature/duas'),
    ('Library', Icons.local_library_rounded, '/library'),
    ('Audio', Icons.headphones_rounded, '/feature/audio'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(
              children: [
                const Expanded(child: Islam307BrandBar(showTagline: true)),
                IconButton(
                  onPressed: () => context.push('/search'),
                  icon: const Icon(Icons.search_rounded),
                ),
                IconButton(
                  onPressed: () => ref.read(appSettingsProvider.notifier).toggleTheme(),
                  icon: Icon(settings.themeMode == ThemeMode.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _verseCard(context),
            const SizedBox(height: 14),
            _offlineToolsCard(context),
            const SizedBox(height: 20),
            const Text('Quick Access', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.82,
              children: _quick.map((e) => _gridItem(context, e.$1, e.$2, e.$3)).toList(),
            ),
            const SizedBox(height: 16),
            _infoCard('Personal Library', 'Bookmarks · Favorites · Reading History · Notes', onTap: () => context.push('/library')),
            _infoCard('Hadith permission status', 'Content placeholder remains disabled until commercial offline redistribution is approved.', onTap: () => context.push('/feature/hadith')),
            _infoCard('Optional Content Updates', 'No background checks · approved signed endpoints only', onTap: () => context.push('/updates')),
            _infoCard('About & Licenses', 'Approved datasets · pending permissions · attribution', onTap: () => context.push('/about/licenses')),
            const SizedBox(height: 20),
            _dashboardFooter(),
          ],
        ),
      ),
      bottomNavigationBar: _bottomNav(context, 0),
    );
  }

  Widget _dashboardFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F4EE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Islam307Theme.goldLight.withValues(alpha: 0.7)),
      ),
      child: const Column(
        children: [
          Islam307BrandBar(showTagline: true, alignment: MainAxisAlignment.center),
          SizedBox(height: 6),
          Text(
            '100% Offline Islamic Companion',
            style: TextStyle(fontSize: 11, color: Islam307Theme.textMuted, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _verseCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: const Border(
          top: BorderSide(color: Islam307Theme.gold, width: 3),
          left: BorderSide(color: Islam307Theme.cardBorder),
          right: BorderSide(color: Islam307Theme.cardBorder),
          bottom: BorderSide(color: Islam307Theme.cardBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Islam307Theme.goldLight.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(999)),
            child: const Text("Quran Arabic", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Islam307Theme.gold)),
          ),
          const SizedBox(height: 12),
          Text('بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ', textAlign: TextAlign.right, style: Islam307Theme.arabic(size: 20)),
          const SizedBox(height: 8),
          const Text(
            'Translations remain disabled until explicit offline commercial redistribution permission is documented.',
            style: TextStyle(color: Islam307Theme.textMuted, height: 1.4),
          ),
          TextButton(onPressed: () => context.push('/quran/read/1/1'), child: const Text('Read More →', style: TextStyle(fontWeight: FontWeight.w700, color: Islam307Theme.emerald))),
        ],
      ),
    );
  }

  Widget _offlineToolsCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Islam307Theme.emeraldSoft, Colors.white.withValues(alpha: 0.2)]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Islam307Theme.emerald.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Offline Utilities',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Islam307Theme.emeraldDeep,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => context.push('/utilities/qibla'),
                icon: const Icon(Icons.explore_rounded),
                label: const Text('Qibla'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.push('/utilities/calendar'),
                icon: const Icon(Icons.calendar_month_rounded),
                label: const Text('Calendar'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.push('/utilities/zakat'),
                icon: const Icon(Icons.calculate_rounded),
                label: const Text('Zakat'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _gridItem(BuildContext context, String label, IconData icon, String? route) {
    return Material(
      color: Islam307Theme.fieldFill,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: route != null ? () => context.push(route) : null,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: route == null ? Islam307Theme.textMuted : Islam307Theme.emerald),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: route == null ? Islam307Theme.textMuted : null)),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(String title, String body, {String? subtitle, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Islam307Theme.fieldFill,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(body, style: const TextStyle(color: Islam307Theme.textMuted, fontSize: 13)),
              if (subtitle != null) Text(subtitle, style: const TextStyle(color: Islam307Theme.emerald, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _bottomNav(BuildContext context, int index) {
    const items = [
      ('Home', Icons.home_rounded, '/home'),
      ('Quran', Icons.menu_book_rounded, '/quran'),
      ('Hadith', Icons.auto_stories_rounded, '/hadith'),
      ('Tafsir', Icons.library_books_rounded, '/tafsir'),
      ('Search', Icons.search_rounded, '/search'),
    ];
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (i) {
          final active = i == index;
          return GestureDetector(
            onTap: () {
              if (i == 0) return;
              context.push(items[i].$3);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: active
                      ? BoxDecoration(color: Islam307Theme.emeraldSoft, borderRadius: BorderRadius.circular(10))
                      : null,
                  child: i == 0
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: ColoredBox(
                            color: const Color(0xFFF7F4EE),
                            child: Image.asset(
                              Islam307Logo.assetPath,
                              width: 26,
                              height: 26,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Icon(
                                items[i].$2,
                                size: 22,
                                color: active ? Islam307Theme.emerald : Islam307Theme.textMuted,
                              ),
                            ),
                          ),
                        )
                      : Icon(items[i].$2, size: 22, color: active ? Islam307Theme.emerald : Islam307Theme.textMuted),
                ),
                Text(
                  items[i].$1,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: active ? Islam307Theme.emerald : Islam307Theme.textMuted,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
