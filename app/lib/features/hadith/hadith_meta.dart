/// Extract authentic isnad (rawi chain) from offline hadith rows.
///
/// Rules:
/// - Narrators = every personal name from the start of the Arabic text until the
///   first mention of the Prophet ﷺ.
/// - Stop at النبي / رسول الله / محمد صلى الله عليه وسلم (and ﷺ variants).
/// - Do NOT include Prophet Muhammad ﷺ in the rawi list.
/// - Everything after that marker is Matn.
/// - Capture the full dynamic chain (no fixed narrator count).
/// - Preserve ibn/bin/bint/Abu/Umm/al-/ibn Abi. Never invent names.

final _diac = RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED\u0640]');

// Boundary marker: first Prophet ﷺ (not bare اسم "محمد").
final _prophetAr = RegExp(
  r'(?:'
  r'رسول\s*الله\s*(?:صلى|صلی|ﷺ)?'
  r'|رسول\s*اللہ\s*(?:صلى|صلی|ﷺ)?'
  r'|النبي\s*(?:صلى|صلی|ﷺ)?'
  r'|النبی\s*(?:صلى|صلی|ﷺ)?'
  r'|نبي\s*الله\s*(?:صلى|صلی|ﷺ)?'
  r'|نبی\s*اللہ\s*(?:صلى|صلی|ﷺ)?'
  r'|محمد\s*(?:صلى|صلی|ﷺ)'
  r')',
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
  r'و?'
  r'(?<verb>حدثنا|حدثني|اخبرنا|اخبرني|انبانا|انباني|سمعت|عن|ان)'
  r'(?=[\s،,;:]+|$)',
  unicode: true,
);

// Opening "قال ابن شهاب / قالت أسماء" — name ends at punctuation, عن, or tx verb.
final _qalaName = RegExp(
  r'(?:^|[\s،,;:]+)'
  r'(?<verb>قال|قالت)\s+'
  r'(?!'
  r'رسول\s*الله|رسول\s*اللہ|النبي|النبی|نبي\s*الله|'
  r'حدثنا|حدثني|اخبرنا|اخبرني|انبانا|انباني|سمعت|عن\s'
  r')'
  r'(?<name>[^،,;:\n"«»‏]{2,80}?)'
  r'(?=\s*(?:'
  r'،|,|:|'
  r'و?(?:حدثنا|حدثني|اخبرنا|اخبرني|انبانا|انباني|سمعت)|'
  r'عن\b|'
  r'و(?:اخبر|حدث|انبان)|'
  r'$'
  r'))',
  unicode: true,
);

/// Transmission / connector tokens that are NEVER part of a narrator name.
const _connectorTokens = {
  'عن',
  'قال',
  'قالت',
  'قالا',
  'قالوا',
  'يقول',
  'يقولون',
  'تقول',
  'ذكر',
  'ذكرت',
  'حدثنا',
  'حدثني',
  'اخبرنا',
  'اخبرني',
  'انبانا',
  'انباني',
  'سمعت',
  'سمع',
  'نا',
  'ثم',
  'ان',
  'فان',
  'انه',
  'انها',
  'انهما',
  'انهم',
};

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

