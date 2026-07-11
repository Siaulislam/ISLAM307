/// Extract authentic isnad (ravi chain) and reference detail from offline hadith rows.
/// Never invents narrators — only parses authenticated Arabic/English text fields.

final _diac = RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED]');

String _stripDiac(String text) {
  return text
      .replaceAll(_diac, '')
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ٱ', 'ا');
}

final _arSplit = RegExp(
  r'(?:^|[\s،,;:]+)'
  r'(?:حدثنا|حدثني|اخبرنا|اخبرني|انبانا|انباني|سمعت|سمع|عن|ان|قال)'
  r'(?:[\s،,;:]+|$)',
  unicode: true,
);

final _arStop = RegExp(
  r'(قال\s+رسول|ان\s+رسول|عن\s+النبي|انه\s+قال|يقول\s*:|سمعت\s+رسول)',
  unicode: true,
);

final _leadingVerb = RegExp(
  r'^(?:حدثنا|حدثني|اخبرنا|اخبرني|انبانا|انباني|سمعت|سمع|عن|ان|قال)\s+',
);

String _cleanName(String name) {
  var n = _stripDiac(name);
  n = n.replaceAll(RegExp(r'\s+'), ' ').trim();
  n = n.replaceAll(RegExp(r'^[ ۔،,;:.\-ـ]+|[ ۔،,;:.\-ـ]+$'), '');
  n = n.replaceFirst(_leadingVerb, '');
  n = n.replaceFirst(RegExp(r'\s*(رضي الله عنه|رضي الله عنها|رضى الله عنه|رضى الله عنها).*$'), '');
  return n.trim();
}

List<String> extractRaviChain(String? textAr, {String? primary, String? textEn}) {
  final names = <String>[];
  final seen = <String>{};

  void add(String raw) {
    final name = _cleanName(raw);
    if (name.length < 2 || name.length > 90) return;
    if ({'قال', 'قالت', 'يقول', 'سمعت', 'عنه', 'عنها', 'ابي', 'ابيه'}.contains(name)) return;
    final key = name.replaceAll(' ', '');
    if (seen.contains(key)) return;
    seen.add(key);
    names.add(name);
  }

  // textEn reserved for future English isnad fallback when Arabic is empty
  final text = _stripDiac(textAr ?? '');
  if (text.isEmpty && (textEn ?? '').trim().isNotEmpty) {
    // Keep primary narrator only when Arabic isnad is absent in source.
  } else if (text.isNotEmpty) {
    final stop = _arStop.firstMatch(text);
    final head = stop != null ? text.substring(0, stop.start) : (text.length > 520 ? text.substring(0, 520) : text);
    for (final part in head.split(_arSplit)) {
      if (part.trim().isEmpty) continue;
      final chunk = part.split(RegExp(r'(?:قال|انه|يقول|،|,)')).first;
      add(chunk);
      if (names.length >= 14) break;
    }
  }

  final primaryClean = primary?.trim() ?? '';
  if (primaryClean.isNotEmpty) {
    final pk = _cleanName(primaryClean).replaceAll(' ', '');
    if (pk.isNotEmpty && !seen.contains(pk) && !names.contains(primaryClean)) {
      names.add(primaryClean);
    }
  }

  return names;
}

String isnadExcerpt(String? textAr, {int maxLen = 420}) {
  final text = (textAr ?? '').trim();
  if (text.isEmpty) return '';
  final plain = _stripDiac(text);
  final stop = _arStop.firstMatch(plain);
  if (stop == null) return text.length > maxLen ? text.substring(0, maxLen) : text;
  final cut = (stop.start + 8).clamp(0, text.length);
  final excerpt = text.substring(0, cut).replaceAll(RegExp(r'[ ،,;:]+$'), '');
  return excerpt.length > maxLen ? excerpt.substring(0, maxLen) : excerpt;
}

Map<String, String> buildReferenceDetail({
  required String bookName,
  required String bookSlug,
  required int hadithNumber,
  dynamic referenceBook,
  dynamic referenceHadith,
  String? chapterTitle,
  dynamic chapterNumber,
  String? grade,
}) {
  final volume = (referenceBook == null || '$referenceBook' == '0' || '$referenceBook'.trim().isEmpty)
      ? ''
      : '$referenceBook';
  var hadithRef = (referenceHadith == null || '$referenceHadith'.trim().isEmpty) ? '' : '$referenceHadith';
  if (hadithRef.isEmpty) hadithRef = '$hadithNumber';

  var status = (grade ?? '').trim();
  if (status.isEmpty && (bookSlug == 'bukhari' || bookSlug == 'muslim')) {
    status = 'صحیح';
  }

  final chapter = (chapterTitle ?? '').trim();
  final chNum = chapterNumber == null ? '' : '$chapterNumber';

  return {
    'kitab': chapter,
    'baab': chapter,
    'baab_number': chNum,
    'volume': volume,
    'english_kitab': chapter,
    'english_name': bookName,
    'hadith_number': hadithRef,
    'takhreej': '',
    'status': status,
    'wazahat': '',
    'source_url': 'https://sunnah.com/$bookSlug:$hadithNumber',
    'chapter_number': chNum,
  };
}
