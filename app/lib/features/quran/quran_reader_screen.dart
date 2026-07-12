import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/audio/recitation_audio_service.dart';
import '../../core/repositories/quran_repository.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/islam307_theme.dart';
import '../../core/user/user_library_store.dart';
import 'widgets/ayah_card.dart';

class QuranReaderScreen extends ConsumerStatefulWidget {
  const QuranReaderScreen({
    super.key,
    this.surahNumber,
    this.startAyah = 1,
    this.rukuNumber,
  });

  final int? surahNumber;
  final int startAyah;
  final int? rukuNumber;

  @override
  ConsumerState<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends ConsumerState<QuranReaderScreen> {
  final _repo = QuranRepository();
  List<Map<String, dynamic>> _ayahs = [];
  String _title = 'Quran';
  bool _loading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = await UserLibraryStore.instance.userId();
    if (widget.rukuNumber != null) {
      final ayahs = await _repo.ayahsForRuku(widget.rukuNumber!);
      final first = ayahs.isEmpty ? null : await _repo.surah(ayahs.first['surah_number'] as int);
      if (!mounted) return;
      setState(() {
        _userId = uid;
        _ayahs = ayahs;
        _title = 'Ruku ${widget.rukuNumber}${first == null ? '' : ' · ${first['name_en']}'}';
        _loading = false;
      });
      return;
    }

    final surahNo = widget.surahNumber ?? 1;
    final ayahs = await _repo.ayahsForSurah(surahNo);
    final surah = await _repo.surah(surahNo);
    if (!mounted) return;
    setState(() {
      _userId = uid;
      _ayahs = ayahs;
      _title = surah == null ? 'Surah $surahNo' : '${surah['name_en']}';
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(_title, style: const TextStyle(fontWeight: FontWeight.w800)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => context.pop()),
        actions: [
          IconButton(
            tooltip: 'Smaller text',
            onPressed: () => ref.read(appSettingsProvider.notifier).setFontScale(settings.fontScale - 0.1),
            icon: const Icon(Icons.text_decrease_rounded),
          ),
          IconButton(
            tooltip: 'Larger text',
            onPressed: () => ref.read(appSettingsProvider.notifier).setFontScale(settings.fontScale + 0.1),
            icon: const Icon(Icons.text_increase_rounded),
          ),
          IconButton(
            tooltip: 'Light / Dark',
            onPressed: () => ref.read(appSettingsProvider.notifier).toggleTheme(),
            icon: Icon(settings.themeMode == ThemeMode.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Islam307Theme.emerald))
          : Column(
              children: [
                if (_userId != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Personal file · $_userId', style: const TextStyle(fontSize: 11, color: Islam307Theme.textMuted, fontWeight: FontWeight.w600)),
                    ),
                  ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Row(
                    children: [
                      _langChip(QuranDisplayLanguage.urdu, 'Urdu'),
                      _langChip(QuranDisplayLanguage.english, 'English'),
                      _langChip(QuranDisplayLanguage.arabicOnly, 'Arabic Only'),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: _ayahs.length,
                    itemBuilder: (_, i) => AyahCard(
                      ayah: _ayahs[i],
                      surahAyahCount: _ayahs.isEmpty ? null : _ayahs.last['ayah_number'] as int?,
                    ),
                  ),
                ),
                ListenableBuilder(
                  listenable: RecitationAudioService.instance,
                  builder: (context, _) {
                    final audio = RecitationAudioService.instance;
                    if (!audio.isActive) return const SizedBox.shrink();
                    return Material(
                      elevation: 8,
                      color: Theme.of(context).cardColor,
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                          child: Row(
                            children: [
                              const Icon(Icons.graphic_eq_rounded, color: Islam307Theme.emerald),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${audio.reciterName ?? 'Qari'} · ${audio.playingSurah}:${audio.playingAyah}',
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                              FilledButton.icon(
                                onPressed: () => RecitationAudioService.instance.stop(),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFB91C1C),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(0, 40),
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                ),
                                icon: const Icon(Icons.stop_rounded, size: 18),
                                label: const Text('Stop'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }

  Widget _langChip(QuranDisplayLanguage lang, String label) {
    final selected = ref.watch(appSettingsProvider).quranLanguage == lang;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => ref.read(appSettingsProvider.notifier).setQuranLanguage(lang),
        selectedColor: Islam307Theme.emerald,
        labelStyle: TextStyle(fontWeight: FontWeight.w700, color: selected ? Colors.white : null),
      ),
    );
  }
}
