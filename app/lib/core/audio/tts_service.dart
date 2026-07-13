import 'package:flutter_tts/flutter_tts.dart';

/// Speaks authentic on-device text only. Never invents religious content.
class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  Future<void> _ensure() async {
    if (_ready) return;
    await _tts.awaitSpeakCompletion(true);
    _ready = true;
  }

  Future<void> stop() => _tts.stop();

  Future<void> speak(String text, {String language = 'en-US'}) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    await _ensure();
    await _tts.stop();
    await _tts.setLanguage(language);
    await _tts.setSpeechRate(0.42);
    await _tts.speak(clean);
  }

  Future<void> speakSequence(List<({String text, String language})> parts) async {
    for (final part in parts) {
      if (part.text.trim().isEmpty) continue;
      await speak(part.text, language: part.language);
    }
  }
}
