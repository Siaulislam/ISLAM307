import 'package:flutter_test/flutter_test.dart';
import 'package:islam307/core/ai/query_terms.dart';

void main() {
  test('extracts meaningful English terms', () {
    expect(
      QueryTerms.extract('What does the Quran say about patience?'),
      contains('patience'),
    );
    expect(
      QueryTerms.extract('What does the Quran say about patience?'),
      isNot(contains('quran')),
    );
  });

  test('preserves direct references', () {
    expect(QueryTerms.extract('Explain Quran 2 : 255'), contains('2:255'));
  });

  test('extracts Urdu topic and removes request words', () {
    final terms = QueryTerms.extract('مجھے صبر کے بارے میں بتائیں');
    expect(terms, contains('صبر'));
    expect(terms, isNot(contains('مجھے')));
  });
}
