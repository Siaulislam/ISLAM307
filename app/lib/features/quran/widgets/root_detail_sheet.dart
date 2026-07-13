import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/quran_grammar.dart';
import '../../core/models/quran_word.dart';
import '../../core/repositories/quran_word_repository.dart';
import '../../core/theme/islam307_theme.dart';
import 'word_detail_sheet.dart';

/// Offline root page — data from quran_words only. Never invents root lexicon entries.
Future<void> showQuranRootDetailSheet(BuildContext context, String root) async {
  final profile = await QuranWordRepository().rootProfile(root);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _RootDetailBody(root: root.trim(), profile: profile),
  );
}

class _RootDetailBody extends StatelessWidget {
  const _RootDetailBody({required this.root, required this.profile});

  final String root;
  final Map<String, dynamic>? profile;

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
                Text('Root · $root', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
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
            const Text('Root', style: TextStyle(fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep)),
            const SizedBox(height: 6),
            Text(root, textAlign: TextAlign.right, style: Islam307Theme.arabic(size: 40)),
            const SizedBox(height: 16),
            const Text('Meaning', style: TextStyle(fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep)),
            const SizedBox(height: 6),
            const Text(
              'No separate classical root lexicon is bundled. Below are attested word glosses from the local database only.',
              style: TextStyle(fontSize: 12, color: Islam307Theme.textMuted, height: 1.4),
            ),
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
                      if (en.isNotEmpty) Text(en, style: const TextStyle(height: 1.4)),
                      Text('$c word hits', style: const TextStyle(fontSize: 11, color: Islam307Theme.textMuted)),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 12),
            Text('Total Occurrences · $occ', style: const TextStyle(fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep)),
            Text('Derived surface forms · $forms', style: const TextStyle(color: Islam307Theme.textMuted)),
            const SizedBox(height: 16),
            const Text('Derived Words', style: TextStyle(fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep)),
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
            const Text('Morphology Tree', style: TextStyle(fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep)),
            const SizedBox(height: 6),
            Text(
              'Root $root → ${forms} attested forms → ${occ} word tokens in the Quran (local DB).',
              style: const TextStyle(height: 1.45),
            ),
            const SizedBox(height: 12),
            const Text('Grammar Tree', style: TextStyle(fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep)),
            const SizedBox(height: 6),
            const Text(
              'Open any derived word for Case · Gender · Number · Tense · Mood · Voice · Person parsed from QAC features.',
              style: TextStyle(height: 1.45, color: Islam307Theme.textMuted),
            ),
            const SizedBox(height: 12),
            const Text('Related Roots', style: TextStyle(fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep)),
            const SizedBox(height: 6),
            const Text(
              kNoAuthenticReference,
              style: TextStyle(color: Islam307Theme.textMuted, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 4),
            const Text(
              '(Related-root links require an authenticated root-relation dataset — not invented.)',
              style: TextStyle(fontSize: 12, color: Islam307Theme.textMuted),
            ),
            const SizedBox(height: 16),
            const Text('Every Ayah using this Root', style: TextStyle(fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep)),
            const SizedBox(height: 8),
            ...ayahs.map((r) {
              final s = r['surah'] as int;
              final a = r['ayah'] as int;
              final ar = '${r['text_ar'] ?? ''}';
              final gloss = '${r['meaning_en'] ?? ''}'.trim().isNotEmpty ? '${r['meaning_en']}' : '${r['meaning_ur'] ?? ''}';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(ar, textAlign: TextAlign.right, style: Islam307Theme.arabic(size: 20, height: 1.5)),
                subtitle: Text('$s:$a · ${gloss.isEmpty ? kNoAuthenticReference : gloss}', maxLines: 2, overflow: TextOverflow.ellipsis),
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
                    await showQuranWordDetailSheet(context, word);
                  },
                ),
              );
            }),
            const SizedBox(height: 10),
            const Text('Source: local quran.db · QAC morphology + Quran.com word glosses', style: TextStyle(fontSize: 11, color: Islam307Theme.textMuted)),
          ],
        ),
      ),
    );
  }
}
