import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Plays authentic Quran recitation from trusted CDN templates.
class RecitationAudioService {
  RecitationAudioService._();
  static final RecitationAudioService instance = RecitationAudioService._();

  final AudioPlayer _player = AudioPlayer();
  Map<String, dynamic>? _catalog;

  Future<Map<String, dynamic>> _load() async {
    _catalog ??= jsonDecode(await rootBundle.loadString('assets/modules/audio_reciters.json')) as Map<String, dynamic>;
    return _catalog!;
  }

  Future<void> stop() => _player.stop();

  Future<String?> playAyah({required int globalNumber, String? reciterId}) async {
    final catalog = await _load();
    final reciters = (catalog['reciters'] as List).cast<Map<String, dynamic>>();
    final id = reciterId ?? catalog['default_reciter'] as String;
    final reciter = reciters.firstWhere((r) => r['id'] == id, orElse: () => reciters.first);
    final template = reciter['url_template'] as String;
    final url = template.replaceAll('{global}', '$globalNumber');
    await _player.stop();
    try {
      await _player.play(UrlSource(url));
      return null;
    } catch (e) {
      return 'Recitation audio unavailable from trusted source right now.';
    }
  }
}
