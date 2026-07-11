/// Extract authentic isnad (rawi chain) from offline hadith rows.
/// Narrators come ONLY from the Isnad (never Matn). Prophet ﷺ is excluded.
/// Preserve ibn/bin/bint/Abu/Umm/al-/ibn Abi. Never invent names.

final _diac = RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED\u0640]');

final _prophetAr = RegExp(
  r'(?:رسول\s*الله|رسول\s*اللہ|النبي\b|النبی\b|نبي\s*الله|نبی\s*اللہ|محمد\s*(?:صلى|صلی|ﷺ))',
  unicode: true,
);

final _prophetEn = RegExp(
  r"(?:Allah'?s\s+Messenger|Messenger\s+of\s+Allah|the\s+Prophet|Prophet\s+Muhammad|Holy\s+Prophet)",
  caseSensitive: false,
);

final _honorificAr = RegExp(
  r'\s*(?:ـ\s*)?(?:رضي|رضى)\s*الله\s*(?:عنهما|عنها|عنهم|عنه)\s*(?:ـ\s*)?',
  unicode: true,
);

final _honorificEn = RegExp(
  r'\s*\((?:may\s+Allah\s+be\s+pleased[^)]*|the\s+mother\s+of\s+the\s+faithful[^)]*)\)\s*',
  caseSensitive: false,
);

const _txVerbs = ['حدثنا', 'حدثني', 'اخبرنا', 'اخبرني', 'انبانا', 'انباني', 'سمعت'];

final _txFind = RegExp(
  r'(?:^|[\s،,;:]+|(?:قال|قالت)\s*:?\s*)'
  r'(حدثنا|حدثني|اخبرنا|اخبرني|انبانا|انباني|سمعت|عن)'
  r'(?=[\s،,;:]+|$)',
  unicode: true,
);

String _stripDiac(String text) => text.replaceAll(_diac, '');

String _foldAr(String text) {
  var t = _stripDiac(text);
  return t
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ٱ', 'ا')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي');
}

