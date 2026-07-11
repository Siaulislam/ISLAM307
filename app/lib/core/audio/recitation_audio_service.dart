import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Plays authentic Quran recitation from trusted EveryAyah CDN.
class RecitationAudioService {
  RecitationAudioService._();
  static final RecitationAudioService instance = RecitationAudioService._();

  final AudioPlayer _player = AudioPlayer();
  Map<String, dynamic>? _catalog;

  Future<Map<String, dynamic>> _load() async {
    _catalog ??= jsonDecode(await rootBundle.loadString('assets/modules/audio_reciters.json')) as Map<String, dynamic>;
    return _catalog!;
  }

  Future<List<Map<String, dynamic>>> reciters() async {
    final catalog = await _load();
    return (catalog['reciters'] as List).cast<Map<String, dynamic>>();
  }

  Future<String> defaultReciterId() async {
    final catalog = await _load();
    return catalog['default_reciter'] as String? ?? 'sudais';
  }

  Future<void> stop() => _player.stop();

  String _pad(int n) => n.toString().padLeft(3, '0');

  Future<String?> playAyah({
    required int surah,
    required int ayah,
    int? globalNumber,
    String? reciterId,
  }) async {
    final catalog = await _load();
    final reciters = (catalog['reciters'] as List).cast<Map<String, dynamic>>();
    final id = reciterId ?? catalog['default_reciter'] as String;
    final reciter = reciters.firstWhere((r) => r['id'] == id, orElse: () => reciters.first);
    var template = reciter['url_template'] as String;
    template = template
        .replaceAll('{sss}', _pad(surah))
        .replaceAll('{aaa}', _pad(ayah))
        .replaceAll('{global}', '${globalNumber ?? 0}');
    await _player.stop();
    try {
      await _player.play(UrlSource(template));
      return null;
    } catch (e) {
      return 'Recitation audio unavailable from trusted source right now.';
    }
  }
}
