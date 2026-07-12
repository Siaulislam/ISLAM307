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

// Optional leading و (واخبرني / وحدثنا); include ان as transmission.
final _txFind = RegExp(
  r'(?:^|[\s،,;:]+|(?:قال|قالت)\s*:?\s*)'
  r'و?'
  r'(?<verb>حدثنا|حدثني|اخبرنا|اخبرني|انبانا|انباني|سمعت|عن|ان)'
  r'(?=[\s،,;:]+|$)',
  unicode: true,
);

// قال <Name> / قالت <Name> — NOT قال حدثنا / قال أخبرنا / Prophet titles.
final _qalaName = RegExp(
  r'(?:^|[\s،,;:]+)'
  r'(?<verb>قال|قالت)\s+'
  r'(?!'
  r'رسول\s*الله|رسول\s*اللہ|النبي|النبی|نبي\s*الله|'
  r'حدثنا|حدثني|اخبرنا|اخبرني|انبانا|انباني|سمعت|عن\s'
  r')'
  r'(?<name>[^،,;:\n"«»‏]{2,80}?)'
  r'(?=\s*(?:،|,|:|و(?:اخبر|حدث|انبان)|$))',
  unicode: true,
);

final _matnNoise = RegExp(
  r'(?:'
  r'فترة\s*الوحى|فترة\s*الوحي|'
  r'في\s*حديثه|وهو\s*يحدث|'
  r'بينا\s*انا|بينما\s*انا|'
  r'في\s*قوله|قوله\s*تعالى|قوله\s*تعالي|'
  r'نحوه'
  r')',
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

bool _isMatnNoise(String name) {
  final n = _foldAr(name);
  if (_matnNoise.hasMatch(n)) return true;
  if (RegExp(r'^(?:في|وهو|فقال|بينا|بينما|فترة|حديثه|نحوه)\b', unicode: true).hasMatch(n)) {
    return true;
  }
  return false;
}

String _cleanNameAr(String raw) {
  var name = raw.replaceAll(_honorificAr, ' ').replaceAll('ـ', ' ');
  name = _norm(_stripDiac(name)).replaceAll(RegExp(r'^[ ،,;:.\-]+|[ ،,;:.\-]+$'), '');
  var folded = _foldAr(name);
  for (final verb in [..._txVerbs, 'عن', 'ان']) {
    if (folded == verb || folded.startsWith('$verb ')) {
      name = _norm(name.substring(verb.length)).replaceAll(RegExp(r'^[ ،,;:.\-]+|[ ،,;:.\-]+$'), '');
      folded = _foldAr(name);
      break;
    }
  }
  name = name.split(RegExp(r'\s+(?:قال|قالت|يقول|يحدث|تحدث|في\s+قوله|في\s+قول|على\s+المنبر)\b')).first;
  name = _norm(name).replaceAll(RegExp(r'\s+(?:قال|قالت|يقول)\s*$'), '');
  name = name.replaceAll(RegExp(r'(?:،|\s)+في\s*$'), '');
  name = _norm(name).replaceAll(RegExp(r'^[ ،,;:.\-]+|[ ،,;:.\-]+$'), '');
  // Remove dangling انه / انها ONLY — never bare ان (breaks سفيان).
  name = name.replaceAll(RegExp(r'\s*,?\s*انه(?:ا)?\s*$'), '');
  name = _norm(name).replaceAll(RegExp(r'^[ ،,;:.\-]+|[ ،,;:.\-]+$'), '');
  if (name.isEmpty ||
      {'قال', 'قالت', 'ان', 'عن', 'و', 'ه', 'ها', 'انه', 'انها', 'في'}.contains(name)) {
    return '';
  }
  if (_isProphetToken(name)) return '';
  if (RegExp(r'يحدث|تحدث', unicode: true).hasMatch(_foldAr(name))) return '';
  if (name.length > 90) return '';
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

  // Explicit matn / speech openings inside Bukhari-style reports
  for (final pat in [
    r'وهو\s+يحدث',
    r'فقال\s+في\s+حديثه',
    r'قال\s+في\s+حديثه',
    r'بينا\s+انا',
    r'بينما\s+انا',
    r'يحدث\s+عن\s+فترة',
  ]) {
    final m = RegExp(pat, unicode: true).firstMatch(plain);
    if (m != null && m.start > 12) candidates.add(m.start);
  }

  // Companion begins speaking: انها قالت / انه قال (not انه سمع)
  for (final m in RegExp(r'انها\s+قالت|انه\s+قال', unicode: true).allMatches(plain)) {
    candidates.add(m.start);
  }

  // ان <person> … Prophet (matn)
  for (final m in RegExp(r'\sان\s+(?!ه\s+سمع)', unicode: true).allMatches(plain)) {
    if (_prophetAr.hasMatch(plain.substring(m.start)) &&
        RegExp(r'(?:حدثنا|حدثني|اخبرنا|عن|قال\s+\S)', unicode: true)
            .hasMatch(plain.substring(0, m.start))) {
      candidates.add(m.start);
    }
  }

  // Direct report from the Prophet
  for (final m in RegExp(
    r'(?:قال|قالت|سمعت|سمع|عن|ان|كان|سال)\s+(?:رسول\s*الله|النبي|نبي\s*الله)',
    unicode: true,
  ).allMatches(plain)) {
    candidates.add(m.start);
  }

  // First prophet token after a chain exists
  for (final m in _prophetAr.allMatches(plain)) {
    if (RegExp(r'(?:حدثنا|حدثني|اخبرنا|عن|قال\s+\S)', unicode: true)
        .hasMatch(plain.substring(0, m.start))) {
      candidates.add(m.start);
      break;
    }
  }

  // Quran citation / opening quote (matn)
  for (final m in RegExp(r'["«»\{]|قوله\s*تعالي|قوله\s*تعالى', unicode: true).allMatches(plain)) {
    if (m.start > 20) candidates.add(m.start);
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

/// Return (display, search) with aligned offsets (1:1 folding).
(String, String) _prepareIsnadDisplay(String isnad) {
  var display = _stripDiac(isnad);
  // Normalize أنه سمع / انه سمع → سمعت (isnad continuation).
  display = display.replaceAll(
    RegExp(r'أن(?:ه|ها)?\s+سمع\s+|ان(?:ه|ها)?\s+سمع\s+', unicode: true),
    ' سمعت ',
  );
  // Bukhari parallel isnad marker "ح وحدثنا" → clean chain break.
  display = display.replaceAll(RegExp(r'\s*ح\s*و\s*(?=حدثنا|حدثني)', unicode: true), ' . ');
  // Drop "نحوه" (commentary pointer, not a person).
  display = display.replaceAll(RegExp(r'،?\s*نحوه\s*', unicode: true), ' ');
  final search = _foldAr(display);
  return (display, search);
}

List<String> _extractNamesFromArIsnad(String isnad) {
  if (isnad.trim().isEmpty) return [];

  final prepared = _prepareIsnadDisplay(isnad);
  final display = prepared.$1;
  final search = prepared.$2;

  final names = <String>[];
  final seen = <String>{};

  bool add(String raw) {
    var name = _cleanNameAr(raw);
    if (name.isEmpty || _isProphetToken(name) || _isMatnNoise(name)) return false;
    // Strip leftover parallel-chain crumbs.
    name = name.split(RegExp(r'\s+\.\s+')).first.replaceAll(RegExp(r'^[ ،,;:]+|[ ،,;:]+$'), '');
    name = _cleanNameAr(name);
    if (name.isEmpty || _isMatnNoise(name)) return false;
    final key = _foldAr(name).replaceAll(' ', '');
    if (seen.contains(key)) return false;
    seen.add(key);
    names.add(name);
    return true;
  }

  // Leading قال / قالت <Name> (e.g. قال ابن شهاب)
  // Name is the last capturing content in the match (lookahead is zero-width).
  for (final m in _qalaName.allMatches(search)) {
    final nameGroup = m.namedGroup('name');
    if (nameGroup == null || nameGroup.isEmpty) continue;
    final nameStart = m.end - nameGroup.length;
    add(display.substring(nameStart, m.end));
  }

  final matches = _txFind.allMatches(search).toList();
  for (var i = 0; i < matches.length; i++) {
    final m = matches[i];
    final verb = m.namedGroup('verb') ?? '';
    final start = m.end;
    final end = i + 1 < matches.length ? matches[i + 1].start : search.length;

    // Skip "عن" that is part of يحدث عن <matn>
    final prevStart = m.start - 8 < 0 ? 0 : m.start - 8;
    final prev = search.substring(prevStart, m.start);
    if (verb == 'عن' && RegExp(r'يحدث\s*$|تحدث\s*$|نحدث\s*$', unicode: true).hasMatch(prev)) {
      continue;
    }
    // Skip "ان" that opens speech: انه قال / انها قالت
    if (verb == 'ان') {
      final aheadEnd = start + 16 > search.length ? search.length : start + 16;
      final ahead = search.substring(start, aheadEnd);
      if (RegExp(r'^\s*(?:ه\s+قال|ها\s+قالت|ه\s+سمع|ها\s+سمعت)', unicode: true).hasMatch(ahead)) {
        continue;
      }
    }

    final chunk = display.substring(start, end).replaceAll(RegExp(r'^[ ،,;:]+|[ ،,;:]+$'), '');
    if (chunk.isEmpty) continue;

    final foldedChunk = _foldAr(chunk);
    if (RegExp(
      r'^(?:انها\s+قالت|انه\s+قال|قال\s+رسول|قالت\s+رسول|وهو\s+يحدث|فقال\s+في)',
      unicode: true,
    ).hasMatch(foldedChunk)) {
      break;
    }
    if (_isProphetToken(chunk) || _isMatnNoise(chunk)) break;

    add(chunk);
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

String isnadExcerptEn(String? textEn, {int maxLen = 320}) {
  final text = (textEn ?? '').trim();
  if (text.isEmpty) return '';
  final head = _cutIsnadEn(text);
  return head.length > maxLen ? head.substring(0, maxLen) : head;
}

final _urHonor = RegExp(r'\s*(?:رضی|رضى)\s*اللہ\s*(?:عنہا|عنها|عنہ|عنه)\s*', unicode: true);

String _cleanNameUr(String raw) {
  var name = _norm(raw).replaceAll(_urHonor, ' ');
  name = name.replaceAll(
    RegExp(r'\s*(?:رضی|رضى)\s*اللہ\s*(?:عنہما|عنهما|عنہا|عنها|عنہ|عنه)\s*', unicode: true),
    ' ',
  );
  name = _norm(name).replaceAll(RegExp(r'^[ ،,;:۔]+|[ ،,;:۔]+$'), '');
  name = name.replaceFirst(RegExp(r'\s+(نے|سے|کی|کو|ما)$'), '').trim();
  if (name.isEmpty ||
      {'ہم', 'ان', 'انہوں', 'اپنے', 'والد', 'یہ', 'اس', 'حدیث', 'وہ', 'ما'}.contains(name)) {
    return '';
  }
  if (_isProphetToken(name) || name.length > 100) return '';
  return name;
}

List<String> extractRaviChainUrdu(String? textUr) {
  final head = isnadExcerptUrdu(textUr, maxLen: 560);
  if (head.isEmpty) return [];
  final names = <String>[];
  final seen = <String>{};

  void add(String raw) {
    final name = _cleanNameUr(raw);
    if (name.isEmpty) return;
    final key = name.replaceAll(' ', '');
    if (seen.contains(key)) return;
    seen.add(key);
    names.add(name);
  }

  // "ابن شہاب کہتے ہیں مجھ کو ابوسلمہ … نے جابر … سے"
  for (final m in RegExp(
    r'(?:^|۔|\.)\s*([^،.]{2,40}?)\s+کہتے\s+ہیں\s+مجھ\s*کو\s+([^،.]{2,60}?)\s+نے\s+([^،.]{2,70}?)\s+سے',
    unicode: true,
  ).allMatches(head)) {
    add(m.group(1)!);
    add(m.group(2)!);
    add(m.group(3)!);
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
  return names.where((n) => !_isProphetToken(n)).toList();
}

Map<String, List<String>> extractRaviByLang(String? textAr, {String? primary, String? textEn, String? textUr}) {
  final ar = extractRaviChain(textAr, primary: primary, textEn: textEn, textUr: textUr);
  var ur = extractRaviChainUrdu(textUr);
  var en = _extractNarratedEn(textEn);
  if (en.length < 2 && ar.length >= 2) {
    en = List<String>.from(ar);
  } else if (en.isEmpty) {
    en = List<String>.from(ar);
  }
  if (ur.isEmpty) ur = List<String>.from(ar);
  return {'ar': ar, 'en': en, 'ur': ur};
}

Map<String, String> isnadByLang(String? textAr, {String? textEn, String? textUr}) {
  return {
    'ar': isnadExcerpt(textAr),
    'en': isnadExcerptEn(textEn),
    'ur': isnadExcerptUrdu(textUr),
  };
}

const refLabels = {
  'en': {
    'kitab': 'Kitab',
    'baab': 'Baab',
    'volume': 'Volume',
    'english_kitab': 'English Kitab',
    'english_name': 'English Name',
    'takhreej': 'Takhreej',
    'status': 'Status',
    'wazahat': 'Wazahat',
  },
  'ur': {
    'kitab': 'کتاب',
    'baab': 'باب',
    'volume': 'جلد',
    'english_kitab': 'انگریزی کتاب',
    'english_name': 'انگریزی نام',
    'takhreej': 'تخریج',
    'status': 'حیثیت',
    'wazahat': 'وضاحت',
  },
  'ar': {
    'kitab': 'كتاب',
    'baab': 'باب',
    'volume': 'المجلد',
    'english_kitab': 'الكتاب بالإنجليزية',
    'english_name': 'الاسم بالإنجليزية',
    'takhreej': 'التخريج',
    'status': 'الحالة',
    'wazahat': 'الشرح',
  },
};

Map<String, dynamic>? _chapterI18n;

/// Load authenticated chapter/book title localizations (call once from repository).
void setChapterI18n(Map<String, dynamic>? data) {
  _chapterI18n = data;
}

String _localizedChapter(String bookSlug, String chapterTitle, String lang) {
  final chapter = chapterTitle.trim();
  if (chapter.isEmpty) return '';
  if (lang == 'en') return chapter;
  final chapters = (_chapterI18n?['chapters'] as Map?)?[bookSlug];
  if (chapters is Map && chapters[chapter] is Map) {
    final value = '${(chapters[chapter] as Map)[lang] ?? ''}'.trim();
    if (value.isNotEmpty) return value;
  }
  return chapter;
}

/// Public localized کتاب/chapter title for topic browse UI.
String localizedChapterTitle(String bookSlug, String chapterTitle, String lang) {
  return _localizedChapter(bookSlug, chapterTitle, lang);
}

Map<String, dynamic> buildReferenceDetail({
  required String bookName,
  required String bookSlug,
  String? bookNameAr,
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

  final gradeRaw = (grade ?? '').trim();
  final chapter = (chapterTitle ?? '').trim();
  final chNum = chapterNumber == null ? '' : '$chapterNumber';

  String statusFor(String lang) {
    if (gradeRaw.isNotEmpty) return gradeRaw;
    if (bookSlug == 'bukhari' || bookSlug == 'muslim') {
      return {'en': 'Sahih', 'ur': 'صحیح', 'ar': 'صحيح'}[lang]!;
    }
    return {
      'en': 'Not graded in source',
      'ur': 'ماخذ میں درجہ نہیں',
      'ar': 'غير مُصنَّف في المصدر',
    }[lang]!;
  }

  final kitabEn = _localizedChapter(bookSlug, chapter, 'en');
  final kitabUr = _localizedChapter(bookSlug, chapter, 'ur');
  final kitabAr = _localizedChapter(bookSlug, chapter, 'ar');

  final byLang = <String, Map<String, dynamic>>{};
  for (final entry in refLabels.entries) {
    final lang = entry.key;
    final labels = entry.value;
    final kitab = lang == 'ur'
        ? (kitabUr.isNotEmpty ? kitabUr : chapter)
        : (lang == 'ar' ? (kitabAr.isNotEmpty ? kitabAr : chapter) : (kitabEn.isNotEmpty ? kitabEn : chapter));
    final values = {
      'kitab': kitab,
      'baab': kitab,
      'volume': volume,
      'english_kitab': kitabEn.isNotEmpty ? kitabEn : chapter,
      'english_name': bookName,
      'takhreej': '',
      'status': statusFor(lang),
      'wazahat': '',
    };
    byLang[lang] = {
      'labels': labels,
      'values': values,
      'rows': [
        for (final key in labels.keys) [labels[key]!, values[key]!],
      ],
    };
  }

  return {
    'kitab': kitabUr.isNotEmpty ? kitabUr : chapter,
    'baab': kitabUr.isNotEmpty ? kitabUr : chapter,
    'baab_number': chNum,
    'volume': volume,
    'english_kitab': kitabEn.isNotEmpty ? kitabEn : chapter,
    'english_name': bookName,
    'hadith_number': hadithRef,
    'takhreej': '',
    'status': statusFor('ur'),
    'wazahat': '',
    'source_url': 'https://sunnah.com/$bookSlug:$hadithNumber',
    'chapter_number': chNum,
    'by_lang': byLang,
  };
}
