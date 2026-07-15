enum EvidenceScope { quran, hadith, both }

class EvidenceScopeDetector {
  static const _quranSignals = {
    'quran',
    'qur’an',
    'قرآن',
    'القرآن',
    'ayah',
    'ayat',
    'آیت',
    'آیات',
    'verse',
    'surah',
    'سورہ',
    'سورة',
  };

  static const _hadithSignals = {
    'hadith',
    'hadees',
    'حدیث',
    'الحديث',
    'sunnah',
    'سنت',
    'bukhari',
    'بخاری',
    'muslim',
    'ترمذی',
    'ابوداؤد',
  };

  static EvidenceScope? detect(String query) {
    final normalized = query.toLowerCase();
    final quran = _quranSignals.any(normalized.contains);
    final hadith = _hadithSignals.any(normalized.contains);
    if (quran && hadith) return EvidenceScope.both;
    if (quran) return EvidenceScope.quran;
    if (hadith) return EvidenceScope.hadith;
    return null;
  }
}
