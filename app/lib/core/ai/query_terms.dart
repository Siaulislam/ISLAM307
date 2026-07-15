class QueryTerms {
  static const _stopWords = {
    'a',
    'an',
    'and',
    'answer',
    'about',
    'both',
    'does',
    'explain',
    'for',
    'from',
    'give',
    'hadith',
    'hadees',
    'in',
    'is',
    'me',
    'of',
    'please',
    'quran',
    'say',
    'show',
    'the',
    'this',
    'to',
    'what',
    'would',
    'you',
    'کیا',
    'کے',
    'کی',
    'میں',
    'مجھے',
    'سے',
    'اور',
    'قرآن',
    'حدیث',
    'بتائیں',
    'عن',
    'في',
    'من',
    'ما',
    'هل',
    'القرآن',
    'الحديث',
  };

  static List<String> extract(String query) {
    final clean = query.trim();
    final directReference =
        RegExp(r'\b\d{1,4}\s*[:/]\s*\d{1,4}\b').firstMatch(clean);
    if (directReference != null) {
      return [
        directReference.group(0)!.replaceAll(RegExp(r'\s+'), ''),
      ];
    }
    final words = RegExp(r'[A-Za-z0-9\u0600-\u06FF]+')
        .allMatches(clean.toLowerCase())
        .map((match) => match.group(0)!)
        .where((word) => word.length > 1 && !_stopWords.contains(word))
        .toList();
    final result = <String>[
      ...words,
    ];
    return result.toSet().take(8).toList();
  }
}
