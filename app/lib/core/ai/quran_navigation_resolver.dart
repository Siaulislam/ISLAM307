class QuranNavigationMatch {
  const QuranNavigationMatch({
    required this.surahNumber,
    required this.displayName,
    required this.autoPlay,
  });

  final int surahNumber;
  final String displayName;
  final bool autoPlay;
}

class QuranNavigationResolver {
  static const _openSignals = [
    'open',
    'go to',
    'show',
    'کھولو',
    'کھولیں',
    'دکھاؤ',
    'افتح',
    'اعرض',
  ];

  static const _quranSignals = [
    'quran',
    'qur’an',
    'surah',
    'sura',
    'قرآن',
    'سورہ',
    'سورة',
  ];

  static const _readSignals = [
    'read',
    'recite',
    'play',
    'listen',
    'تلاوت',
    'سناؤ',
    'پڑھو',
    'اقرأ',
    'شغل',
  ];

  static QuranNavigationMatch? resolve(
    String command,
    List<Map<String, dynamic>> surahs,
  ) {
    final lower = command.toLowerCase();
    if (!_openSignals.any(lower.contains) ||
        !_quranSignals.any(lower.contains)) {
      return null;
    }
    final target = _targetText(lower);
    if (target.isEmpty) return null;
    final normalizedTarget = _normalize(target);
    for (final surah in surahs) {
      final names = [
        '${surah['name_en'] ?? ''}',
        '${surah['name_ar'] ?? ''}',
        '${surah['name_transliteration'] ?? ''}',
      ].where((name) => name.trim().isNotEmpty);
      for (final name in names) {
        final normalizedName = _normalize(name);
        final shortName = normalizedName.replaceFirst(
          RegExp(r'^(al|an|as|at)'),
          '',
        );
        if (normalizedTarget.contains(normalizedName) ||
            (shortName.length >= 3 && normalizedTarget.contains(shortName)) ||
            normalizedName.contains(normalizedTarget)) {
          return QuranNavigationMatch(
            surahNumber: surah['number'] as int,
            displayName: name,
            autoPlay: _readSignals.any(lower.contains),
          );
        }
      }
    }
    return null;
  }

  static String _targetText(String command) {
    return command
        .replaceAll(
          RegExp(
            r'\b(open|go to|show|quran|surah|sura|read|recite|play|listen)\b',
          ),
          ' ',
        )
        .replaceAll(
          RegExp(r'کھولو|کھولیں|دکھاؤ|قرآن|سورہ|تلاوت|سناؤ|پڑھو|افتح|اعرض|سورة|اقرأ|شغل'),
          ' ',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('aa', 'a')
        .replaceAll('ee', 'i')
        .replaceAll('oo', 'u')
        .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF]'), '');
  }
}
