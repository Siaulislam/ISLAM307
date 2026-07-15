import '../database/database_registry.dart';
import '../database/quran_database.dart';
import '../repositories/hadith_repository.dart';
import '../repositories/quran_word_repository.dart';
import 'evidence_scope.dart';
import 'generic_local_database_search.dart';
import 'local_asset_knowledge_search.dart';
import 'personal_state_knowledge.dart';
import 'query_language.dart';
import 'query_terms.dart';

/// Deterministic retrieval-only assistant.
///
/// It never answers from model knowledge: all answer blocks are exact excerpts
/// returned by local databases or local personal state.
class SourceReferenceSearch {
  SourceReferenceSearch({
    required DatabaseRegistry registry,
    QuranDatabase? quran,
    HadithRepository? hadith,
    QuranWordRepository? words,
    GenericLocalDatabaseSearch? generic,
    LocalAssetKnowledgeSearch? assets,
    PersonalStateKnowledge? personal,
  })  : _registry = registry,
        _quran = quran ?? QuranDatabase.instance,
        _hadith = hadith ?? HadithRepository(registry),
        _words = words ?? QuranWordRepository(),
        _generic = generic ?? GenericLocalDatabaseSearch(registry),
        _assets = assets ?? LocalAssetKnowledgeSearch(),
        _personal = personal ?? PersonalStateKnowledge();

  final DatabaseRegistry _registry;
  final QuranDatabase _quran;
  final HadithRepository _hadith;
  final QuranWordRepository _words;
  final GenericLocalDatabaseSearch _generic;
  final LocalAssetKnowledgeSearch _assets;
  final PersonalStateKnowledge _personal;

  static const noReferenceMessage =
      'The requested information is not available in the current local database.';

  Future<SourceReferenceResult> search(
    String question, {
    EvidenceScope? scopeOverride,
  }) async {
    final query = question.trim();
    final language = QueryLanguageDetector.detect(query);
    if (query.isEmpty) {
      return SourceReferenceResult.empty(
        _notFound(language),
        language: language,
      );
    }

    final explicitScope = EvidenceScopeDetector.detect(query);
    final effectiveScope = scopeOverride ?? explicitScope;
    final terms = QueryTerms.extract(query);
    if (terms.isEmpty) {
      return SourceReferenceResult.empty(
        _notFound(language),
        language: language,
      );
    }
    final searchQuran =
        effectiveScope == null || effectiveScope != EvidenceScope.hadith;
    final searchHadith =
        effectiveScope == null || effectiveScope != EvidenceScope.quran;

    final quranRows = searchQuran
        ? await _searchTerms(
            terms,
            (term) => _quran.search(term, limit: 8),
          )
        : const <Map<String, dynamic>>[];
    final hadithRows = searchHadith
        ? await _searchTerms(
            terms,
            (term) => _hadith.search(term, limit: 8),
          )
        : const <Map<String, dynamic>>[];
    final wordRows = searchQuran
        ? await _searchTerms(
            terms,
            (term) => _words.search(term, limit: 8),
          )
        : const [];

    if (scopeOverride == null &&
        explicitScope == null &&
        quranRows.isNotEmpty &&
        hadithRows.isNotEmpty) {
      return SourceReferenceResult.scopeChoice(
        message: _scopeQuestion(language),
        language: language,
      );
    }

    final refs = <SourceReference>[
      ...quranRows.map((row) => _quranReference(row, language)),
      ...hadithRows.map((row) => _hadithReference(row, language)),
      ...wordRows.map(
        (word) => SourceReference(
          type: SourceType.word,
          sourceId: 'quran',
          title:
              'Quran word · ${word.surah}:${word.ayah}:${word.wordNumber} · ${word.textAr}',
          excerpt: _wordExcerpt(word, language),
          reference:
              'Quran ${word.surah}:${word.ayah} · Word ${word.wordNumber}',
          surah: word.surah,
          ayah: word.ayah,
          route: '/quran/read/${word.surah}/${word.ayah}',
        ),
      ),
    ];

    final genericDatabases = switch (effectiveScope) {
      EvidenceScope.quran => _registry.namesForEvidenceScope('quran'),
      EvidenceScope.hadith => _registry.namesForEvidenceScope('hadith'),
      EvidenceScope.both => {
          ..._registry.namesForEvidenceScope('quran'),
          ..._registry.namesForEvidenceScope('hadith'),
        },
      _ => _registry.registeredNames.toSet(),
    };
    final genericHits = await _generic.search(
      terms,
      language: language,
      databases: genericDatabases,
      limit: 12,
    );
    refs.addAll(genericHits.map((hit) {
      final type = switch (hit.database) {
        'quran' => SourceType.quran,
        'hadith' => SourceType.hadith,
        'narrators' => SourceType.narrator,
        _ => SourceType.app,
      };
      return SourceReference(
        type: type,
        sourceId: hit.database,
        title: hit.title,
        excerpt: hit.excerpt,
        reference: hit.reference,
      );
    }));

    if (effectiveScope == null) {
      final personalHits = <PersonalKnowledgeHit>[];
      final assetHits = <AssetKnowledgeHit>[];
      for (final term in terms) {
        personalHits.addAll(
          await _personal.search(term, language: language),
        );
        assetHits.addAll(await _assets.search(term));
      }
      refs.addAll(personalHits.map(
        (hit) => SourceReference(
          type: SourceType.personal,
          sourceId: 'personal',
          title: hit.title,
          excerpt: hit.excerpt,
          reference: hit.reference,
        ),
      ));
      refs.addAll(assetHits.map(
        (hit) => SourceReference(
          type: SourceType.app,
          sourceId: 'assets',
          title: hit.title,
          excerpt: hit.excerpt,
          reference: hit.reference,
        ),
      ));
    }

    final filtered = _deduplicate(refs)
      ..sort((a, b) {
        final coverage = _termCoverage(b, terms).compareTo(
          _termCoverage(a, terms),
        );
        if (coverage != 0) return coverage;
        final priority =
            _sourcePriority(a.type).compareTo(_sourcePriority(b.type));
        if (priority != 0) return priority;
        final reference = a.reference.compareTo(b.reference);
        if (reference != 0) return reference;
        final source = a.sourceId.compareTo(b.sourceId);
        if (source != 0) return source;
        final title = a.title.compareTo(b.title);
        if (title != 0) return title;
        return a.excerpt.compareTo(b.excerpt);
      });
    if (filtered.isEmpty) {
      return SourceReferenceResult.empty(
        _notFound(language),
        language: language,
      );
    }
    return SourceReferenceResult(
      references: filtered,
      answerText: _composeAnswer(query, filtered, language),
      language: language,
      selectedScope: effectiveScope,
    );
  }

