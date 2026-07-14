import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/quran_grammar.dart';
import '../../core/repositories/quran_word_repository.dart';
import '../../core/theme/islam307_theme.dart';
import 'word_detail_sheet.dart';

/// Offline root page — attested local glosses only.
Future<void> showQuranRootDetailSheet(BuildContext context, String root, {String? preferredLang}) async {
  final profile = await QuranWordRepository().rootProfile(root);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Theme(
      data: Theme.of(ctx).copyWith(
        textSelectionTheme: const TextSelectionThemeData(
          selectionColor: Color(0x3399F6E4),
          selectionHandleColor: Islam307Theme.emerald,
        ),
      ),
      child: _RootDetailBody(root: root.trim(), profile: profile, preferredLang: preferredLang?.trim().isNotEmpty == true ? preferredLang!.trim() : 'ur'),
    ),
  );
}

class _RootDetailBody extends StatelessWidget {
  const _RootDetailBody({required this.root, required this.profile, required this.preferredLang});

  final String root;
  final Map<String, dynamic>? profile;
  final String preferredLang;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.92;
    if (profile == null) {
      return SafeArea(
        child: SizedBox(
          height: 220,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('جذر · $root', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(height: 16),
                const Text(kNoAuthenticReference, style: TextStyle(color: Islam307Theme.textMuted, height: 1.5)),
              ],
            ),
          ),
        ),
      );
    }

    final meanings = (profile!['attested_meanings'] as List).cast<Map<String, dynamic>>();
    final derived = (profile!['derived_words'] as List).cast<Map<String, dynamic>>();
    final ayahs = (profile!['ayahs'] as List).cast<Map<String, dynamic>>();
    final occ = profile!['occurrence_count'] as int? ?? 0;
    final forms = profile!['form_count'] as int? ?? 0;

    return SafeArea(
      child: SizedBox(
        height: height,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            const Text('جذر', style: TextStyle(fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep)),
            const SizedBox(height: 6),
            Text(root, textAlign: TextAlign.right, style: Islam307Theme.arabic(size: 40)),
            const SizedBox(height: 16),
            const Text('معانی (مستند لفظی تراجم)', style: TextStyle(fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep)),
            const SizedBox(height: 8),
            if (meanings.isEmpty)
              const Text(kNoAuthenticReference, style: TextStyle(color: Islam307Theme.textMuted))
            else
              ...meanings.map((m) {
                final en = '${m['meaning_en'] ?? ''}'.trim();
                final ur = '${m['meaning_ur'] ?? ''}'.trim();
                final c = m['c'] ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (ur.isNotEmpty) Text(ur, textAlign: TextAlign.right, textDirection: TextDirection.rtl, style: Islam307Theme.urdu(size: 18)),
                      if (en.isNotEmpty) Text(en, style: const TextStyle(height: 1.4, color: Islam307Theme.textMuted)),
                      Text('$c', style: const TextStyle(fontSize: 11, color: Islam307Theme.textMuted)),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 12),
            Text('کل وقوعات (جذر) · $occ', style: const TextStyle(fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep)),
            Text('مشتق اشکال · $forms', style: const TextStyle(color: Islam307Theme.textMuted)),
            const SizedBox(height: 16),
            const Text('مشتق الفاظ', style: TextStyle(fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep)),
            const SizedBox(height: 8),
            if (derived.isEmpty)
              const Text(kNoAuthenticReference, style: TextStyle(color: Islam307Theme.textMuted))
            else
              ...derived.map((d) {
                final ar = '${d['text_ar'] ?? ''}';
                final lemma = '${d['lemma'] ?? ''}';
                final pos = '${d['pos'] ?? ''}';
                final c = d['c'] ?? 0;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(ar, textAlign: TextAlign.right, style: Islam307Theme.arabic(size: 22)),
                  subtitle: Text('Lemma ${lemma.isEmpty ? '—' : lemma} · POS ${pos.isEmpty ? '—' : pos} · $c'),
                );
              }),
            const SizedBox(height: 12),
            const Text('متعلقہ جذور', style: TextStyle(fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep)),
            const SizedBox(height: 6),
            const Text(kNoAuthenticReference, style: TextStyle(color: Islam307Theme.textMuted, fontStyle: FontStyle.italic)),
            const SizedBox(height: 16),
            const Text('وہ آیات جن میں یہ جذر ہے', style: TextStyle(fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep)),
            const SizedBox(height: 8),
            ...ayahs.map((r) {
              final s = r['surah'] as int;
              final a = r['ayah'] as int;
              final ar = '${r['text_ar'] ?? ''}';
              final ur = '${r['meaning_ur'] ?? ''}'.trim();
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(ar, textAlign: TextAlign.right, style: Islam307Theme.arabic(size: 20, height: 1.5)),
                subtitle: Text('$s:$a · ${ur.isEmpty ? kNoAuthenticReference : ur}', maxLines: 2, overflow: TextOverflow.ellipsis, textDirection: TextDirection.rtl),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/quran/read/$s/$a');
                },
                trailing: IconButton(
                  tooltip: 'Word details',
                  icon: const Icon(Icons.info_outline_rounded),
                  onPressed: () async {
                    final word = await QuranWordRepository().wordAt(s, a, (r['word_number'] as int?) ?? 1);
                    if (!context.mounted || word == null) return;
                    await showQuranWordDetailSheet(context, word, preferredLang: preferredLang);
                  },
                ),
              );
            }),
            const SizedBox(height: 10),
            const Text('Source: local quran.db · QAC + Quran.com WBW', style: TextStyle(fontSize: 11, color: Islam307Theme.textMuted)),
          ],
        ),
      ),
    );
  }
}
