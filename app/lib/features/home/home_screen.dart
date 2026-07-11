import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/islam307_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _quick = [
    ('Quran', Icons.menu_book_rounded, '/quran'),
    ('Hadith', Icons.auto_stories_rounded, null),
    ('Tafsir', Icons.library_books_rounded, null),
    ('AI', Icons.auto_awesome_rounded, null),
    ('Prayer', Icons.mosque_rounded, null),
    ('Qibla', Icons.explore_rounded, null),
    ('Azkar', Icons.favorite_rounded, null),
    ('Duas', Icons.volunteer_activism_rounded, null),
    ('Library', Icons.local_library_rounded, null),
    ('Audio', Icons.headphones_rounded, null),
    ('Videos', Icons.play_circle_outline_rounded, null),
    ('Downloads', Icons.download_rounded, null),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Islam307Theme.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Islam307Theme.emeraldSoft,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Islam307Theme.goldLight, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: const Text('U', style: TextStyle(fontWeight: FontWeight.w900, color: Islam307Theme.emeraldDeep)),
                ),
                const Spacer(),
                _iconBtn(Icons.search_rounded),
                const SizedBox(width: 8),
                _iconBtn(Icons.notifications_none_rounded),
              ],
            ),
            const SizedBox(height: 20),
            _verseCard(context),
            const SizedBox(height: 14),
            _prayerCard(),
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
            _infoCard('Continue Reading', 'Al-Baqarah · Page 42 · Juz 1', onTap: () => context.push('/quran/read/2/1')),
            _infoCard('Daily Hadith', 'Actions are judged by intentions…', subtitle: 'Sahih Bukhari · 1'),
          ],
        ),
      ),
      bottomNavigationBar: _bottomNav(context, 0),
    );
  }

  Widget _verseCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Islam307Theme.white,
        borderRadius: BorderRadius.circular(20),
        border: const Border(top: BorderSide(color: Islam307Theme.gold, width: 3), left: BorderSide(color: Islam307Theme.cardBorder), right: BorderSide(color: Islam307Theme.cardBorder), bottom: BorderSide(color: Islam307Theme.cardBorder)),
        boxShadow: const [BoxShadow(color: Color(0x140F172A), blurRadius: 24, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Islam307Theme.goldLight.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(999)),
            child: const Text('Today\'s Verse', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Islam307Theme.gold)),
          ),
          const SizedBox(height: 12),
          const Text('بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ', textAlign: TextAlign.right, style: TextStyle(fontSize: 20, height: 1.8)),
          const SizedBox(height: 8),
          const Text('In the name of Allah, the Entirely Merciful, the Especially Merciful.', style: TextStyle(color: Islam307Theme.textMuted, height: 1.5)),
          TextButton(onPressed: () => context.push('/quran/read/1/1'), child: const Text('Read More →', style: TextStyle(fontWeight: FontWeight.w700, color: Islam307Theme.emerald))),
        ],
      ),
    );
  }

  Widget _prayerCard() {
    const times = [('Fajr', '05:12'), ('Dhuhr', '12:45'), ('Asr', '16:20'), ('Maghrib', '18:52'), ('Isha', '20:15')];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Islam307Theme.emeraldSoft, Islam307Theme.white]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Islam307Theme.emerald.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Prayer Times', style: TextStyle(fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep)),
              Text('Karachi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Islam307Theme.emerald)),
            ],
          ),
          const SizedBox(height: 8),
          ...times.map((t) {
            final active = t.$1 == 'Dhuhr';
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: active ? 10 : 0),
              decoration: active ? BoxDecoration(color: Islam307Theme.emerald.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)) : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(t.$1, style: TextStyle(fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
                  Text(t.$2, style: TextStyle(fontWeight: FontWeight.w800, color: active ? Islam307Theme.emeraldDeep : Islam307Theme.textPrimary)),
                ],
              ),
            );
          }),
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
            Icon(icon, color: Islam307Theme.emerald),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
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

  Widget _iconBtn(IconData icon) => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(border: Border.all(color: Islam307Theme.cardBorder), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, size: 22),
      );

  Widget _bottomNav(BuildContext context, int index) {
    const items = [('Home', Icons.home_rounded), ('Quran', Icons.menu_book_rounded), ('AI', Icons.auto_awesome_rounded), ('Library', Icons.local_library_rounded), ('More', Icons.menu_rounded)];
    return Container(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Islam307Theme.cardBorder)), color: Islam307Theme.white),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (i) {
          final active = i == index;
          return GestureDetector(
            onTap: () {
              if (i == 1) context.push('/quran');
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: active ? BoxDecoration(color: Islam307Theme.emeraldSoft, borderRadius: BorderRadius.circular(10)) : null,
                  child: Icon(items[i].$2, size: 22, color: active ? Islam307Theme.emerald : Islam307Theme.textMuted),
                ),
                Text(items[i].$1, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: active ? Islam307Theme.emerald : Islam307Theme.textMuted)),
              ],
            ),
          );
        }),
      ),
    );
  }
}
