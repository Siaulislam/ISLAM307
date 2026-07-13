import 'quran_grammar.dart';

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

  QuranGrammarAnalysis get grammarAnalysis {
    final feats = parts.map((p) => p.features).where((f) => f.isNotEmpty);
    if (feats.isNotEmpty) return QuranGrammarAnalysis.fromFeatures(feats);
    if (morphology.isNotEmpty) return QuranGrammarAnalysis.fromFeatures([morphology]);
    return const QuranGrammarAnalysis();
  }

  String fieldOrMissing(String value) => value.trim().isEmpty ? kNoAuthenticReference : value;

  /// Local-only explanation built from authenticated DB fields — never invents.
  String localAiExplanation() {
    final g = grammarAnalysis;
    final lines = <String>[
      'Arabic Language Analysis (local quran.db only)',
      'Arabic: $textAr',
      'Urdu: ${fieldOrMissing(meaningUr)}',
      'English: ${fieldOrMissing(meaningEn)}',
      'Transliteration: ${fieldOrMissing(transliteration)}',
      'Root: ${fieldOrMissing(root)}',
      'Lemma: ${fieldOrMissing(lemma)}',
      'Part of speech: ${fieldOrMissing(pos)}',
      'Grammar: ${fieldOrMissing(grammarSummary)}',
      'Morphology: ${fieldOrMissing(morphology)}',
      'Syntax: ${fieldOrMissing(syntaxSummary)}',
    ];
    for (final e in g.displayRows.entries) {
      lines.add('${e.key}: ${e.value}');
    }
    if (occurrenceCount > 0) {
      lines.add('Root/lemma/form occurrences in Quran: $occurrenceCount');
    }
    lines.add('Reference: $surah:$ayah (word $wordNumber)');
    lines.add('Source: ${source.isEmpty ? 'quran.db' : source}');
    lines.add('AI must not invent meanings — only authenticated fields above.');
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