  Future<List<T>> _safe<T>(Future<List<T>> Function() request) async {
    try {
      return await request();
    } catch (_) {
      return <T>[];
    }
  }

  Future<List<T>> _searchTerms<T>(
    List<String> terms,
    Future<List<T>> Function(String term) search,
  ) async {
    final rows = <T>[];
    for (final term in terms) {
      rows.addAll(await _safe(() => search(term)));
    }
    return rows;
  }

  SourceReference _quranReference(
    Map<String, dynamic> row,
    QueryLanguage language,
  ) {
    final surah = row['surah_number'] as int?;
    final ayah = row['ayah_number'] as int?;
    final reference = 'Quran ${surah ?? '—'}:${ayah ?? '—'}';
    return SourceReference(
      type: SourceType.quran,
      sourceId: 'quran',
      title: '$reference · ${row['name_en'] ?? row['name_ar'] ?? ''}',
      excerpt: _pickText(
        row,
        language,
        arabic: const ['text_uthmani'],
        urdu: const ['translation_ur'],
        english: const ['translation_en'],
      ),
      reference: reference,
      surah: surah,
      ayah: ayah,
      route:
          surah == null || ayah == null ? null : '/quran/read/$surah/$ayah',
    );
  }

  SourceReference _hadithReference(
    Map<String, dynamic> row,
    QueryLanguage language,
  ) {
    final bookId = row['book_id'] as int?;
    final number = row['hadith_number'] as int?;
    final book = '${row['book_name'] ?? row['book_slug'] ?? 'Hadith'}';
    final grading = HadithRepository.gradingSummary(row);
    final storedReference = '${row['reference'] ?? ''}'.trim();
    final referenceBook = row['reference_book'];
    final referenceHadith = row['reference_hadith'];
    final reference = storedReference.isNotEmpty
        ? storedReference
        : referenceBook != null &&
                '$referenceBook' != '0' &&
                referenceHadith != null
            ? '$book · Book $referenceBook · Hadith $referenceHadith'
            : '$book · Hadith ${number ?? '—'}';
    return SourceReference(
      type: SourceType.hadith,
      sourceId: 'hadith',
      title: reference,
      excerpt: _pickText(
        row,
        language,
        arabic: const ['text_ar'],
        urdu: const ['text_ur'],
        english: const ['text_en'],
      ),
      reference: reference,
      hadithBook: book,
      hadithBookId: bookId,
      hadithNumber: number,
      grade: grading.grade,
      scholar: grading.scholar,
      route: bookId == null || number == null
          ? null
          : '/hadith/read/$bookId/$number',
    );
  }

  String _wordExcerpt(dynamic word, QueryLanguage language) {
    final values = switch (language) {
      QueryLanguage.urdu => [
          if (word.meaningUr.isNotEmpty) word.meaningUr,
        ],
      QueryLanguage.arabic => [
          if (word.textAr.isNotEmpty) word.textAr,
          if (word.root.isNotEmpty) 'الجذر: ${word.root}',
          if (word.lemma.isNotEmpty) 'الكلمة: ${word.lemma}',
        ],
      QueryLanguage.english => [
          if (word.meaningEn.isNotEmpty) word.meaningEn,
        ],
    };
    return values.join('\n');
  }

