import 'package:flutter_test/flutter_test.dart';
import 'package:islam307/core/ai/quran_navigation_resolver.dart';

void main() {
  final surahs = <Map<String, dynamic>>[
    {
      'number': 4,
      'name_en': 'An-Nisa',
      'name_ar': 'النساء',
      'name_transliteration': "An-Nisā'",
    },
    {
      'number': 36,
      'name_en': 'Ya-Sin',
      'name_ar': 'يس',
      'name_transliteration': 'Yaseen',
    },
  ];

  test('opens spoken Nisaa command and enables recitation', () {
    final result = QuranNavigationResolver.resolve(
      'Open Quran Surah Nisaa and read',
      surahs,
    );
    expect(result?.surahNumber, 4);
    expect(result?.autoPlay, isTrue);
  });

  test('opens Arabic Surah command', () {
    final result = QuranNavigationResolver.resolve(
      'افتح سورة النساء',
      surahs,
    );
    expect(result?.surahNumber, 4);
    expect(result?.autoPlay, isFalse);
  });

  test('does not navigate without an open command', () {
    expect(
      QuranNavigationResolver.resolve('What is in Surah Nisa?', surahs),
      isNull,
    );
  });
}
