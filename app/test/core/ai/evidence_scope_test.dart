import 'package:flutter_test/flutter_test.dart';
import 'package:islam307/core/ai/evidence_scope.dart';

void main() {
  test('detects Quran evidence request', () {
    expect(
      EvidenceScopeDetector.detect('Show Quran verses about patience'),
      EvidenceScope.quran,
    );
  });

  test('detects Hadith evidence request', () {
    expect(
      EvidenceScopeDetector.detect('Show Hadith about prayer'),
      EvidenceScope.hadith,
    );
  });

  test('detects both sources', () {
    expect(
      EvidenceScopeDetector.detect('Quran and Hadith about charity'),
      EvidenceScope.both,
    );
  });

  test('leaves topic-only question open for evidence choice', () {
    expect(EvidenceScopeDetector.detect('What is patience?'), isNull);
  });
}
