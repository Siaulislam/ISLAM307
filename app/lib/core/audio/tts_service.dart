import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Speaks authentic on-device text only. Never invents religious content.
/// Prefers clear male scholar voices (Arabic KSA/EG, Pakistani Urdu, South-Asian English).
class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  List<dynamic> _languages = const [];
  List<Map<String, String>> _voices = const [];
  double _rateMultiplier = 1.0;
  bool _paused = false;
  int _speakGeneration = 0;

  bool get isPaused => _paused;

  Future<void> _ensure() async {
    if (_ready) return;
    try {
      await _tts.setSharedInstance(true);
    } catch (_) {}
    await _tts.awaitSpeakCompletion(true);
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          ],
          IosTextToSpeechAudioMode.voicePrompt,
        );
      }
    } catch (_) {}
    try {
      _languages = await _tts.getLanguages ?? const [];
    } catch (_) {
      _languages = const [];
    }
    await _refreshVoices();
    _ready = true;
  }

  Future<void> _refreshVoices() async {
    try {
      final raw = await _tts.getVoices;
      if (raw is! List) {
        _voices = const [];
        return;
      }
      _voices = raw
          .map((e) {
            if (e is Map) {
              return <String, String>{
                'name': '${e['name'] ?? ''}',
                'locale': '${e['locale'] ?? e['lang'] ?? ''}',
              };
            }
            return <String, String>{'name': '$e', 'locale': ''};
          })
          .where((v) => v['name']!.isNotEmpty)
          .toList();
    } catch (_) {
      _voices = const [];
    }
  }

  /// Multiplier applied on top of a calm base rate (0.75 / 1 / 1.25 / 1.5).
  Future<void> setRateMultiplier(double multiplier) async {
    _rateMultiplier = multiplier.clamp(0.5, 2.0);
    await _ensure();
    try {
      await _tts.setSpeechRate(_effectiveRate(language: 'en-IN'));
    } catch (_) {}
  }

  double _effectiveRate({required String language}) {
    final code = language.toLowerCase();
    final base = code.startsWith('ar')
        ? 0.32
        : (code.startsWith('en') ? 0.36 : 0.40);
    return (base * _rateMultiplier).clamp(0.18, 0.75);
  }

  Future<void> stop() async {
    _paused = false;
    _speakGeneration++;
    await _tts.stop();
  }

  Future<void> pause() async {
    try {
      await _tts.pause();
      _paused = true;
    } catch (_) {
      await stop();
    }
  }

  Future<void> resume() async {
    _paused = false;
  }

  List<String> _localeCandidates(String language) {
    final code = language.toLowerCase();
    if (code.startsWith('ar')) return ['ar-SA', 'ar-EG', 'ar_SA', 'ar_EG', 'ar'];
    if (code.startsWith('ur')) return ['ur-PK', 'ur_PK', 'ur'];
    if (code.startsWith('hi')) return ['hi-IN', 'hi_IN', 'hi'];
    return ['en-IN', 'en_IN', 'en-PK', 'en_PK', 'en-GB', 'en_GB', 'en-US', 'en_US', 'en'];
  }

  int _genderPenalty(String name) {
    final s = name.toLowerCase();
    if (RegExp(
          r'female|woman|girl|zira|susan|samantha|karen|moira|tessa|fiona|veena|lekha|nicky|helena|linda|hazel|serena|allison|ava|kathy|victoria|salli|karen',
        ).hasMatch(s)) {
      return 80;
    }
    if (RegExp(
          r'male|man|boy|maged|naayf|najib|khaled|khalid|omar|ahmed|mohamed|mohammed|hassan|hussain|ravi|asif|farhan|daniel|david|mark|george|thomas|james|ryan|alex',
        ).hasMatch(s)) {
      return 0;
    }
    return 25;
  }

  Future<Map<String, String>?> _pickMaleVoice(String language) async {
    await _ensure();
    if (_voices.isEmpty) await _refreshVoices();
    if (_voices.isEmpty) return null;
    final locales = _localeCandidates(language).map((e) => e.toLowerCase().replaceAll('_', '-')).toList();
    final primary = locales.first.split('-').first;

    Map<String, String>? best;
    var bestScore = 1 << 30;
    for (final v in _voices) {
      final locale = (v['locale'] ?? '').toLowerCase().replaceAll('_', '-');
      final name = v['name'] ?? '';
      final label = '$name $locale';
      var score = 1000;
      final exact = locales.indexWhere((l) => locale == l || locale.startsWith('$l-') || locale.startsWith(l));
      if (exact >= 0) {
        score = exact * 10;
      } else if (locale.startsWith(primary)) {
        score = 45;
      } else {
        continue;
      }
      score += _genderPenalty(label);
      if (RegExp(r'enhanced|premium|neural|natural|offline|quality').hasMatch(label.toLowerCase())) {
        score -= 4;
      }
      if (primary == 'ar' && RegExp(r'saudi|egypt|ksa|maged|naayf').hasMatch(label.toLowerCase())) {
        score -= 8;
      }
      if (primary == 'ur' && RegExp(r'pakistan|urdu').hasMatch(label.toLowerCase())) {
        score -= 8;
      }
      if (primary == 'en' && RegExp(r'india|pakistan').hasMatch(label.toLowerCase())) {
        score -= 6;
      }
      if (primary == 'en' && RegExp(r'british|uk english female|zira|samantha').hasMatch(label.toLowerCase())) {
        score += 30;
      }
      if (score < bestScore) {
        bestScore = score;
        best = v;
      }
    }
    return best;
  }

  Future<bool> isLanguageAvailable(String language) async {
    await _ensure();
    if (_languages.isEmpty) return true;
    final wanted = language.toLowerCase();
    final short = wanted.split('-').first;
    for (final raw in _languages) {
      final code = '$raw'.toLowerCase();
      if (code == wanted || code.startsWith('$short-') || code == short) return true;
    }
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return true;
    }
    return false;
  }

  /// Returns false when the offline voice appears missing.
  Future<bool> speakOffline(
    String text, {
    String language = 'en-IN',
    double? rateMultiplier,
  }) async {
    final clean = text.trim();
    if (clean.isEmpty) return true;
    await _ensure();
    final available = await isLanguageAvailable(language);
    if (!available) return false;
    if (rateMultiplier != null) {
      _rateMultiplier = rateMultiplier.clamp(0.5, 2.0);
    }

    final gen = ++_speakGeneration;
    await _tts.stop();
    _paused = false;
    // Avoid engine glitches from stop→speak in the same tick.
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (gen != _speakGeneration) return true;

    final voice = await _pickMaleVoice(language);
    final locale = voice?['locale']?.isNotEmpty == true ? voice!['locale']! : language;
    try {
      if (voice != null) {
        await _tts.setVoice({'name': voice['name']!, 'locale': locale});
      }
    } catch (_) {}
    await _tts.setLanguage(locale.contains('-') || locale.contains('_') ? locale.replaceAll('_', '-') : language);
    await _tts.setSpeechRate(_effectiveRate(language: language));
    try {
      await _tts.setPitch(0.92);
    } catch (_) {}
    try {
      await _tts.setVolume(1.0);
    } catch (_) {}

    if (gen != _speakGeneration) return true;
    await _tts.speak(clean);
    return true;
  }

  Future<void> speak(String text, {String language = 'en-IN', double? rateMultiplier}) async {
    await speakOffline(text, language: language, rateMultiplier: rateMultiplier);
  }

  Future<void> speakSequence(List<({String text, String language})> parts) async {
    for (final part in parts) {
      if (part.text.trim().isEmpty) continue;
      final ok = await speakOffline(part.text, language: part.language);
      if (!ok) return;
    }
  }

  Future<void> showInstallVoiceGuide(BuildContext context, String language) async {
    final label = _labelFor(language);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Install offline $label male voice'),
        content: Text(
          'ISLAM 307 prefers a clear male voice for Hadith audio.\n\n'
          'Arabic: install Saudi (ar-SA) or Egyptian (ar-EG) male voice.\n'
          'Urdu: install Pakistani (ur-PK) male voice.\n'
          'English: install Indian/Pakistani English male voice (clearer than fast British female).\n\n'
          'Android: Settings → System → Languages & input → Text-to-speech → '
          'gear icon → Install voice data → $label.\n\n'
          'iPhone/iPad: Settings → Accessibility → Spoken Content → Voices → $label.\n\n'
          'After installing, return here and press Play again.',
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  String _labelFor(String language) {
    final code = language.toLowerCase();
    if (code.startsWith('ar')) return 'Arabic (Saudi/Egyptian male)';
    if (code.startsWith('ur')) return 'Urdu (Pakistan male)';
    if (code.startsWith('hi')) return 'Hindi';
    if (code.startsWith('en')) return 'English (India/Pakistan male)';
    return language;
  }
}
