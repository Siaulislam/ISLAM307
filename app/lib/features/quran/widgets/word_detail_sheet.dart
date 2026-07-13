import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/audio/tts_service.dart';
import '../../core/models/quran_grammar.dart';
import '../../core/models/quran_word.dart';
import '../../core/repositories/quran_word_repository.dart';
import '../../core/theme/islam307_theme.dart';
import 'root_detail_sheet.dart';

const _langLabels = <String, String>{
  'ur': 'اردو',
  'en': 'English',
  'hi': 'हिन्दी',
  'bn': 'বাংলা',
  'id': 'Indonesia',
  'tr': 'Türkçe',
  'fa': 'فارسی',
};

String _langTitle(String? lang) => _langLabels[lang] ?? (lang?.toUpperCase() ?? '');

/// Instant word popup → optional full Word Details (authenticated quran.db only).
Future<void> showQuranWordQuickSheet(BuildContext context, QuranWord seed, {String? preferredLang}) async {
  final repo = QuranWordRepository();
  final word = await repo.wordById(seed.id) ?? seed;
  if (!context.mounted) return;
  final lang = preferredLang?.trim().isNotEmpty == true ? preferredLang!.trim() : 'ur';
  final selected = word.meaningForLang(lang);

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
              Text('لفظ کا مطلب · ${word.reference}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
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
              if (lang != 'ur') ...[
                const SizedBox(height: 8),
                Text(_langTitle(lang), style: const TextStyle(fontWeight: FontWeight.w700, color: Islam307Theme.emeraldDeep, fontSize: 12)),
                Text(
                  selected.isEmpty ? kNoAuthenticReference : selected,
                  textAlign: (lang == 'fa') ? TextAlign.right : TextAlign.left,
                  textDirection: lang == 'fa' ? TextDirection.rtl : TextDirection.ltr,
                  style: lang == 'fa' ? Islam307Theme.urdu(size: 18) : const TextStyle(height: 1.45, fontSize: 15),
                ),
              ],
              if (word.meaningEn.isNotEmpty && lang != 'en') ...[
                const SizedBox(height: 6),
                Text(word.meaningEn, style: const TextStyle(height: 1.45, fontSize: 14, color: Islam307Theme.textMuted)),
              ],
              if (word.root.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('جذر · ${word.root}', textAlign: TextAlign.right, style: Islam307Theme.arabic(size: 20)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  showQuranWordDetailSheet(context, word, preferredLang: lang);
                },
                child: const Text('مزید · مکمل لفظی تجزیہ'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> showQuranWordDetailSheet(BuildContext context, QuranWord seed, {String? preferredLang}) async {
  final repo = QuranWordRepository();
  final word = await repo.wordById(seed.id) ?? seed;
  final similar = await repo.similarWords(word, limit: 16);
  final verses = await repo.versesContainingWord(word, limit: 60);
  if (!context.mounted) return;
  final lang = preferredLang?.trim().isNotEmpty == true ? preferredLang!.trim() : 'ur';

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
      child: _WordDetailBody(word: word, similar: similar, verses: verses, preferredLang: lang),
    ),
  );
}

class _WordDetailBody extends StatefulWidget {
  const _WordDetailBody({
    required this.word,
    required this.similar,
    required this.verses,
    required this.preferredLang,
  });

  final QuranWord word;
  final List<QuranWord> similar;
  final List<Map<String, dynamic>> verses;
  final String preferredLang;

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

  String _ttsFor(String lang) {
    return switch (lang) {
      'ur' => 'ur-PK',
      'en' => 'en-US',
      'hi' => 'hi-IN',
      'bn' => 'bn-BD',
      'id' => 'id-ID',
      'tr' => 'tr-TR',
      'fa' => 'fa-IR',
      _ => 'en-US',
    };
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.word;
    final g = w.grammarAnalysis;
    final lang = widget.preferredLang;
    final selected = w.meaningForLang(lang);
    final height = MediaQuery.sizeOf(context).height * 0.92;
    final surface = w.occurrenceSurface;
    final lemmaOcc = w.occurrenceLemma;
    final rootOcc = w.occurrenceRoot;

    return SafeArea(
      child: SizedBox(
        height: height,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('تفصیل لفظ · ${w.reference}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                ),
                IconButton(
                  tooltip: 'Speak Arabic',
                  onPressed: _speaking ? null : () => _speak(w.textAr, 'ar-SA'),
                  icon: const Icon(Icons.volume_up_rounded, color: Islam307Theme.emerald),
                ),
                IconButton(
                  tooltip: 'Copy',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: w.localAiExplanation(lang: lang)));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
                  },
                  icon: const Icon(Icons.copy_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(w.textAr, textAlign: TextAlign.right, style: Islam307Theme.arabic(size: 36)),
            _block('عربی لفظ', w.textAr, arabic: true, speak: () => _speak(w.textAr, 'ar-SA')),
            _block(
              'اردو معنی',
              w.fieldOrMissing(w.meaningUr),
              style: Islam307Theme.urdu(size: 20),
              align: TextAlign.right,
              direction: TextDirection.rtl,
              speak: w.meaningUr.isEmpty ? null : () => _speak(w.meaningUr, 'ur-PK'),
            ),
            if (lang != 'ur')
              _block(
                '${_langTitle(lang)} معنی',
                w.fieldOrMissing(selected),
                align: lang == 'fa' ? TextAlign.right : TextAlign.left,
                direction: lang == 'fa' ? TextDirection.rtl : TextDirection.ltr,
                style: lang == 'fa' ? Islam307Theme.urdu(size: 18) : null,
                speak: selected.isEmpty ? null : () => _speak(selected, _ttsFor(lang)),
              ),
            if (lang != 'en')
              _block(
                'English Meaning',
                w.fieldOrMissing(w.meaningEn),
                speak: w.meaningEn.isEmpty ? null : () => _speak(w.meaningEn, 'en-US'),
              ),
            _block('تلفظ', w.fieldOrMissing(w.transliteration)),
            _block(
              'جذر حروف',
              w.fieldOrMissing(w.root),
              arabic: w.root.isNotEmpty,
              trailing: w.root.isEmpty
                  ? null
                  : TextButton(
                      onPressed: () => showQuranRootDetailSheet(context, w.root, preferredLang: lang),
                      child: const Text('جذر کھولیں'),
                    ),
            ),
            _block('نحو / گرامر', w.fieldOrMissing(w.grammarSummary)),
            _block('قسم کلمہ', w.fieldOrMissing(w.pos)),
            _block('نحو ترکیب', w.fieldOrMissing(w.syntaxSummary)),
            _block('اسی لفظ کی تعداد (عین شکل)', surface > 0 ? '$surface' : kNoAuthenticReference),
            _block('اسی مادہ/lemma کی تعداد', lemmaOcc > 0 ? '$lemmaOcc' : kNoAuthenticReference),
            _block('اسی جذر کی کل تعداد', rootOcc > 0 ? '$rootOcc' : kNoAuthenticReference),
            const SizedBox(height: 6),
            const Text('گرامر (QAC)', style: TextStyle(fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep)),
            const SizedBox(height: 8),
            if (g.isEmpty)
              const Text(kNoAuthenticReference, style: TextStyle(color: Islam307Theme.textMuted))
            else
              ...g.displayRows.entries.map((e) => _kv(e.key, e.value)),
            const SizedBox(height: 12),
            const Text('وہ آیات جن میں یہی لفظ ہے', style: TextStyle(fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep)),
            const SizedBox(height: 8),
            if (widget.verses.isEmpty)
              const Text(kNoAuthenticReference, style: TextStyle(color: Islam307Theme.textMuted))
            else
              ...widget.verses.map((r) {
                final s = r['surah'] as int;
                final a = r['ayah'] as int;
                final ar = '${r['text_ar'] ?? ''}';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(ar, textAlign: TextAlign.right, style: Islam307Theme.arabic(size: 20, height: 1.5)),
                  subtitle: Text('$s:$a'),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/quran/read/$s/$a');
                  },
                );
              }),
            const SizedBox(height: 12),
            const Text('متعلقہ الفاظ', style: TextStyle(fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep)),
            const SizedBox(height: 8),
            if (widget.similar.isEmpty)
              const Text(kNoAuthenticReference, style: TextStyle(color: Islam307Theme.textMuted))
            else
              ...widget.similar.map(
                (r) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(r.textAr, textAlign: TextAlign.right, style: Islam307Theme.arabic(size: 20, height: 1.5)),
                  subtitle: Text(
                    '${r.surah}:${r.ayah} · ${r.meaningUr.isNotEmpty ? r.meaningUr : r.fieldOrMissing(r.meaningForLang(lang))}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.rtl,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    showQuranWordDetailSheet(context, r, preferredLang: lang);
                  },
                ),
              ),
            const SizedBox(height: 10),
            Text('Source: ${w.source.isEmpty ? 'quran.db' : w.source}', style: const TextStyle(fontSize: 11, color: Islam307Theme.textMuted)),
          ],
        ),
      ),
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
