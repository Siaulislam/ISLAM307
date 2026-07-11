/// Extract authentic isnad (ravi chain) and reference detail from offline hadith rows.
/// Never invents narrators — only parses authenticated Arabic/Urdu text fields.

const prophetAr = 'رسول اللہ صلی اللہ علیہ وسلم';
const prophetUr = 'نبی کریم محمد صلی اللہ علیہ وسلم';

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

final _urStop = RegExp(
  r'(آپ\s+نے\s+فرمایا|فرمایا\s+کہ|کہ\s+ایک\s+شخص|سے\s+سوال\s+کیا|'
  r'نبی\s+کریم\s+صلی\s+اللہ\s+علیہ\s+وسلم\s+سے\s+سوال|'
  r'رسول\s+اللہ\s+صلی\s+اللہ\s+علیہ\s+وسلم\s+سے\s+سوال)',
  unicode: true,
);

final _leadingVerb = RegExp(
  r'^(?:حدثنا|حدثني|اخبرنا|اخبرني|انبانا|انباني|سمعت|سمع|عن|ان|قال)\s+',
);

final _urHonorific = RegExp(r'\s*(?:رضی|رضى)\s*اللہ\s*(?:عنہا|عنها|عنہ|عنه)\s*', unicode: true);

String _cleanArName(String name) {
  var n = _stripDiac(name);
  n = n.replaceAll(RegExp(r'\s+'), ' ').trim();
  n = n.replaceAll(RegExp(r'^[ ۔،,;:.\-ـ]+|[ ۔،,;:.\-ـ]+$'), '');
  n = n.replaceFirst(_leadingVerb, '');
  n = n.replaceFirst(RegExp(r'\s*(رضي الله عنه|رضي الله عنها|رضى الله عنه|رضى الله عنها).*$'), '');
  return n.trim();
}

String _cleanUrName(String name) {
  var n = name.replaceAll(RegExp(r'\s+'), ' ').trim();
  n = n.replaceAll(_urHonorific, ' ');
  n = n.replaceAll(RegExp(r'\s+'), ' ').trim();
  n = n.replaceFirst(RegExp(r'\s+(نے|سے|کی|کو|وہ|کہتے|ہیں)$'), '');
  return n.trim();
}

List<String> _appendProphet(List<String> names, String label) {
  if (names.isEmpty) return names;
  final joined = names.join(' ');
  if (joined.contains('رسول اللہ') || joined.contains('نبی کریم') || joined.contains('محمد صلی')) {
    return names;
  }
  return [...names, label];
}

(List<String> names, String excerpt) extractRaviChainUrdu(String? textUr) {
  final text = (textUr ?? '').trim();
  if (text.isEmpty) return (<String>[], '');
  final stop = _urStop.firstMatch(text);
  final head = stop != null ? text.substring(0, stop.start).replaceAll(RegExp(r'[ ،,]+$'), '') : (text.length > 560 ? text.substring(0, 560) : text);
  if (head.isEmpty) return (<String>[], '');

  final names = <String>[];
  final seen = <String>{};

  void add(String raw) {
    final name = _cleanUrName(raw);
    if (name.length < 2 || name.length > 100) return;
    if ({'ہم', 'ان', 'انہوں', 'اپنے', 'والد', 'یہ', 'اس', 'حدیث', 'وہ'}.contains(name)) return;
    final key = name.replaceAll(' ', '');
    if (seen.contains(key)) return;
    seen.add(key);
    names.add(name);
  }

  for (final m in RegExp(r'(?:ہم\s*)?کو\s+([^،.]{2,60}?)\s+نے\s+(?:یہ\s+)?(?:حدیث\s+)?بیان\s+کی', unicode: true).allMatches(head)) {
    add(m.group(1)!);
  }
  for (final m in RegExp(r'ہم\s*کو\s+([^،.]{2,60}?)\s+نے\s+خبر\s+دی', unicode: true).allMatches(head)) {
    add(m.group(1)!);
  }
  for (final m in RegExp(
    r'ان\s*کو\s+([^،.]{2,50}?)\s+نے(?:\s+([^،.]{2,50}?)\s+کی\s+روایت\s+سے)?\s*(?:خبر\s+دی|بیان\s+کی)?',
    unicode: true,
  ).allMatches(head)) {
    add(m.group(1)!);
    if (m.group(2) != null) add(m.group(2)!);
  }
  for (final m in RegExp(r'([^\s،,]{2,40})\s+([^\s،,]{2,40})\s+سے\s+روایت\s+کرتے', unicode: true).allMatches(head)) {
    add(m.group(1)!);
    add(m.group(2)!);
  }
  for (final m in RegExp(
    r'(?:^|،|\.|۔)\s*(?:وہ\s+)?([^\s،.]{2,20}(?:\s+[^\s،.]{2,20}){0,3})\s+سے(?=\s*(?:،|۔|\.|$|وہ))',
    unicode: true,
  ).allMatches(head)) {
    final chunk = m.group(1)!;
    if (['نے', 'بیان', 'خبر', 'روایت', 'حدیث', 'کہتے'].any(chunk.contains)) continue;
    add(chunk);
  }
  if (RegExp(r'اپنے\s+والد\s+سے').hasMatch(head)) add('ان کے والد');
  for (final m in RegExp(r'انہوں\s+نے\s+(?!اپنے\s+والد)([^،.]{2,70}?)\s+سے\s+نقل\s+کی', unicode: true).allMatches(head)) {
    add(m.group(1)!);
  }

  return (_appendProphet(names, prophetUr), head.length > 480 ? head.substring(0, 480) : head);
}

