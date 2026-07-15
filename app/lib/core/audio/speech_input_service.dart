import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechInputService {
  SpeechInputService._();
  static final SpeechInputService instance = SpeechInputService._();

  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;
  String? _lastError;

  bool get isListening => _speech.isListening;
  String? get lastError => _lastError;

  Future<bool> start({
    required String localeId,
    required void Function(String words, bool isFinal) onResult,
    required void Function(String message) onError,
  }) async {
    _lastError = null;
    if (!_initialized) {
      _initialized = await _speech.initialize(
        onError: (SpeechRecognitionError error) {
          _lastError = error.errorMsg;
          onError(error.errorMsg);
        },
        onStatus: (_) {},
      );
    }
    if (!_initialized) {
      const message =
          'Microphone or speech recognition permission is unavailable.';
      _lastError = message;
      onError(message);
      return false;
    }
    await _speech.listen(
      localeId: localeId,
      onResult: (SpeechRecognitionResult result) {
        onResult(result.recognizedWords, result.finalResult);
      },
    );
    return _speech.isListening;
  }

  Future<void> stop() => _speech.stop();

  Future<void> cancel() => _speech.cancel();
}
