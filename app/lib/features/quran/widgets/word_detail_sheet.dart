import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/audio/tts_service.dart';
import '../../core/models/quran_grammar.dart';
import '../../core/models/quran_word.dart';
import '../../core/repositories/quran_word_repository.dart';
import '../../core/theme/islam307_theme.dart';
import 'root_detail_sheet.dart';

/// Instant word popup → optional full Word Details (authenticated quran.db only).
Future<void> showQuranWordQuickSheet(BuildContext context, QuranWord seed) async {
  final repo = QuranWordRepository();
  final word = await repo.wordById(seed.id) ?? seed;
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Word Meaning · ${word.reference}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 10),
              Text(word.textAr, textAlign: TextAlign.right, style: Islam307Theme.arabic(size: 34)),
              if (word.transliteration.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(word.transliteration, style: const TextStyle(color: Islam307Theme.textMuted, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 12),
              Text(
                word.meaningUr.isEmpty ? kNoAuthenticReference : word.meaningUr,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: Islam307Theme.urdu(size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                word.meaningEn.isEmpty ? kNoAuthenticReference : word.meaningEn,
                style: const TextStyle(height: 1.45, fontSize: 15),
              ),
              if (word.root.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('Root · ${word.root}', textAlign: TextAlign.right, style: Islam307Theme.arabic(size: 20)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  showQuranWordDetailSheet(context, word);
                },
                child: const Text('More · Full Word Analysis'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Full Word Details — authenticated fields only.
Future<void> showQuranWordDetailSheet(BuildContext context, QuranWord seed) async {
  final repo = QuranWordRepository();
  final word = await repo.wordById(seed.id) ?? seed;
  final similar = await repo.similarWords(word, limit: 16);
  final verses = await repo.versesContainingWord(word, limit: 60);
  final surfaceCount = await repo.surfaceCount(word);
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _WordDetailBody(
      word: word,
      similar: similar,
      verses: verses,
      surfaceCount: surfaceCount,
    ),
  );
}

class _WordDetailBody extends StatefulWidget {
  const _WordDetailBody({
    required this.word,
    required this.similar,
    required this.verses,
    required this.surfaceCount,
  });

  final QuranWord word;
  final List<QuranWord> similar;
  final List<Map<String, dynamic>> verses;
  final int surfaceCount;

  @override
  State<_WordDetailBody> createState() => _WordDetailBodyState();
}

class _WordDetailBodyState extends State<_WordDetailBody> {
  bool _speaking = false;

  Future<void> _speak(String text, String language) async {
    if (text.trim().isEmpty || text == kNoAuthenticReference) return;
    setState(() => _speaking = true);
    final ok = await TtsService.instance.speakOffline(text, language: language);
    if (!mounted) return;
    setState(() => _speaking = false);
    if (!ok) await TtsService.instance.showInstallVoiceGuide(context, language);
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.word;
    final g = w.grammarAnalysis;
    final height = MediaQuery.sizeOf(context).height * 0.92;
    return SafeArea(
      child: SizedBox(
        height: height,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Word Details · ${w.reference}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                ),
                IconButton(
                  tooltip: 'Speak Arabic',
                  onPressed: _speaking ? null : () => _speak(w.textAr, 'ar-SA'),
                  icon: const Icon(Icons.volume_up_rounded, color: Islam307Theme.emerald),
                ),
                IconButton(
                  tooltip: 'Copy',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: w.localAiExplanation()));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied authenticated word details')));
                  },
                  icon: const Icon(Icons.copy_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(w.textAr, textAlign: TextAlign.right, style: Islam307Theme.arabic(size: 36)),
            _block('Arabic Word', w.textAr, arabic: true, speak: () => _speak(w.textAr, 'ar-SA')),
            _block(
              'Urdu Meaning',
              w.fieldOrMissing(w.meaningUr),
              style: Islam307Theme.urdu(size: 20),
              align: TextAlign.right,
              direction: TextDirection.rtl,
              speak: w.meaningUr.isEmpty ? null : () => _speak(w.meaningUr, 'ur-PK'),
            ),
            _block(
              'English Meaning',
              w.fieldOrMissing(w.meaningEn),
              speak: w.meaningEn.isEmpty ? null : () => _speak(w.meaningEn, 'en-US'),
            ),
            _block('Transliteration', w.fieldOrMissing(w.transliteration)),
            _block(
              'Root Letters',
              w.fieldOrMissing(w.root),
              arabic: w.root.isNotEmpty,
              trailing: w.root.isEmpty
                  ? null
                  : TextButton(
                      onPressed: () => showQuranRootDetailSheet(context, w.root),
                      child: const Text('Open Root'),
                    ),
            ),
            _block(
              'Root Meaning',
              'Attested only via word glosses for this root — open Root page. AI never invents root definitions.',
            ),
            _block('Morphology', w.fieldOrMissing(w.morphology)),
            _block('Grammar', w.fieldOrMissing(w.grammarSummary)),
            _block('Part of Speech', w.fieldOrMissing(w.pos)),
            _block('Syntax', w.fieldOrMissing(w.syntaxSummary)),
            _block('Word Frequency (this surface form)', '${widget.surfaceCount}'),
            _block('Total Occurrences (root / lemma / form family)', '${w.occurrenceCount}'),
            const SizedBox(height: 6),
            const Text('Grammar (parsed from QAC features)', style: TextStyle(fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep)),
            const SizedBox(height: 8),
            if (g.isEmpty)
              const Text(kNoAuthenticReference, style: TextStyle(color: Islam307Theme.textMuted))
            else
              ...g.displayRows.entries.map((e) => _kv(e.key, e.value)),
            const SizedBox(height: 14),
            const Text('Morphology Tree', style: TextStyle(fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep)),
            const SizedBox(height: 8),
            if (w.parts.isEmpty)
              const Text(kNoAuthenticReference, style: TextStyle(color: Islam307Theme.textMuted))
            else
              ...w.parts.map(
                (p) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFD1D5DB)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${p.role} · ${p.tag.isEmpty ? '—' : p.tag}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(p.features.isEmpty ? kNoAuthenticReference : p.features, style: const TextStyle(fontSize: 13, height: 1.45, color: Islam307Theme.textMuted)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            const Text('Every verse containing this word', style: TextStyle(fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep)),
            const SizedBox(height: 8),
            if (widget.verses.isEmpty)
              const Text(kNoAuthenticReference, style: TextStyle(color: Islam307Theme.textMuted))
            else
              ...widget.verses.map((r) {
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
                );
              }),
            const SizedBox(height: 12),
            const Text('Related Words', style: TextStyle(fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep)),
            const SizedBox(height: 8),
            if (widget.similar.isEmpty)
              const Text(kNoAuthenticReference, style: TextStyle(color: Islam307Theme.textMuted))
            else
              ...widget.similar.map(
                (r) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(r.textAr, textAlign: TextAlign.right, style: Islam307Theme.arabic(size: 20, height: 1.5)),
                  subtitle: Text(
                    '${r.surah}:${r.ayah} · ${r.meaningEn.isNotEmpty ? r.meaningEn : (r.meaningUr.isNotEmpty ? r.meaningUr : kNoAuthenticReference)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    showQuranWordDetailSheet(context, r);
                  },
                ),
              ),
            const SizedBox(height: 12),
            const Text('Arabic Language Analysis', style: TextStyle(fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep)),
            const SizedBox(height: 8),
            _analysisBox([
              'POS: ${w.fieldOrMissing(w.pos)}',
              'Lemma: ${w.fieldOrMissing(w.lemma)}',
              'Syntax: ${w.fieldOrMissing(w.syntaxSummary)}',
              'Morphology: ${w.fieldOrMissing(w.morphology)}',
            ].join('\n')),
            const SizedBox(height: 12),
            const Text('AI Explanation', style: TextStyle(fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep)),
            const SizedBox(height: 4),
            const Text(
              'Explains only authenticated grammar and morphology from the local database. Never generates new meanings.',
              style: TextStyle(fontSize: 12, color: Islam307Theme.textMuted, height: 1.4),
            ),
            const SizedBox(height: 8),
            _analysisBox(w.localAiExplanation()),
            const SizedBox(height: 10),
            Text(
              'Source: ${w.source.isEmpty ? 'quran.db' : w.source}',
              style: const TextStyle(fontSize: 11, color: Islam307Theme.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _analysisBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Islam307Theme.emeraldSoft, borderRadius: BorderRadius.circular(14)),
      child: Text(text, style: const TextStyle(height: 1.55, fontSize: 13)),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(k, style: const TextStyle(fontWeight: FontWeight.w700, color: Islam307Theme.textMuted, fontSize: 13))),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35))),
        ],
      ),
    );
  }

  Widget _block(
    String title,
    String body, {
    TextStyle? style,
    TextAlign align = TextAlign.left,
    TextDirection? direction,
    bool arabic = false,
    VoidCallback? speak,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep))),
              if (trailing != null) trailing,
              if (speak != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: _speaking ? null : speak,
                  icon: const Icon(Icons.volume_up_rounded, size: 18, color: Islam307Theme.emerald),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            body,
            textAlign: arabic ? TextAlign.right : align,
            textDirection: arabic ? TextDirection.rtl : direction,
            style: style ??
                (arabic
                    ? Islam307Theme.arabic(size: 22, height: 1.6)
                    : TextStyle(
                        height: 1.5,
                        fontSize: 15,
                        color: body == kNoAuthenticReference ? Islam307Theme.textMuted : null,
                        fontStyle: body == kNoAuthenticReference ? FontStyle.italic : null,
                      )),
          ),
        ],
      ),
    );
  }
}
