import '../database/quran_database.dart';
import '../database/user_database.dart';
import '../datasets/dataset_license_registry.dart';
import '../repositories/quran_word_repository.dart';
import 'tafsir_intent.dart';

/// Source-only Islamic search — NEVER generates rulings from itself.
/// Quran and Hadith search locally; explicit verse-Tafseer requests query the
/// official licensed provider at runtime.
class SourceReferenceSearch {
  SourceReferenceSearch({
    QuranDatabase? quran,
    QuranWordRepository? words,
    UserDatabase? userDatabase,
  })  : _quran = quran ?? QuranDatabase.instance,
        _words = words ?? QuranWordRepository(),
        _userDatabase = userDatabase ?? UserDatabase.instance;

  final QuranDatabase _quran;
  final QuranWordRepository _words;
  final UserDatabase _userDatabase;

  static const noReferenceMessage = 'No authentic licensed local reference found.';

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
      return SourceReferenceResult.empty(
        'Offline Tafseer is permission pending. No Tafseer has been imported, and AI will not stream or generate a substitute for Quran ${tafsirIntent.surah}:${tafsirIntent.ayah}.',
      );
    }

    final quranHits = await _quran.search(q, limit: 5);
    final wordHits = await _words.search(q, limit: 8);
    final userHits = await _userDatabase.searchUserData(q, limit: 8);
    final featureHits = (await DatasetLicenseRegistry.instance.features())
        .where(
          (feature) =>
              feature.title.toLowerCase().contains(q.toLowerCase()),
        );

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
      ...userHits.map((row) => SourceReference(
            type: SourceType.user,
            title: '${row['title'] ?? 'Personal note'}',
            excerpt: '${row['body'] ?? ''}',
            targetUri: row['target_uri'] as String?,
          )),
      ...featureHits.map((feature) => SourceReference(
            type: SourceType.feature,
            title: feature.title,
            excerpt: 'Offline module · license-gated',
            targetUri: feature.route,
          )),
    ];

    if (refs.isEmpty) {
      return SourceReferenceResult.empty(noReferenceMessage);
    }
    return SourceReferenceResult(references: refs, answerExcerpt: refs.first.excerpt);
  }
}

enum SourceType { quran, hadith, tafsir, word, user, feature }

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
    this.targetUri,
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
  final String? targetUri;

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
