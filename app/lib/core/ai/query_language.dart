enum QueryLanguage { urdu, english, arabic }

class QueryLanguageDetector {
  static final _arabicScript = RegExp(r'[\u0600-\u06FF]');
  static final _latinScript = RegExp(r'[A-Za-z]');
  static final _urduSpecific = RegExp(r'[ٹڈڑںھہےگپچژک]');

  static const _urduWords = {
    'نماز',
    'روزہ',
    'زکوٰۃ',
    'کیا',
    'کیسے',
    'کیوں',
    'مجھے',
    'ہے',
    'ہیں',
    'میں',
    'اور',
    'حدیث',
    'قرآن',
    'تفسیر',
  };

  static QueryLanguage detect(String text) {
    final clean = text.trim();
    if (!_arabicScript.hasMatch(clean)) return QueryLanguage.english;
    if (_urduSpecific.hasMatch(clean)) return QueryLanguage.urdu;
    final words = clean
        .split(RegExp(r'\s+'))
        .map((word) => word.replaceAll(RegExp(r'[^\u0600-\u06FF]'), ''));
    if (words.any(_urduWords.contains)) return QueryLanguage.urdu;
    if (_latinScript.hasMatch(clean)) {
      // Mixed Latin + Arabic-script questions are most commonly Urdu in the
      // supported UI; source text itself remains unchanged.
      return QueryLanguage.urdu;
    }
    return QueryLanguage.arabic;
  }
}
