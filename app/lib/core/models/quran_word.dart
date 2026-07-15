import 'quran_grammar.dart';

/// Offline Quran word knowledge row (QAC morphology + authenticated glosses).
class QuranWord {
  const QuranWord({
    required this.id,
    required this.surah,
    required this.ayah,
    required this.wordNumber,
    required this.textAr,
    this.textImlaei = '',
    this.transliteration = '',
    this.meaningEn = '',
    this.meaningUr = '',
    this.meaningHi = '',
    this.meaningBn = '',
    this.meaningId = '',
    this.meaningTr = '',
    this.meaningFa = '',
    this.root = '',
    this.lemma = '',
    this.pos = '',
    this.morphology = '',
    this.grammarSummary = '',
    this.syntaxSummary = '',
    this.occurrenceCount = 0,
    this.occurrenceSurface = 0,
    this.occurrenceLemma = 0,
    this.occurrenceRoot = 0,
    this.source = '',
    this.parts = const [],
  });

  final int id;
  final int surah;
  final int ayah;
  final int wordNumber;
  final String textAr;
  final String textImlaei;
  final String transliteration;
  final String meaningEn;
  final String meaningUr;
  final String meaningHi;
  final String meaningBn;
  final String meaningId;
  final String meaningTr;
  final String meaningFa;
  final String root;
  final String lemma;
  final String pos;
  final String morphology;
  final String grammarSummary;
  final String syntaxSummary;
  final int occurrenceCount;
  final int occurrenceSurface;
  final int occurrenceLemma;
  final int occurrenceRoot;
  final String source;
  final List<QuranWordPart> parts;

  factory QuranWord.fromMap(Map<String, dynamic> m, {List<QuranWordPart> parts = const []}) {
    int asInt(dynamic v) => (v as int?) ?? 0;
    return QuranWord(
      id: m['id'] as int,
      surah: m['surah'] as int,
      ayah: m['ayah'] as int,
      wordNumber: m['word_number'] as int,
      textAr: '${m['text_ar'] ?? ''}',
      textImlaei: '${m['text_imlaei'] ?? ''}',
      transliteration: '${m['transliteration'] ?? ''}',
      meaningEn: '${m['meaning_en'] ?? ''}',
      meaningUr: '${m['meaning_ur'] ?? ''}',
      meaningHi: '${m['meaning_hi'] ?? ''}',
      meaningBn: '${m['meaning_bn'] ?? ''}',
      meaningId: '${m['meaning_id'] ?? ''}',
      meaningTr: '${m['meaning_tr'] ?? ''}',
      meaningFa: '${m['meaning_fa'] ?? ''}',
      root: '${m['root'] ?? ''}',
      lemma: '${m['lemma'] ?? ''}',
      pos: '${m['pos'] ?? ''}',
      morphology: '${m['morphology'] ?? ''}',
      grammarSummary: '${m['grammar_summary'] ?? ''}',
      syntaxSummary: '${m['syntax_summary'] ?? ''}',
      occurrenceCount: asInt(m['occurrence_count']),
      occurrenceSurface: asInt(m['occurrence_surface']),
      occurrenceLemma: asInt(m['occurrence_lemma']),
      occurrenceRoot: asInt(m['occurrence_root']),
      source: '${m['source'] ?? ''}',
      parts: parts,
    );
  }

  String get reference => '$surah:$ayah:$wordNumber';

  /// Authenticated word gloss for a UI language code (never invents).
  String meaningForLang(String? lang) {
    switch ((lang ?? '').trim()) {
      case 'ur':
        return meaningUr;
      case 'en':
        return meaningEn;
      case 'hi':
        return meaningHi;
      case 'bn':
        return meaningBn;
      case 'id':
        return meaningId;
      case 'tr':
        return meaningTr;
      case 'fa':
        return meaningFa;
      default:
        return '';
    }
  }

  QuranGrammarAnalysis get grammarAnalysis {
    final feats = parts.map((p) => p.features).where((f) => f.isNotEmpty);
    if (feats.isNotEmpty) return QuranGrammarAnalysis.fromFeatures(feats);
    if (morphology.isNotEmpty) return QuranGrammarAnalysis.fromFeatures([morphology]);
    return const QuranGrammarAnalysis();
  }

  String fieldOrMissing(String value) => value.trim().isEmpty ? kNoAuthenticReference : value;

  String localAiExplanation({String? lang}) {
    final selected = meaningForLang(lang);
    final lines = <String>[
      'Arabic: $textAr',
      'Urdu: ${fieldOrMissing(meaningUr)}',
      if (lang != null && lang.isNotEmpty && lang != 'ur')
        '${lang.toUpperCase()}: ${fieldOrMissing(selected)}',
      'English: ${fieldOrMissing(meaningEn)}',
      'Transliteration: ${fieldOrMissing(transliteration)}',
      'Root: ${fieldOrMissing(root)}',
      'Lemma: ${fieldOrMissing(lemma)}',
      'Part of speech: ${fieldOrMissing(pos)}',
      'Grammar: ${fieldOrMissing(grammarSummary)}',
      'Morphology: ${fieldOrMissing(morphology)}',
      'Syntax: ${fieldOrMissing(syntaxSummary)}',
      'This word form: ${occurrenceSurface > 0 ? occurrenceSurface : '—'}',
      'Same lemma: ${occurrenceLemma > 0 ? occurrenceLemma : '—'}',
      'Same root: ${occurrenceRoot > 0 ? occurrenceRoot : '—'}',
      'Reference: $surah:$ayah (word $wordNumber)',
      'Source: ${source.isEmpty ? 'quran.db' : source}',
    ];
    return lines.join('\n');
  }
}

class QuranWordPart {
  const QuranWordPart({
    required this.partIndex,
    this.formBw = '',
    this.tag = '',
    this.features = '',
  });

  final int partIndex;
  final String formBw;
  final String tag;
  final String features;

  factory QuranWordPart.fromMap(Map<String, dynamic> m) {
    return QuranWordPart(
      partIndex: m['part_index'] as int,
      formBw: '${m['form_bw'] ?? ''}',
      tag: '${m['tag'] ?? ''}',
      features: '${m['features'] ?? ''}',
    );
  }

  String get role {
    final f = features.toUpperCase();
    if (f.contains('PREFIX')) return 'Prefix';
    if (f.contains('SUFFIX')) return 'Suffix';
    if (f.contains('STEM')) return 'Stem';
    return 'Segment';
  }
}
