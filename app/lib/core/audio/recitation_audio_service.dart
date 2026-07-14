import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Audio architecture placeholder. Streaming remains disabled until licensed.
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

  Future<List<Map<String, dynamic>>> reciters() async => const [];

  Future<String> defaultReciterId() async => '';

  Future<void> stop() async {
    _userStopped = true;
    await _clearSession(stopPlayer: true);
  }

  Future<String?> playAyah({
    required int surah,
    required int ayah,
    int? globalNumber,
    String? reciterId,
    bool continueThroughSurah = false,
    int? endAyah,
  }) async {
    return 'Recitation audio is permission pending and is not streamed.';
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