(List<String> names, String excerpt) extractRaviChainArabic(String? textAr, {String? primary}) {
  final names = <String>[];
  final seen = <String>{};

  void add(String raw) {
    final name = _cleanArName(raw);
    if (name.length < 2 || name.length > 90) return;
    if ({'قال', 'قالت', 'يقول', 'سمعت', 'عنه', 'عنها', 'ابي', 'ابيه'}.contains(name)) return;
    if (name.contains('"') || name.contains('\u200f')) return;
    final key = name.replaceAll(' ', '');
    if (seen.contains(key)) return;
    seen.add(key);
    names.add(name);
  }

  final text = _stripDiac(textAr ?? '');
  var excerpt = '';
  if (text.isNotEmpty) {
    final stop = _arStop.firstMatch(text);
    final head = stop != null ? text.substring(0, stop.start) : (text.length > 420 ? text.substring(0, 420) : text);
    excerpt = isnadExcerpt(textAr);
    for (final part in head.split(_arSplit)) {
      if (part.trim().isEmpty) continue;
      add(part.split(RegExp(r'(?:قال|انه|يقول|،|,)')).first);
      if (names.length >= 12) break;
    }
  }

  final primaryClean = primary?.trim() ?? '';
  if (primaryClean.isNotEmpty && primaryClean.length < 60 && !primaryClean.contains('(')) {
    final pk = _cleanArName(primaryClean).replaceAll(' ', '');
    if (pk.isNotEmpty && !seen.contains(pk) && !names.contains(primaryClean)) {
      names.add(primaryClean);
    }
  }

  return (_appendProphet(names, prophetAr), excerpt);
}

List<String> extractRaviChain(String? textAr, {String? primary, String? textEn, String? textUr}) {
  final ur = extractRaviChainUrdu(textUr);
  final urPeople = ur.$1.where((n) => !n.contains('نبی کریم') && !n.contains('رسول اللہ')).length;
  if (urPeople >= 2) return ur.$1;

  final ar = extractRaviChainArabic(textAr, primary: primary);
  final arPeople = ar.$1.where((n) => !n.contains('رسول اللہ')).length;
  if (arPeople >= 2) return ar.$1;
  if (ur.$1.isNotEmpty) return ur.$1;
  if (ar.$1.isNotEmpty) return ar.$1;

  final primaryClean = primary?.trim() ?? '';
  if (primaryClean.isNotEmpty) return _appendProphet([primaryClean], prophetUr);
  return const [];
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

String isnadExcerptUrdu(String? textUr, {int maxLen = 480}) {
  final excerpt = extractRaviChainUrdu(textUr).$2;
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