  String _pickText(
    Map<String, dynamic> row,
    QueryLanguage language, {
    required List<String> arabic,
    required List<String> urdu,
    required List<String> english,
  }) {
    final keys = switch (language) {
      QueryLanguage.arabic => arabic,
      QueryLanguage.urdu => urdu,
      QueryLanguage.english => english,
    };
    for (final key in keys) {
      final value = '${row[key] ?? ''}'.trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  List<SourceReference> _deduplicate(List<SourceReference> rows) {
    final seen = <String>{};
    return rows.where((row) {
      if (row.excerpt.trim().isEmpty) return false;
      final key = '${row.reference}\u0000${row.excerpt.trim()}';
      return seen.add(key);
    }).toList();
  }

  int _sourcePriority(SourceType type) {
    return switch (type) {
      SourceType.quran => 0,
      SourceType.hadith => 1,
      SourceType.word => 2,
      SourceType.narrator => 3,
      SourceType.personal => 4,
      SourceType.app => 5,
    };
  }

  int _termCoverage(SourceReference reference, List<String> terms) {
    final text =
        '${reference.title} ${reference.excerpt} ${reference.reference}'
            .toLowerCase();
    return terms
        .where((term) => text.contains(term.toLowerCase()))
        .length;
  }

  String _composeAnswer(
    String question,
    List<SourceReference> refs,
    QueryLanguage language,
  ) {
    final concise = [
      'short',
      'brief',
      'concise',
      'مختصر',
      'باختصار',
    ].any(question.toLowerCase().contains);
    final selected = refs.take(concise ? 1 : 5).toList();
    final intro = switch (language) {
      QueryLanguage.urdu =>
        'مقامی ایپ ڈیٹابیس میں درج ذیل متعلقہ معلومات ملی:',
      QueryLanguage.arabic =>
        'وُجدت المعلومات التالية في قاعدة بيانات التطبيق المحلية:',
      QueryLanguage.english =>
        'I found the following relevant information in the local application database:',
    };
    final referenceLabel = switch (language) {
      QueryLanguage.urdu => 'حوالہ',
      QueryLanguage.arabic => 'المرجع',
      QueryLanguage.english => 'Reference',
    };
    final blocks = selected.asMap().entries.map((entry) {
      final row = entry.value;
      return '${entry.key + 1}. ${row.excerpt}\n$referenceLabel: ${row.reference}';
    });
    return '$intro\n\n${blocks.join('\n\n')}';
  }

  String _scopeQuestion(QueryLanguage language) {
    return switch (language) {
      QueryLanguage.urdu =>
        'کیا آپ جواب قرآن، حدیث، یا دونوں سے چاہتے ہیں؟',
      QueryLanguage.arabic =>
        'هل تريد الإجابة من القرآن أو الحديث أو كليهما؟',
      QueryLanguage.english =>
        'Would you like the answer from the Quran, Hadith, or both?',
    };
  }

  String _notFound(QueryLanguage language) {
    return switch (language) {
      QueryLanguage.urdu =>
        'درخواست کردہ معلومات موجودہ مقامی ڈیٹابیس میں دستیاب نہیں ہیں۔',
      QueryLanguage.arabic =>
        'المعلومات المطلوبة غير متاحة في قاعدة البيانات المحلية الحالية.',
      QueryLanguage.english => noReferenceMessage,
    };
  }
}

enum SourceType { quran, hadith, word, narrator, app, personal }

class SourceReference {
  const SourceReference({
    required this.type,
    required this.sourceId,
    required this.title,
    required this.excerpt,
    required this.reference,
    this.route,
    this.surah,
    this.ayah,
    this.hadithBook,
    this.hadithBookId,
    this.hadithNumber,
    this.grade,
    this.scholar,
  });

  final SourceType type;
  final String sourceId;
  final String title;
  final String excerpt;
  final String reference;
  final String? route;
  final int? surah;
  final int? ayah;
  final String? hadithBook;
  final int? hadithBookId;
  final int? hadithNumber;
  final String? grade;
  final String? scholar;

  List<String> get citationLines {
    return [
      reference,
      if (type == SourceType.hadith)
        'Grade: ${grade ?? HadithRepository.gradeNotVerified}',
      if (scholar != null && scholar!.isNotEmpty) 'Scholar: $scholar',
    ];
  }
}

class SourceReferenceResult {
  const SourceReferenceResult({
    required this.references,
    required this.answerText,
    required this.language,
    this.selectedScope,
    this.needsScopeChoice = false,
  });

  SourceReferenceResult.empty(
    String message, {
    required QueryLanguage language,
  })  : references = const [],
        answerText = message,
        language = language,
        selectedScope = null,
        needsScopeChoice = false;

  SourceReferenceResult.scopeChoice({
    required String message,
    required QueryLanguage language,
  })  : references = const [],
        answerText = message,
        language = language,
        selectedScope = null,
        needsScopeChoice = true;

  final List<SourceReference> references;
  final String answerText;
  final QueryLanguage language;
  final EvidenceScope? selectedScope;
  final bool needsScopeChoice;

  bool get hasReferences => references.isNotEmpty;

  List<SourceReference> byType(SourceType type) =>
      references.where((reference) => reference.type == type).toList();
}
