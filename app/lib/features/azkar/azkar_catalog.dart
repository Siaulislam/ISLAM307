/// Built-in authentic dhikr phrases for the Azkar Tasbeeh counter.
class AzkarDhikr {
  const AzkarDhikr({
    required this.id,
    required this.arabic,
    required this.transliteration,
    required this.meaning,
    this.defaultTarget = 33,
  });

  final String id;
  final String arabic;
  final String transliteration;
  final String meaning;
  final int defaultTarget;
}

const List<AzkarDhikr> kAzkarCatalog = [
  AzkarDhikr(
    id: 'subhanallah',
    arabic: 'سُبْحَانَ ٱللَّهِ',
    transliteration: 'SubhanAllah',
    meaning: 'Glory be to Allah',
    defaultTarget: 33,
  ),
  AzkarDhikr(
    id: 'alhamdulillah',
    arabic: 'ٱلْحَمْدُ لِلَّهِ',
    transliteration: 'Alhamdulillah',
    meaning: 'All praise is for Allah',
    defaultTarget: 33,
  ),
  AzkarDhikr(
    id: 'allahu_akbar',
    arabic: 'ٱللَّهُ أَكْبَرُ',
    transliteration: 'Allahu Akbar',
    meaning: 'Allah is the Greatest',
    defaultTarget: 33,
  ),
  AzkarDhikr(
    id: 'tahlil',
    arabic: 'لَا إِلَٰهَ إِلَّا ٱللَّهُ',
    transliteration: 'La ilaha illallah',
    meaning: 'There is no god but Allah',
    defaultTarget: 100,
  ),
  AzkarDhikr(
    id: 'astaghfirullah',
    arabic: 'أَسْتَغْفِرُ ٱللَّهَ',
    transliteration: 'Astaghfirullah',
    meaning: 'I seek forgiveness from Allah',
    defaultTarget: 100,
  ),
  AzkarDhikr(
    id: 'salawat',
    arabic: 'ٱللَّهُمَّ صَلِّ عَلَىٰ مُحَمَّدٍ',
    transliteration: 'Allahumma salli ala Muhammad',
    meaning: 'O Allah, send blessings upon Muhammad',
    defaultTarget: 100,
  ),
];
