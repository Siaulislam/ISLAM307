/// Parses authenticated Quranic Arabic Corpus (QAC) morphology features.
/// Never invents meanings — only maps stored feature tags to labels.
class QuranGrammarAnalysis {
  const QuranGrammarAnalysis({
    this.caseLabel = '',
    this.gender = '',
    this.number = '',
    this.tense = '',
    this.mood = '',
    this.voice = '',
    this.person = '',
    this.pattern = '',
    this.weakStrong = '',
    this.verbForm = '',
    this.nominalForm = '',
    this.particle = '',
    this.lemma = '',
    this.rootBw = '',
    this.rawFlags = const [],
  });

  final String caseLabel;
  final String gender;
  final String number;
  final String tense;
  final String mood;
  final String voice;
  final String person;
  final String pattern;
  final String weakStrong;
  final String verbForm;
  final String nominalForm;
  final String particle;
  final String lemma;
  final String rootBw;
  final List<String> rawFlags;

  bool get isEmpty =>
      caseLabel.isEmpty &&
      gender.isEmpty &&
      number.isEmpty &&
      tense.isEmpty &&
      mood.isEmpty &&
      voice.isEmpty &&
      person.isEmpty &&
      pattern.isEmpty &&
      weakStrong.isEmpty &&
      verbForm.isEmpty &&
      nominalForm.isEmpty &&
      particle.isEmpty &&
      rawFlags.isEmpty;

  Map<String, String> get displayRows {
    final rows = <String, String>{};
    void put(String k, String v) {
      if (v.trim().isNotEmpty) rows[k] = v;
    }

    put('Case', caseLabel);
    put('Gender', gender);
    put('Number', number);
    put('Tense', tense);
    put('Mood', mood);
    put('Voice', voice);
    put('Person', person);
    put('Pattern', pattern);
    put('Weak / Strong root', weakStrong);
    put('Verb form', verbForm);
    put('Nominal form', nominalForm);
    put('Particle', particle);
    return rows;
  }

  /// Build from QAC `features` strings (stem preferred) already stored offline.
  factory QuranGrammarAnalysis.fromFeatures(Iterable<String> featureStrings) {
    final flags = <String>{};
    final kv = <String, String>{};
    for (final feat in featureStrings) {
      for (final part in feat.split('|')) {
        final p = part.trim();
        if (p.isEmpty) continue;
        if (p.contains(':')) {
          final i = p.indexOf(':');
          kv[p.substring(0, i)] = p.substring(i + 1);
        } else {
          flags.add(p);
        }
      }
    }

    String caseLabel = '';
    if (flags.contains('NOM') || kv.containsKey('NOM')) caseLabel = 'Nominative (رفع)';
    if (flags.contains('ACC') || kv.containsKey('ACC')) caseLabel = 'Accusative (نصب)';
    if (flags.contains('GEN') || kv.containsKey('GEN')) caseLabel = 'Genitive (جر)';

    String gender = '';
    if (flags.any((f) => f.contains('F')) &&
        (flags.contains('F') ||
            flags.contains('FS') ||
            flags.contains('FP') ||
            flags.contains('2FS') ||
            flags.contains('2FP') ||
            flags.contains('3FS') ||
            flags.contains('3FP'))) {
      gender = 'Feminine';
    }
    if (flags.any((f) =>
        f == 'M' ||
        f == 'MS' ||
        f == 'MP' ||
        f == '2MS' ||
        f == '2MP' ||
        f == '3MS' ||
        f == '3MP')) {
      gender = gender.isEmpty ? 'Masculine' : gender;
      if (flags.any((f) => f == 'M' || f == 'MS' || f == 'MP' || f.startsWith('2M') || f.startsWith('3M'))) {
        gender = 'Masculine';
      }
      if (flags.any((f) => f == 'F' || f == 'FS' || f == 'FP' || f.startsWith('2F') || f.startsWith('3F'))) {
        gender = 'Feminine';
      }
    }

    String number = '';
    if (flags.any((f) => f.endsWith('P') || f == 'MP' || f == 'FP' || f == '1P' || f == '2MP' || f == '2FP' || f == '3MP' || f == '3FP')) {
      number = 'Plural';
    }
    if (flags.any((f) => f == 'MD' || f == 'FD' || f.contains('DU'))) number = 'Dual';
    if (flags.any((f) => f == 'MS' || f == 'FS' || f == '1S' || f == '2MS' || f == '2FS' || f == '3MS' || f == '3FS' || f == 'M' || f == 'F')) {
      if (number.isEmpty) number = 'Singular';
    }

    String tense = '';
    if (flags.contains('PERF')) tense = 'Perfect (ماضي)';
    if (flags.contains('IMPF')) tense = 'Imperfect (مضارع)';
    if (flags.contains('IMPV')) tense = 'Imperative (أمر)';

    String mood = '';
    if (flags.contains('MOOD:IND') || kv['MOOD'] == 'IND') mood = 'Indicative';
    if (flags.contains('MOOD:SUBJ') || kv['MOOD'] == 'SUBJ') mood = 'Subjunctive';
    if (flags.contains('MOOD:JUS') || kv['MOOD'] == 'JUS') mood = 'Jussive';
    if (kv.containsKey('MOOD')) {
      mood = switch (kv['MOOD']) {
        'IND' => 'Indicative',
        'SUBJ' => 'Subjunctive',
        'JUS' => 'Jussive',
        _ => kv['MOOD']!,
      };
    }

    String voice = '';
    if (flags.contains('PASS')) voice = 'Passive';
    if (flags.contains('ACT')) voice = 'Active';

    String person = '';
    for (final f in flags) {
      if (f.startsWith('1')) {
        person = '1st';
        break;
      }
      if (f.startsWith('2')) {
        person = '2nd';
        break;
      }
      if (f.startsWith('3')) {
        person = '3rd';
        break;
      }
    }

    final verbForm = kv['SP'] ?? kv['VFORM'] ?? '';
    final pattern = kv['PATTERN'] ?? kv['FORM'] ?? '';
    final weakStrong = flags.contains('WEAK')
        ? 'Weak'
        : (flags.contains('STRONG') ? 'Strong' : '');
    final nominalForm = flags.contains('PCPL')
        ? 'Participle'
        : (flags.contains('VN') ? 'Verbal noun' : '');
    final particle = flags.contains('PREFIX') || kv.containsKey('bi+') || flags.any((f) => f.endsWith('+'))
        ? (kv.keys.where((k) => k == 'PREFIX' || k.endsWith('+')).isNotEmpty ? 'Affix present' : '')
        : '';

    return QuranGrammarAnalysis(
      caseLabel: caseLabel,
      gender: gender,
      number: number,
      tense: tense,
      mood: mood,
      voice: voice,
      person: person,
      pattern: pattern,
      weakStrong: weakStrong,
      verbForm: verbForm,
      nominalForm: nominalForm,
      particle: particle,
      lemma: kv['LEM'] ?? '',
      rootBw: kv['ROOT'] ?? '',
      rawFlags: flags.toList()..sort(),
    );
  }
}

const kNoAuthenticReference = 'No authentic reference found.';
