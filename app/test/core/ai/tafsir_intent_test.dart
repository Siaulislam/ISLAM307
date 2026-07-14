import 'package:flutter_test/flutter_test.dart';
import 'package:islam307/core/ai/tafsir_intent.dart';

void main() {
  test('detects Tafseer request with verse reference', () {
    final intent = TafsirIntent.parse('Please explain this verse 2:255');
    expect(intent.isTafsirRequest, isTrue);
    expect(intent.surah, 2);
    expect(intent.ayah, 255);
  });

  test('requires a verse instead of guessing', () {
    final intent = TafsirIntent.parse('Give me Tafseer');
    expect(intent.isTafsirRequest, isTrue);
    expect(intent.hasVerse, isFalse);
  });

  test('does not treat ordinary search as Tafseer intent', () {
    final intent = TafsirIntent.parse('patience in prayer');
    expect(intent.isTafsirRequest, isFalse);
  });
}
