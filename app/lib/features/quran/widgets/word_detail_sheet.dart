import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/audio/tts_service.dart';
import '../../core/models/quran_word.dart';
import '../../core/repositories/quran_word_repository.dart';
import '../../core/theme/islam307_theme.dart';

/// Offline word knowledge sheet — data from quran.db only.
Future<void> showQuranWordDetailSheet(BuildContext context, QuranWord seed) async {
  final repo = QuranWordRepository();
  final word = await repo.wordById(seed.id) ?? seed;
  final related = await repo.relatedByRoot(word.root, excludeId: word.id, limit: 10);
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _WordDetailBody(word: word, related: related),
  );
}

class _WordDetailBody extends StatefulWidget {
  const _WordDetailBody({required this.word, required this.related});

  final QuranWord word;
  final List<QuranWord> related;

  @override
  State<_WordDetailBody> createState() => _WordDetailBodyState();
}

class _WordDetailBodyState extends State<_WordDetailBody> {
  bool _speaking = false;

  Future<void> _speak(String text, String language) async {
    setState(() => _speaking = true);
    final ok = await TtsService.instance.speakOffline(text, language: language);
    if (!mounted) return;
    setState(() => _speaking = false);
    if (!ok) {
      await TtsService.instance.showInstallVoiceGuide(context, language);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.word;
    final height = MediaQuery.sizeOf(context).height * 0.88;
    return SafeArea(
      child: SizedBox(
        height: height,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Word · ${w.surah}:${w.ayah}:${w.wordNumber}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ),
                IconButton(
                  tooltip: 'Speak Arabic word',
                  onPressed: _speaking ? null : () => _speak(w.textAr, 'ar-SA'),
                  icon: const Icon(Icons.volume_up_rounded, color: Islam307Theme.emerald),
                ),
                IconButton(
                  tooltip: 'Copy',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: w.localAiExplanation()));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied word details')));
                  },
                  icon: const Icon(Icons.copy_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(w.textAr, textAlign: TextAlign.right, style: Islam307Theme.arabic(size: 36)),
            if (w.transliteration.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(w.transliteration, style: const TextStyle(color: Islam307Theme.textMuted, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 16),
            _block(
              'Urdu Meaning',
              w.meaningUr.isEmpty ? '—' : w.meaningUr,
              style: Islam307Theme.urdu(size: 20),
              align: TextAlign.right,
              direction: TextDirection.rtl,
              speak: w.meaningUr.isEmpty ? null : () => _speak(w.meaningUr, 'ur-PK'),
            ),
            _block(
              'English Meaning',
              w.meaningEn.isEmpty ? '—' : w.meaningEn,
              speak: w.meaningEn.isEmpty ? null : () => _speak(w.meaningEn, 'en-US'),
            ),
            _block('Root', w.root.isEmpty ? '—' : w.root, arabic: w.root.isNotEmpty),
            _block('Lemma', w.lemma.isEmpty ? '—' : w.lemma, arabic: w.lemma.isNotEmpty),
            _block('Morphology', w.morphology.isEmpty ? '—' : w.morphology),
            _block('Grammar', w.grammarSummary.isEmpty ? '—' : w.grammarSummary),
            _block('Syntax', w.syntaxSummary.isEmpty ? '—' : w.syntaxSummary),
            _block('Part of speech', w.pos.isEmpty ? '—' : w.pos),
            _block('Occurrences', '${w.occurrenceCount}'),
            if (w.parts.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Segments', style: TextStyle(fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep)),
              const SizedBox(height: 8),
              ...w.parts.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${p.partIndex}. ${p.tag} · ${p.features}',
                    style: const TextStyle(fontSize: 13, height: 1.45, color: Islam307Theme.textMuted),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text('Related verses (same root)', style: TextStyle(fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep)),
            const SizedBox(height: 8),
            if (widget.related.isEmpty)
              const Text('No related verses in local database.', style: TextStyle(color: Islam307Theme.textMuted))
            else
              ...widget.related.map(
                (r) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(r.textAr, textAlign: TextAlign.right, style: Islam307Theme.arabic(size: 20, height: 1.6)),
                  subtitle: Text(
                    '${r.surah}:${r.ayah} · ${r.meaningEn.isNotEmpty ? r.meaningEn : r.meaningUr}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/quran/read/${r.surah}/${r.ayah}');
                  },
                ),
              ),
            const SizedBox(height: 12),
            const Text('AI explanation (local database only)', style: TextStyle(fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Islam307Theme.emeraldSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(w.localAiExplanation(), style: const TextStyle(height: 1.55, fontSize: 13)),
            ),
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

  Widget _block(
    String title,
    String body, {
    TextStyle? style,
    TextAlign align = TextAlign.left,
    TextDirection? direction,
    bool arabic = false,
    VoidCallback? speak,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep)),
              ),
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
                    : const TextStyle(height: 1.55, fontSize: 15)),
          ),
        ],
      ),
    );
  }
}
