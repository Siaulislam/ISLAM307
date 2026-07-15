import 'package:flutter_test/flutter_test.dart';
import 'package:islam307/core/ai/query_language.dart';

void main() {
  test('detects English', () {
    expect(
      QueryLanguageDetector.detect('What is patience?'),
      QueryLanguage.english,
    );
  });

  test('detects Urdu', () {
    expect(
      QueryLanguageDetector.detect('نماز کے بارے میں کیا ہے؟'),
      QueryLanguage.urdu,
    );
  });

  test('detects Arabic', () {
    expect(
      QueryLanguageDetector.detect('ما معنى الصبر؟'),
      QueryLanguage.arabic,
    );
  });
}
