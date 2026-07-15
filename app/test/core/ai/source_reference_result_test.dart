import 'package:flutter_test/flutter_test.dart';
import 'package:islam307/core/ai/evidence_scope.dart';
import 'package:islam307/core/ai/query_language.dart';
import 'package:islam307/core/ai/source_reference_search.dart';

void main() {
  test('empty result contains no generated evidence', () {
    final result = SourceReferenceResult.empty(
      SourceReferenceSearch.noReferenceMessage,
      language: QueryLanguage.english,
    );
    expect(result.references, isEmpty);
    expect(result.hasReferences, isFalse);
    expect(result.answerText, SourceReferenceSearch.noReferenceMessage);
  });

  test('scope choice contains no premature answer evidence', () {
    final result = SourceReferenceResult.scopeChoice(
      message: 'Would you like the answer from the Quran, Hadith, or both?',
      language: QueryLanguage.english,
    );
    expect(result.needsScopeChoice, isTrue);
    expect(result.references, isEmpty);
  });

  test('stored reference is preserved exactly', () {
    const reference = SourceReference(
      type: SourceType.hadith,
      sourceId: 'hadith',
      title: 'Sahih Muslim · Hadith 1',
      excerpt: 'Stored text',
      reference: 'Sahih Muslim · Hadith 1',
      hadithBook: 'Sahih Muslim',
      hadithNumber: 1,
      grade: 'Sahih',
    );
    expect(reference.citationLines.first, 'Sahih Muslim · Hadith 1');
    expect(reference.citationLines, contains('Grade: Sahih'));
  });

  test('selected scope is retained on completed result', () {
    const result = SourceReferenceResult(
      references: [],
      answerText: 'No data',
      language: QueryLanguage.english,
      selectedScope: EvidenceScope.quran,
    );
    expect(result.selectedScope, EvidenceScope.quran);
  });
}