final _matnAfterQala = RegExp(
  r'^(?:'
  r'تخلف|بينما|بينا|كان|كنت|كنا|ذكر|ذكرت|خطب|جاء|جاءت|بعث|كتب|'
  r'يسروا|تسموا|حفظت|اقبلت|بت\s|ضمني|عقلت|اتي|اتيت|سئل|سال|'
  r'ان\s+رسول|ان\s+النبي|سمعت\s+النبي|سمعت\s+رسول'
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
  // Bare "محمد" is a common narrator short-name — require salawat/ﷺ.
  if (RegExp(
        r'^(?:رسول\s*الله(?:\s*صلى.*)?'
        r'|رسول\s*اللہ(?:\s*صلى.*)?'
        r'|النبي(?:\s*صلى.*)?'
        r'|النبی(?:\s*صلى.*)?'
        r'|نبي\s*الله(?:\s*صلى.*)?'
        r'|نبی\s*اللہ(?:\s*صلى.*)?'
        r'|محمد\s*(?:صلى|صلی|ﷺ).*'
        r"|allah'?s\s+messenger|the\s+prophet|messenger\s+of\s+allah|prophet\s+muhammad)$",
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
  if (RegExp(r'^(?:في|وهو|فقال|بينا|بينما|فترة|حديثه|نحوه|تخلف|ذكر)\b', unicode: true).hasMatch(n)) {
    return true;
  }
  if (_matnAfterQala.hasMatch(n)) return true;
  return false;
}

bool _looksLikePersonName(String name) {
  final n = _foldAr(name);
  if (n.isEmpty || _isMatnNoise(n)) return false;
  if (_matnAfterQala.hasMatch(n)) return false;
  if (n.length > 70 || n.split(RegExp(r'\s+')).length > 12) return false;
  if (RegExp(
    r'(?:يمنعني|يزعم|تمارى|البعوث|في\s+المسجد|عدو\s+الله|خطيبا|'
    r'^قال\s|^قلت\s|^قيل\s|^ح$|^حدث$|^انه$|^انها$|^رجلا$|^سئل$|^اشهد|'
    r'^رايت$|^استيقظ$|^صلى\s|^لما\s|^احدثكم|'
    r'صحبت\s|فلم\s+اسمعه|كذب\s|لعمرو|لابن|'
    r'اخواننا|يشغلهم|يلزم\s+رسول|بذلك)',
    unicode: true,
  ).hasMatch(n)) {
    return false;
  }
  final tokens = RegExp(r'\w+', unicode: true)
      .allMatches(n)
      .map((m) => m.group(0)!)
      .where((t) => !_txVerbs.contains(t) && !{'عن', 'ان', 'قال', 'قالت', 'ح'}.contains(t))
      .toList();
  return tokens.isNotEmpty;
}

String _cleanNameAr(String raw) {
  var name = raw.replaceAll(_honorificAr, ' ').replaceAll('ـ', ' ');
  name = _norm(_stripDiac(name)).replaceAll(RegExp(r'^[ ،,;:.\-]+|[ ،,;:.\-]+$'), '');

  // Iteratively strip leading/trailing connector tokens (عن، قال، قالت، …).
  for (var i = 0; i < 8; i++) {
    final folded = _foldAr(name);
    final tokens = folded.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return '';
    final parts = name.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.first == 'و' && tokens.length > 1 && _connectorTokens.contains(tokens[1])) {
      name = _norm(parts.skip(2).join(' ')).replaceAll(RegExp(r'^[ ،,;:.\-]+|[ ،,;:.\-]+$'), '');
      continue;
    }
    if (_connectorTokens.contains(tokens.first)) {
      name = _norm(parts.skip(1).join(' ')).replaceAll(RegExp(r'^[ ،,;:.\-]+|[ ،,;:.\-]+$'), '');
      continue;
    }
    if (_connectorTokens.contains(tokens.last)) {
      name = _norm(parts.take(parts.length - 1).join(' ')).replaceAll(RegExp(r'^[ ،,;:.\-]+|[ ،,;:.\-]+$'), '');
      continue;
    }
    break;
  }

  // Cut at first internal speech/matn verb (keep the person name before it).
  final foldedFull = _foldAr(name);
  final cut = RegExp(
    r'\s+(?:قال|قالت|قالا|قالوا|يقول|يقولون|تقول|يحدث|تحدث|ذكر|ذكرت|'
    r'في\s+قوله|في\s+قول|على\s+المنبر)\b',
    unicode: true,
  ).firstMatch(foldedFull);
  if (cut != null) {
    name = name.substring(0, cut.start);
  }

  name = _norm(name).replaceAll(RegExp(r'\s+(?:قال|قالت|يقول)\s*$'), '');
  name = name.replaceAll(RegExp(r'(?:،|\s)+في\s*$'), '');
  name = name.replaceAll(
    RegExp(r'\s+(?:أخبره|أخبرها|أخبرهما|اخبره|اخبرها|اخبرهما)\s*$'),
    '',
  );
  name = _norm(name).replaceAll(RegExp(r'^[ ،,;:.\-]+|[ ،,;:.\-]+$'), '');

  var folded = _foldAr(name);
  if (name.isEmpty ||
      _connectorTokens.contains(folded) ||
      {'و', 'ه', 'ها', 'في', 'اخبره', 'أخبره'}.contains(folded)) {
    return '';
  }
  if (_isProphetToken(name)) return '';
  if (RegExp(r'يحدث|تحدث', unicode: true).hasMatch(folded)) return '';
  // Remove any remaining standalone connector words inside the name.
  final nameParts = name.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  final foldParts = folded.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  if (nameParts.length == foldParts.length && foldParts.any(_connectorTokens.contains)) {
    final kept = <String>[];
    for (var i = 0; i < nameParts.length; i++) {
      if (!_connectorTokens.contains(foldParts[i])) kept.add(nameParts[i]);
    }
    name = _norm(kept.join(' '));
    folded = _foldAr(name);
    if (name.isEmpty || _connectorTokens.contains(folded)) return '';
  }
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

  // 1) Primary: first Prophet ﷺ marker.
  final prophetMatch = _prophetAr.firstMatch(plain);
  if (prophetMatch != null) candidates.add(prophetMatch.start);

  // 2) Companion matn speech after isnad (قال كان / بينما / …).
  for (final m in RegExp(
    r'(?:^|[\s،,;:])(?<qala>قال(?:ت)?)\s+'
    r'(?!حدثنا|حدثني|اخبرنا|اخبرني|انبانا|انباني|سمعت|عن\s)'
    r'(?=كان|كنت|كنا|بينما|بينا|تخلف|ذكر|خطب|جاء|جاءت|بعث|كتب|'
    r'يسروا|تسموا|حفظت|اقبلت|ضمني|عقلت|اتي|اتيت|سئل)',
    unicode: true,
  ).allMatches(plain)) {
    if (RegExp(r'(?:حدثنا|حدثني|اخبرنا|عن)', unicode: true).hasMatch(plain.substring(0, m.start))) {
      final qalaStart = m.namedGroup('qala') != null ? m.end - m.namedGroup('qala')!.length : m.start;
      // Prefer named group start via match groups — use start of قال within match.
      final local = plain.substring(m.start, m.end);
      final qi = local.indexOf('قال');
      candidates.add(qi >= 0 ? m.start + qi : m.start);
    }
  }

  // 3) Fallback matn openers when neither above matched.
  if (candidates.isEmpty) {
    for (final pat in [
      r'وهو\s+يحدث',
      r'بينا\s+انا',
      r'بينما\s+انا',
      r'["«»\{]|قوله\s*تعالي|قوله\s*تعالى',
    ]) {
      final m = RegExp(pat, unicode: true).firstMatch(plain);
      if (m != null && m.start > 20) {
        candidates.add(m.start);
        break;
      }
    }
  }

  final cut = candidates.isEmpty
      ? (plain.length < 800 ? plain.length : 800)
      : candidates.reduce((a, b) => a < b ? a : b);
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

  // (start_offset, name) — sorted into document order at the end.
  final ordered = <(int, String)>[];
  final seen = <String>{};

  bool add(String raw, int pos) {
    var name = _cleanNameAr(raw);
    if (name.isEmpty || _isProphetToken(name) || _isMatnNoise(name) || !_looksLikePersonName(name)) {
      return false;
    }
    name = name.split(RegExp(r'\s+\.\s+')).first.replaceAll(RegExp(r'^[ ،,;:]+|[ ،,;:]+$'), '');
    name = _cleanNameAr(name);
    if (name.isEmpty || _isMatnNoise(name) || !_looksLikePersonName(name)) return false;

    // Split apposition "أبو النعمان، عارم بن الفضل".
    if (name.contains('،') || name.contains(',')) {
      var addedAny = false;
      var partPos = pos;
      for (final partRaw in name.split(RegExp(r'[،,]'))) {
        var part = _cleanNameAr(partRaw);
        if (part.isEmpty || !_looksLikePersonName(part)) continue;
        final key = _foldAr(part).replaceAll(' ', '');
        if (seen.contains(key)) continue;
        seen.add(key);
        ordered.add((partPos, part));
        partPos += 1;
        addedAny = true;
      }
      return addedAny;
    }

    final key = _foldAr(name).replaceAll(' ', '');
    if (seen.contains(key)) return false;
    seen.add(key);
    ordered.add((pos, name));
    return true;
  }

  for (final m in _qalaName.allMatches(search)) {
    final nameGroup = m.namedGroup('name');
    if (nameGroup == null || nameGroup.isEmpty) continue;
    final nameStart = m.end - nameGroup.length;
    final candidate = display.substring(nameStart, m.end);
    final folded = _foldAr(candidate);
    if (_matnAfterQala.hasMatch(folded)) continue;
    if (folded.split(RegExp(r'\s+')).length > 5 || folded.length > 40) continue;
    if (folded.startsWith('قال ') || folded.startsWith('قلت ')) continue;
    add(candidate, nameStart);
  }

  final matches = _txFind.allMatches(search).toList();
  for (var i = 0; i < matches.length; i++) {
    final m = matches[i];
    final verb = m.namedGroup('verb') ?? '';
    final start = m.end;
    final end = i + 1 < matches.length ? matches[i + 1].start : search.length;

    final prevStart = m.start - 8 < 0 ? 0 : m.start - 8;
    final prev = search.substring(prevStart, m.start);
    if (verb == 'عن' && RegExp(r'يحدث\s*$|تحدث\s*$|نحدث\s*$', unicode: true).hasMatch(prev)) {
      continue;
    }
    if (verb == 'ان') {
      final aheadEnd = start + 16 > search.length ? search.length : start + 16;
      final ahead = search.substring(start, aheadEnd);
      if (RegExp(r'^\s*(?:ه\s+قال|ها\s+قالت|ه\s+سمع|ها\s+سمعت)', unicode: true).hasMatch(ahead)) {
        continue;
      }
    }

    var chunk = display.substring(start, end).replaceAll(RegExp(r'^[ ،,;:]+|[ ،,;:]+$'), '');
    if (chunk.isEmpty) continue;

    final foldedChunk = _foldAr(chunk);
    if (RegExp(r'^(?:انها\s+قالت|انه\s+قال)', unicode: true).hasMatch(foldedChunk)) break;
    if (_matnAfterQala.hasMatch(foldedChunk)) break;
    if (RegExp(r'^(?:قال\s+رسول|قالت\s+رسول|وهو\s+يحدث|فقال\s+في)', unicode: true).hasMatch(foldedChunk)) {
      break;
    }
    if (_isProphetToken(chunk) || _isMatnNoise(chunk)) break;

    final speech = RegExp(
      r'\s+قال(?:ت)?\s+(?=تخلف|بينما|بينا|كان|كنت|كنا|ذكر|خطب|جاء|بعث|كتب|يسروا|تسموا|حفظت)',
      unicode: true,
    ).firstMatch(foldedChunk);
    if (speech != null) {
      chunk = display.substring(start, start + speech.start).replaceAll(RegExp(r'^[ ،,;:]+|[ ،,;:]+$'), '');
      add(chunk, start);
      break;
    }

    add(chunk, start);
  }

  ordered.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final item in ordered) item.$2];
}