String _norm(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();

bool _isProphetToken(String name) {
  final n = _norm(_foldAr(name));
  if (n.isEmpty) return false;
  if (RegExp(
        r'^(?:رسول\s*الله|رسول\s*اللہ|النبي|النبی|نبي\s*الله|نبی\s*اللہ|محمد(?:\s*صلى.*)?|'
        r"allah'?s\s+messenger|the\s+prophet|messenger\s+of\s+allah|prophet\s+muhammad)$",
        caseSensitive: false,
        unicode: true,
      ).hasMatch(n)) {
    return true;
  }
  if (_prophetAr.hasMatch(n) && n.length < 48) return true;
  if (_prophetEn.hasMatch(n) && n.length < 56) return true;
  return false;
}

String _cleanNameAr(String raw) {
  var name = raw.replaceAll(_honorificAr, ' ').replaceAll('ـ', ' ');
  name = _norm(_stripDiac(name)).replaceAll(RegExp(r'^[ ،,;:.\-]+|[ ،,;:.\-]+$'), '');
  var folded = _foldAr(name);
  for (final verb in [..._txVerbs, 'عن']) {
    if (folded == verb || folded.startsWith('$verb ')) {
      name = _norm(name.substring(verb.length)).replaceAll(RegExp(r'^[ ،,;:.\-]+|[ ،,;:.\-]+$'), '');
      folded = _foldAr(name);
      break;
    }
  }
  name = name.split(RegExp(r'\s+(?:قال|قالت|يقول|في\s+قوله|في\s+قول|على\s+المنبر)\b')).first;
  name = _norm(name).replaceAll(RegExp(r'\s+(?:قال|قالت|يقول)\s*$'), '');
  name = name.replaceAll(RegExp(r'\s*,?\s*انه(?:ا)?\s*$'), '');
  name = _norm(name).replaceAll(RegExp(r'^[ ،,;:.\-]+|[ ،,;:.\-]+$'), '');
  if (name.isEmpty || {'قال', 'قالت', 'ان', 'عن', 'و', 'ه', 'ها', 'انه', 'انها'}.contains(name)) {
    return '';
  }
  if (_isProphetToken(name) || name.length > 90) return '';
  return name;
}

String _cleanNameEn(String raw) {
  var name = raw.replaceAll(_honorificEn, ' ');
  name = _norm(name);
  name = name
      .split(RegExp(r'\s+(?:said|reported|asked|while|that|in\s+the|regarding|reporting)\b', caseSensitive: false))
      .first;
  name = _norm(name).replaceAll(RegExp(r'''^[ ,;:.\-'"]+|[ ,;:.\-'"]+$'''), '');
  if (name.isEmpty || _isProphetToken(name) || name.length > 80) return '';
  return name;
}

String _cutIsnadAr(String textAr) {
  final display = _stripDiac(textAr);
  final plain = _foldAr(display);
  if (plain.isEmpty) return '';

  final candidates = <int>[];
  for (final m in RegExp(r'انها\s+قالت|انه\s+قال', unicode: true).allMatches(plain)) {
    candidates.add(m.start);
  }
  for (final m in RegExp(r'\sان\s+(?!ه\s+سمع)', unicode: true).allMatches(plain)) {
    if (_prophetAr.hasMatch(plain.substring(m.start)) &&
        RegExp(r'(?:حدثنا|حدثني|اخبرنا|عن)', unicode: true).hasMatch(plain.substring(0, m.start))) {
      candidates.add(m.start);
    }
  }
  for (final m in RegExp(
    r'(?:قال|قالت|سمعت|سمع|عن|ان|كان|سال)\s+(?:رسول\s*الله|النبي|نبي\s*الله)',
    unicode: true,
  ).allMatches(plain)) {
    candidates.add(m.start);
  }
  for (final m in _prophetAr.allMatches(plain)) {
    if (RegExp(r'(?:حدثنا|حدثني|اخبرنا|عن)', unicode: true).hasMatch(plain.substring(0, m.start))) {
      candidates.add(m.start);
      break;
    }
  }

  int cut;
  if (candidates.isEmpty) {
    final m = RegExp(r'["«»\{]|قوله\s*تعالي', unicode: true).firstMatch(plain);
    cut = m?.start ?? (plain.length < 500 ? plain.length : 500);
  } else {
    final positive = candidates.where((c) => c > 0).toList();
    cut = positive.isEmpty ? candidates.reduce((a, b) => a < b ? a : b) : positive.reduce((a, b) => a < b ? a : b);
  }
  return display.substring(0, cut).replaceAll(RegExp(r'[ ،,;:]+$'), '');
}

List<String> _extractNamesFromArIsnad(String isnad) {
  if (isnad.trim().isEmpty) return [];
  var display = _stripDiac(isnad);
  display = display.replaceAll(RegExp(r'أن(?:ه|ها)?\s+سمع\s+|ان(?:ه|ها)?\s+سمع\s+', unicode: true), ' سمعت ');
  final search = _foldAr(display);
  final matches = _txFind.allMatches(search).toList();
  if (matches.isEmpty) return [];

  final names = <String>[];
  final seen = <String>{};
  for (var i = 0; i < matches.length; i++) {
    final start = matches[i].end;
    final end = i + 1 < matches.length ? matches[i + 1].start : search.length;
    final chunk = display.substring(start, end).replaceAll(RegExp(r'^[ ،,;:]+|[ ،,;:]+$'), '');
    if (chunk.isEmpty) continue;
    final folded = _foldAr(chunk);
    if (RegExp(r'^(?:انها\s+قالت|انه\s+قال|قال\s+رسول|قالت\s+رسول)', unicode: true).hasMatch(folded)) break;
    if (_isProphetToken(chunk)) break;
    final name = _cleanNameAr(chunk);
    if (name.isEmpty || _isProphetToken(name)) {
      if (_isProphetToken(name)) break;
      continue;
    }
    final key = _foldAr(name).replaceAll(' ', '');
    if (seen.contains(key)) continue;
    seen.add(key);
    names.add(name);
    if (names.length >= 16) break;
  }
  return names;
}

String _cutIsnadEn(String textEn) {
  final m = _prophetEn.firstMatch(textEn);
  if (m == null) return textEn.length > 400 ? textEn.substring(0, 400) : textEn;
  return textEn.substring(0, m.start).replaceAll(RegExp(r'[ ,;:]+$'), '');
}

List<String> _extractNarratedEn(String? textEn) {
  final text = (textEn ?? '').trim();
  if (text.isEmpty) return [];
  final head = _prophetEn.hasMatch(text) ? _cutIsnadEn(text) : text.split('.').first;
  final m = RegExp(
    r'^\s*Narrated\s+(.+?)(?:\s*[:.\n]|\s+that\b|\s+said\b|\s+reported\b)',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(head);
  if (m == null) return [];
  final name = _cleanNameEn(m.group(1)!);
  return name.isEmpty ? [] : [name];
}

List<String> extractRaviChain(String? textAr, {String? primary, String? textEn, String? textUr}) {
  final ar = (textAr ?? '').trim();
  final en = (textEn ?? '').trim();
  var names = <String>[];
  if (ar.isNotEmpty) {
    names = _extractNamesFromArIsnad(_cutIsnadAr(ar));
  }
  if (names.isEmpty && en.isNotEmpty) {
    names = _extractNarratedEn(en);
  }
  if (names.isEmpty && (primary ?? '').trim().isNotEmpty) {
    final p = RegExp(r'[A-Za-z]').hasMatch(primary!) ? _cleanNameEn(primary) : _cleanNameAr(primary);
    if (p.isNotEmpty && !_isProphetToken(p)) names = [p];
  }
  return names.where((n) => n.isNotEmpty && !_isProphetToken(n)).toList();
}

String isnadExcerpt(String? textAr, {int maxLen = 480}) {
  final text = (textAr ?? '').trim();
  if (text.isEmpty) return '';
  final plain = _foldAr(text);
  final cutPlain = _cutIsnadAr(text);
  if (cutPlain.isEmpty || plain.isEmpty) return text.length > maxLen ? text.substring(0, maxLen) : text;
  final ratio = cutPlain.length / plain.length;
  final cut = (text.length * ratio).round().clamp(1, text.length);
  final excerpt = text.substring(0, cut).replaceAll(RegExp(r'[ ،,;:]+$'), '');
  return excerpt.length > maxLen ? excerpt.substring(0, maxLen) : excerpt;
}

String isnadExcerptUrdu(String? textUr, {int maxLen = 480}) {
  final text = (textUr ?? '').trim();
  if (text.isEmpty) return '';
  final stop = RegExp(
    r'(آپ\s+نے\s+فرمایا|فرمایا\s+کہ|نبی\s+کریم|رسول\s+اللہ|رسول\s+الله|صلی\s+اللہ\s+علیہ\s+وسلم\s+سے\s+سوال)',
    unicode: true,
  ).firstMatch(text);
  final head = stop != null ? text.substring(0, stop.start).replaceAll(RegExp(r'[ ،,]+$'), '') : text;
  return head.length > maxLen ? head.substring(0, maxLen) : head;
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
