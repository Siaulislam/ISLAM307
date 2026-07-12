/// Offline Quran word knowledge row (QAC morphology + glosses).
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
    this.root = '',
    this.lemma = '',
    this.pos = '',
    this.morphology = '',
    this.grammarSummary = '',
    this.syntaxSummary = '',
    this.occurrenceCount = 0,
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
  final String root;
  final String lemma;
  final String pos;
  final String morphology;
  final String grammarSummary;
  final String syntaxSummary;
  final int occurrenceCount;
  final String source;
  final List<QuranWordPart> parts;

  factory QuranWord.fromMap(Map<String, dynamic> m, {List<QuranWordPart> parts = const []}) {
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
      root: '${m['root'] ?? ''}',
      lemma: '${m['lemma'] ?? ''}',
      pos: '${m['pos'] ?? ''}',
      morphology: '${m['morphology'] ?? ''}',
      grammarSummary: '${m['grammar_summary'] ?? ''}',
      syntaxSummary: '${m['syntax_summary'] ?? ''}',
      occurrenceCount: (m['occurrence_count'] as int?) ?? 0,
      source: '${m['source'] ?? ''}',
      parts: parts,
    );
  }

  String get reference => '$surah:$ayah:$wordNumber';

  /// Local-only explanation built from authenticated DB fields — never invents.
  String localAiExplanation() {
    final lines = <String>[
      'Arabic: $textAr',
      if (meaningUr.isNotEmpty) 'Urdu: $meaningUr',
      if (meaningEn.isNotEmpty) 'English: $meaningEn',
      if (transliteration.isNotEmpty) 'Transliteration: $transliteration',
      if (root.isNotEmpty) 'Root: $root',
      if (lemma.isNotEmpty) 'Lemma: $lemma',
      if (pos.isNotEmpty) 'Part of speech: $pos',
      if (grammarSummary.isNotEmpty) 'Grammar: $grammarSummary',
      if (morphology.isNotEmpty) 'Morphology: $morphology',
      if (syntaxSummary.isNotEmpty) 'Syntax: $syntaxSummary',
      if (occurrenceCount > 0) 'Occurrences (same root/lemma/form): $occurrenceCount',
      'Reference: $surah:$ayah (word $wordNumber)',
      'Source: local quran.db only — no generated rulings.',
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
}