String _cutIsnadEn(String textEn) {
  final m = _prophetEn.firstMatch(textEn);
  if (m == null) return textEn.length > 400 ? textEn.substring(0, 400) : textEn;
  return textEn.substring(0, m.start).replaceAll(RegExp(r'[ ,;:]+$'), '');
}

final _enNarratorNoise = RegExp(
  r'^(?:it|this|the above|another|a tradition|a hadith|narrated|reported|one|some|people|'
  r'he|she|they|we|i|and|or|from|that|when|while|after|before|also|same|'
  r'the prophet|allah|messenger|narrator not mentioned|see translation|'
  r'the same|the like)\b',
  caseSensitive: false,
);

/// Authenticated English attributed-narrator patterns only (never invent names).
final _enNarratorPatterns = <RegExp>[
  RegExp(r'^\s*Narrated\s+(.+?)(?:\s*:|\s*\(|\s*$)', caseSensitive: false, dotAll: true),
  RegExp(r'^\s*It (?:is|was) narrated on the authority of\s+(.+?)(?:\s+that\b|\s*:)', caseSensitive: false),
  RegExp(r'^\s*It (?:is|was) reported on the authority of\s+(.+?)(?:\s+that\b|\s*:)', caseSensitive: false),
  RegExp(
    r'^\s*It has been (?:narrated|reported|related|transmitted) on the authority of\s+(.+?)'
    r'(?:\s+that\b|\s*:|\s+who\b|\s*,|\s*\.)',
    caseSensitive: false,
  ),
  RegExp(
    r'^\s*(?:This hadith|A hadith like this|The above hadith|The same hadith)'
    r'[^.!?]{0,120}?\bon the authority of\s+(.+?)'
    r'(?:\s+with\b|\s+that\b|\s+from\b|\s+through\b|\s*,|\s*\.|$)',
    caseSensitive: false,
  ),
  RegExp(
    r'^\s*(?:This hadith|A hadith like this)'
    r'[^.!?]{0,80}?\b(?:narrated|reported|transmitted)\s+by\s+(.+?)'
    r'(?:\s+with\b|\s+through\b|\s+on\b|\s*,|\s*\.|$)',
    caseSensitive: false,
  ),
  RegExp(r'^\s*It was narrated from\s+(.+?)(?:\s+that\b|\s*,\s*who\b|\s*:)', caseSensitive: false),
  RegExp(r'^\s*It was narrated that\s+(.+?)(?:\s+said\b|\s*:)', caseSensitive: false),
  RegExp(r'^\s*(.+?)\s+narrated\s+that\s*:?', caseSensitive: false),
  RegExp(r'^\s*(.+?)\s+narrated\s*:', caseSensitive: false),
  RegExp(r'^\s*(.+?)\s+narrated\s+on the authority of\b', caseSensitive: false),
  RegExp(r'^\s*(.+?)\s+reported\s*:', caseSensitive: false),
  RegExp(r'^\s*(.+?)\s+reported\s+that\b', caseSensitive: false),
  RegExp(r'^\s*(.+?)\s+reported\s+on the authority of\b', caseSensitive: false),
  RegExp(r"^\s*(.+?)\s+reported\s+Allah'?s\s+(?:Messenger|Apostle)\b", caseSensitive: false),
  RegExp(r'^\s*(.+?)\s*\(\s*Allah be pleased[^)]*\)\s*reported\b', caseSensitive: false),
  RegExp(r'^\s*(.+?)\s+said\s*:', caseSensitive: false),
];

