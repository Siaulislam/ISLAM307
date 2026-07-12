import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Speaks authentic on-device text only. Never invents religious content.
/// Uses device offline TTS — does not store per-word audio files.
class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _ready = false;
  List<dynamic> _languages = const [];
  double _rateMultiplier = 1.0;
  bool _paused = false;

  bool get isPaused => _paused;

  Future<void> _ensure() async {
    if (_ready) return;
    await _tts.awaitSpeakCompletion(true);
    try {
      _languages = await _tts.getLanguages ?? const [];
    } catch (_) {
      _languages = const [];
    }
    _ready = true;
  }

  /// Multiplier applied on top of a calm base rate (0.75 / 1 / 1.25 / 1.5).
  Future<void> setRateMultiplier(double multiplier) async {
    _rateMultiplier = multiplier.clamp(0.5, 2.0);
    await _ensure();
    try {
      await _tts.setSpeechRate(_effectiveRate(forArabic: false));
    } catch (_) {}
  }

  double _effectiveRate({required bool forArabic}) {
    final base = forArabic ? 0.34 : 0.42;
    return (base * _rateMultiplier).clamp(0.2, 0.9);
  }

  Future<void> stop() async {
    _paused = false;
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
    // flutter_tts has no universal resume; re-speak is handled by callers when needed.
    // On platforms that support pause, speaking may continue after pause() returns speaking.
    _paused = false;
  }

  Future<bool> isLanguageAvailable(String language) async {
    await _ensure();
    // Empty inventory is ambiguous (plugin/platform quirks) — attempt speak.
    if (_languages.isEmpty) return true;
    final wanted = language.toLowerCase();
    final short = wanted.split('-').first;
    for (final raw in _languages) {
      final code = '$raw'.toLowerCase();
      if (code == wanted || code.startsWith('$short-') || code == short) return true;
    }
    // On web/desktop, language codes often differ from BCP-47 tags we pass.
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
    String language = 'en-US',
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
    final forArabic = language.toLowerCase().startsWith('ar');
    await _tts.stop();
    _paused = false;
    await _tts.setLanguage(language);
    await _tts.setSpeechRate(_effectiveRate(forArabic: forArabic));
    try {
      await _tts.setPitch(forArabic ? 0.95 : 1.0);
    } catch (_) {}
    await _tts.speak(clean);
    return true;
  }

  Future<void> speak(String text, {String language = 'en-US', double? rateMultiplier}) async {
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
        title: Text('Install offline $label voice'),
        content: Text(
          'ISLAM 307 uses your device Text-To-Speech. '
          'The offline $label voice does not appear to be installed.\n\n'
          'Android: Settings → System → Languages & input → Text-to-speech → '
          'gear icon → Install voice data → $label.\n\n'
          'iPhone/iPad: Settings → Accessibility → Spoken Content → Voices → $label.\n\n'
          'After installing, return here and press the speaker again.',
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  String _labelFor(String language) {
    final code = language.toLowerCase();
    if (code.startsWith('ar')) return 'Arabic';
    if (code.startsWith('ur')) return 'Urdu';
    if (code.startsWith('hi')) return 'Hindi';
    if (code.startsWith('en')) return 'English';
    return language;
  }
}
