import '../database/database_registry.dart';
import '../database/quran_database.dart';
import '../repositories/hadith_repository.dart';
import '../repositories/quran_word_repository.dart';
import '../repositories/tafsir_repository.dart';
import 'tafsir_intent.dart';

/// Source-only Islamic search — NEVER generates rulings from itself.
/// Quran and Hadith search locally; explicit verse-Tafseer requests query the
/// official licensed provider at runtime.
class SourceReferenceSearch {
  SourceReferenceSearch({
    required DatabaseRegistry registry,
    QuranDatabase? quran,
    HadithRepository? hadith,
    TafsirRepository? tafsir,
    QuranWordRepository? words,
  })  : _quran = quran ?? QuranDatabase.instance,
        _hadith = hadith ?? HadithRepository(registry),
        _tafsir = tafsir ?? TafsirRepository(),
        _words = words ?? QuranWordRepository();

  final QuranDatabase _quran;
  final HadithRepository _hadith;
  final TafsirRepository _tafsir;
  final QuranWordRepository _words;

  static const noReferenceMessage = 'No authentic reference found.';

  Future<SourceReferenceResult> search(
    String question, {
    String tafsirSourceSlug = 'ibn-kathir',
  }) async {
    final q = question.trim();
    if (q.isEmpty) {
      return SourceReferenceResult.empty(noReferenceMessage);
    }

    final tafsirIntent = TafsirIntent.parse(q);
    if (tafsirIntent.isTafsirRequest) {
      if (!tafsirIntent.hasVerse) {
        return SourceReferenceResult.empty(
          'Please include a verse reference, for example “Explain Quran 2:255”. Tafseer is never guessed.',
        );
      }
      final entry = await _tafsir.entry(
        tafsirSourceSlug,
        tafsirIntent.surah!,
        tafsirIntent.ayah!,
      );
      if (entry == null || entry['unavailable'] == true) {
        return SourceReferenceResult.empty(
          [
            entry?['message'] ?? TafsirRepository.unavailableMessage,
            if ('${entry?['notes'] ?? ''}'.trim().isNotEmpty) entry!['notes'],
          ].join('\n'),
        );
      }
      final reference = SourceReference(
        type: SourceType.tafsir,
        title:
            'Tafseer · ${entry['source_name']} · ${entry['surah_number']}:${entry['ayah_number']}',
        excerpt: '${entry['text']}',
        surah: entry['surah_number'] as int?,
        ayah: entry['ayah_number'] as int?,
        tafsirSlug: entry['source_slug'] as String?,
        tafsirName: entry['source_name'] as String?,
        tafsirAuthor: entry['author'] as String?,
        tafsirSource: entry['source'] as String?,
        tafsirLanguage: entry['language'] as String?,
        citation: entry['citation'] as String?,
        referenceUrl: entry['reference_url'] as String?,
      );
      return SourceReferenceResult(
        references: [reference],
        answerExcerpt: reference.excerpt,
      );
    }

    final quranHits = await _quran.search(q, limit: 5);
    final hadithHits = await _hadith.search(q, limit: 5);
    final wordHits = await _words.search(q, limit: 8);

    final refs = <SourceReference>[
      ...quranHits.map((r) => SourceReference(
            type: SourceType.quran,
            title: 'Quran · ${r['name_en']} · ${r['surah_number']}:${r['ayah_number']}',
            excerpt: (r['translation_en'] as String?) ??
                (r['translation_ur'] as String?) ??
                (r['text_uthmani'] as String? ?? ''),
            surah: r['surah_number'] as int?,
            ayah: r['ayah_number'] as int?,
          )),
      ...hadithHits.map((r) {
        final grading = HadithRepository.gradingSummary(r);
        return SourceReference(
          type: SourceType.hadith,
          title: 'Hadith · ${r['book_name']} · ${r['hadith_number']}',
          excerpt: (r['text_en'] as String?) ?? (r['text_ar'] as String? ?? ''),
          hadithBook: r['book_name'] as String?,
          hadithNumber: r['hadith_number'] as int?,
          grade: grading.grade,
          scholar: grading.scholar,
          // Do not surface sunnah.com / fawazahmed0 reference URLs in AI answers.
          referenceUrl: null,
        );
      }),
      ...wordHits.map((w) => SourceReference(
            type: SourceType.word,
            title: 'Word · ${w.surah}:${w.ayah}:${w.wordNumber} · ${w.textAr}',
            excerpt: [
              if (w.meaningUr.isNotEmpty) 'Urdu: ${w.meaningUr}',
              if (w.meaningEn.isNotEmpty) 'English: ${w.meaningEn}',
              if (w.root.isNotEmpty) 'Root: ${w.root}',
              if (w.grammarSummary.isNotEmpty) 'Grammar: ${w.grammarSummary}',
              if (w.morphology.isNotEmpty) 'Morphology: ${w.morphology}',
            ].join('\n'),
            surah: w.surah,
            ayah: w.ayah,
          )),
    ];

    if (refs.isEmpty) {
      return SourceReferenceResult.empty(noReferenceMessage);
    }
    return SourceReferenceResult(references: refs, answerExcerpt: refs.first.excerpt);
  }
}

enum SourceType { quran, hadith, tafsir, word }

class SourceReference {
  const SourceReference({
    required this.type,
    required this.title,
    required this.excerpt,
    this.surah,
    this.ayah,
    this.hadithBook,
    this.hadithNumber,
    this.tafsirSlug,
    this.tafsirName,
    this.tafsirAuthor,
    this.tafsirSource,
    this.tafsirLanguage,
    this.citation,
    this.grade,
    this.scholar,
    this.referenceUrl,
  });

  final SourceType type;
  final String title;
  final String excerpt;
  final int? surah;
  final int? ayah;
  final String? hadithBook;
  final int? hadithNumber;
  final String? tafsirSlug;
  final String? tafsirName;
  final String? tafsirAuthor;
  final String? tafsirSource;
  final String? tafsirLanguage;
  final String? citation;
  final String? grade;
  final String? scholar;
  final String? referenceUrl;

  /// Display lines required for hadith AI answers.
  List<String> get hadithCitationLines {
    if (type != SourceType.hadith) return [];
    return [
      'Book: ${hadithBook ?? '—'}',
      'Hadith Number: ${hadithNumber ?? '—'}',
      'Grade: ${grade ?? HadithRepository.gradeNotVerified}',
      if (scholar != null && scholar!.isNotEmpty) 'Scholar: $scholar',
      if (referenceUrl != null && referenceUrl!.isNotEmpty) 'Reference: $referenceUrl',
    ];
  }

  List<String> get tafsirCitationLines {
    if (type != SourceType.tafsir) return [];
    return [
      'Tafseer: ${tafsirName ?? '—'}',
      'Author: ${tafsirAuthor ?? '—'}',
      'Source: ${tafsirSource ?? '—'}',
      'Language: ${tafsirLanguage ?? '—'}',
      'Citation: ${citation ?? 'Quran ${surah ?? '—'}:${ayah ?? '—'}'}',
      if (referenceUrl != null && referenceUrl!.isNotEmpty)
        'Reference: $referenceUrl',
    ];
  }
}

class SourceReferenceResult {
  const SourceReferenceResult({required this.references, this.answerExcerpt});
  SourceReferenceResult.empty(String message)
      : references = const [],
        answerExcerpt = message;

  final List<SourceReference> references;
  final String? answerExcerpt;

  bool get hasReferences => references.isNotEmpty;

  List<SourceReference> byType(SourceType type) => references.where((r) => r.type == type).toList();
}