final _onAuthEn = RegExp(r'on(?: the)? authority of\s+([^,.\n]+)', caseSensitive: false);

bool _looksLikeEnNarrator(String name) {
  final n = name.trim();
  if (n.isEmpty || n.length < 2 || n.length > 90) return false;
  if (_enNarratorNoise.hasMatch(n)) return false;
  if (!RegExp(r'[A-Za-z]').hasMatch(n)) return false;
  if (RegExp(
    r'\bnarrated\b|\breported\b|\btradition\b|\bchain\b|\babove\b|\bmentioned\b|'
    r'\bhadith\b|\btransmitted\b|\btranslation\b',
    caseSensitive: false,
  ).hasMatch(n)) {
    return false;
  }
  if (n.split(RegExp(r'\s+')).length > 12) return false;
  if (_isProphetToken(n)) return false;
  return true;
}

List<String> _extractNarratedEn(String? textEn) {
  final text = (textEn ?? '').trim();
  if (text.isEmpty) return [];
  for (final pat in _enNarratorPatterns) {
    final m = pat.firstMatch(text);
    if (m == null) continue;
    var name = _cleanNameEn(m.group(1)!);
    name = name.replaceFirst(RegExp(r'\s*\(.*$'), '').trim();
    if (_looksLikeEnNarrator(name)) return [name];
  }
  final matches = _onAuthEn.allMatches(text).toList();
  if (matches.isNotEmpty) {
    final head = matches.where((m) => m.start < 520).toList();
    final pool = head.isEmpty ? matches : head;
    for (final m in pool.reversed) {
      var name = _cleanNameEn(m.group(1)!);
      name = name.replaceFirst(RegExp(r'\s*\(.*$'), '').trim();
      if (_looksLikeEnNarrator(name)) return [name];
    }
  }
  return [];
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
    // Intentionally omit external sunnah.com / provider links from reference UI.
    'source_url': '',
    'chapter_number': chNum,
    'by_lang': byLang,
  };
}
