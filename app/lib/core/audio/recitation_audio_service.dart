import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Plays authentic Quran recitation from trusted EveryAyah CDN.
/// Supports continuous ayah playback with an explicit Stop control.
class RecitationAudioService extends ChangeNotifier {
  RecitationAudioService._() {
    _player.onPlayerComplete.listen((_) => _onComplete());
    _player.onPlayerStateChanged.listen((state) {
      _playerState = state;
      notifyListeners();
    });
  }
  static final RecitationAudioService instance = RecitationAudioService._();

  final AudioPlayer _player = AudioPlayer();
  Map<String, dynamic>? _catalog;
  PlayerState _playerState = PlayerState.stopped;

  String? _reciterId;
  String? _reciterName;
  int? _surah;
  int? _ayah;
  int? _endAyah;
  bool _continueThroughSurah = false;
  bool _userStopped = false;

  bool get isPlaying => _playerState == PlayerState.playing || _playerState == PlayerState.paused;
  bool get isActive =>
      _surah != null &&
      _ayah != null &&
      (_continueThroughSurah || _playerState == PlayerState.playing || _playerState == PlayerState.paused);
  int? get playingSurah => _surah;
  int? get playingAyah => _ayah;
  String? get reciterName => _reciterName;
  String? get reciterId => _reciterId;

  bool isPlayingAyah(int surah, int ayah) =>
      isActive && _surah == surah && _ayah == ayah;

  Future<void> _clearSession({bool stopPlayer = false}) async {
    _continueThroughSurah = false;
    _surah = null;
    _ayah = null;
    _endAyah = null;
    if (stopPlayer) await _player.stop();
    notifyListeners();
  }

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

  Future<void> stop() async {
    _userStopped = true;
    await _clearSession(stopPlayer: true);
  }

  String _pad(int n) => n.toString().padLeft(3, '0');

  Future<String?> playAyah({
    required int surah,
    required int ayah,
    int? globalNumber,
    String? reciterId,
    bool continueThroughSurah = false,
    int? endAyah,
  }) async {
    final catalog = await _load();
    final reciters = (catalog['reciters'] as List).cast<Map<String, dynamic>>();
    final id = reciterId ?? _reciterId ?? catalog['default_reciter'] as String;
    final reciter = reciters.firstWhere((r) => r['id'] == id, orElse: () => reciters.first);

    _userStopped = false;
    _continueThroughSurah = continueThroughSurah;
    _endAyah = endAyah;
    _reciterId = reciter['id'] as String;
    _reciterName = reciter['name_en'] as String? ?? _reciterId;
    _surah = surah;
    _ayah = ayah;
    notifyListeners();

    var template = reciter['url_template'] as String;
    template = template
        .replaceAll('{sss}', _pad(surah))
        .replaceAll('{aaa}', _pad(ayah))
        .replaceAll('{global}', '${globalNumber ?? 0}');
    await _player.stop();
    try {
      await _player.play(UrlSource(template));
      return null;
    } catch (_) {
      await _clearSession(stopPlayer: true);
      return 'Recitation audio unavailable from trusted source right now.';
    }
  }

  Future<void> _onComplete() async {
    if (_userStopped || !_continueThroughSurah) {
      await _clearSession();
      return;
    }
    final surah = _surah;
    final ayah = _ayah;
    if (surah == null || ayah == null) return;
    final next = ayah + 1;
    if (_endAyah != null && next > _endAyah!) {
      await _clearSession();
      return;
    }
    final err = await playAyah(
      surah: surah,
      ayah: next,
      reciterId: _reciterId,
      continueThroughSurah: true,
      endAyah: _endAyah,
    );
    if (err != null) {
      await _clearSession();
    }
  }
}
