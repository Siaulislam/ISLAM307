import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/audio/recitation_audio_service.dart';
import '../../core/audio/tts_service.dart';
import '../../core/models/quran_word.dart';
import '../../core/repositories/quran_word_repository.dart';
import '../../core/repositories/tafsir_repository.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/islam307_theme.dart';
import '../../core/user/user_library_store.dart';
import 'word_detail_sheet.dart';

class AyahCard extends ConsumerStatefulWidget {
  const AyahCard({super.key, required this.ayah, this.surahName, this.surahAyahCount});

  final Map<String, dynamic> ayah;
  final String? surahName;
  final int? surahAyahCount;

  @override
  ConsumerState<AyahCard> createState() => _AyahCardState();
}

class _AyahCardState extends ConsumerState<AyahCard> {
  bool _bookmarked = false;
  String? _highlight;
  String? _note;
  bool _ready = false;
  List<QuranWord> _words = const [];
  bool _wordsLoaded = false;
  /// null = hide translation under the ayah
  String? _translationLang;
  /// null = hide tafsir panel; otherwise selected source slug
  String? _tafsirSlug;
  Map<String, dynamic>? _tafsirEntry;
  bool _tafsirLoading = false;
  final _tafsirRepo = TafsirRepository();
  List<Map<String, dynamic>> _tafsirSources = const [];

  static const _translationOptions = <(String id, String label, String region)>[
    ('ur', 'Urdu', 'Pakistan'),
    ('en', 'English', 'International'),
    ('hi', 'Hindi', 'India'),
    ('fil', 'Filipino', 'Philippines'),
    ('bn', 'Bengali', 'Bangladesh'),
    ('id', 'Indonesian', 'Indonesia'),
    ('ms', 'Malay', 'Malaysia'),
    ('tr', 'Turkish', 'Türkiye'),
    ('fa', 'Persian', 'Iran / Afghanistan'),
    ('fr', 'French', 'North & West Africa'),
    ('ha', 'Hausa', 'Nigeria'),
    ('so', 'Somali', 'Somalia'),
    ('ps', 'Pashto', 'Afghanistan / Pakistan'),
    ('sw', 'Swahili', 'East Africa'),
  ];

  int get _surah => widget.ayah['surah_number'] as int;
  int get _ayahNo => widget.ayah['ayah_number'] as int;

  @override
  void initState() {
    super.initState();
    _loadPersonal();
    _loadWords();
    _loadTafsirSources();
  }

  Future<void> _loadTafsirSources() async {
    try {
      final sources = await _tafsirRepo.catalogSources();
      if (!mounted) return;
      setState(() => _tafsirSources = sources);
    } catch (_) {
      if (!mounted) return;
      setState(() => _tafsirSources = const []);
    }
  }

  Future<void> _loadPersonal() async {
    final store = UserLibraryStore.instance;
    final bookmarked = await store.isBookmarked(_surah, _ayahNo);
    final highlight = await store.highlight(_surah, _ayahNo);
    final note = await store.note(_surah, _ayahNo);
    if (!mounted) return;
    setState(() {
      _bookmarked = bookmarked;
      _highlight = highlight;
      _note = note;
      _ready = true;
    });
  }

  Future<void> _loadWords() async {
    final words = await QuranWordRepository().wordsForAyah(_surah, _ayahNo);
    if (!mounted) return;
    setState(() {
      _words = words;
      _wordsLoaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final scale = settings.fontScale;
    final arabic = '${widget.ayah['text_uthmani'] ?? ''}';
    final refLabel = '$_surah:$_ayahNo';
    final page = widget.ayah['page_madani'] ?? widget.ayah['page'];
    final juz = widget.ayah['juz'];

    // Authenticated offline columns only (translation_<lang>). Never invent text.
    const rtlLangs = {'ur', 'fa', 'ps'};
    const ttsByLang = <String, String>{
      'ur': 'ur-PK',
      'en': 'en-US',
      'hi': 'hi-IN',
      'fil': 'fil-PH',
      'bn': 'bn-BD',
      'id': 'id-ID',
      'ms': 'ms-MY',
      'tr': 'tr-TR',
      'fa': 'fa-IR',
      'fr': 'fr-FR',
      'ha': 'ha-NG',
      'so': 'so-SO',
      'ps': 'ps-AF',
      'sw': 'sw-KE',
    };

    String? translation;
    TextStyle? translationStyle;
    var translationRtl = false;
    String ttsLang = 'en-US';
    if (_translationLang != null) {
      final raw = '${widget.ayah['translation_$_translationLang'] ?? ''}'.trim();
      translation = raw.isEmpty ? null : raw;
      translationRtl = rtlLangs.contains(_translationLang);
      ttsLang = ttsByLang[_translationLang] ?? 'en-US';
      translationStyle = translationRtl
          ? Islam307Theme.urdu(size: 17 * scale)
          : TextStyle(color: Theme.of(context).hintColor, height: 1.6, fontSize: 15 * scale);
    }

    final highlighted = _highlight != null;
    final showMissingTranslation = _translationLang != null && translation == null;
    final trLabel = _translationOptions
            .where((e) => e.$1 == _translationLang)
            .map((e) => e.$2)
            .followedBy(const ['Translation'])
            .first;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: highlighted ? const Color(0xFFFFF4CC) : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openVerseActions(arabic: arabic, translation: translation, ttsLang: ttsLang, refLabel: refLabel),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(refLabel, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A))),
                  if (_bookmarked) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.bookmark_rounded, color: Islam307Theme.gold, size: 16),
                  ],
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _headerChoice(
                          label: trLabel,
                          active: _translationLang != null,
                          onTap: _pickTranslationLang,
                        ),
                        const SizedBox(width: 8),
                        _headerChoice(
                          label: 'Tafseer',
                          active: _tafsirSlug != null,
                          onTap: _pickTafsirSource,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Page $page · Juz $juz',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Islam307Theme.emerald),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_wordsLoaded && _words.isNotEmpty)
                _tappableArabic(scale)
              else
                Text(arabic, textAlign: TextAlign.right, style: Islam307Theme.arabic(size: 24 * scale)),
              if (translation != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        trLabel.toUpperCase(),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep, letterSpacing: 0.3),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        translation,
                        textAlign: translationRtl ? TextAlign.right : TextAlign.left,
                        textDirection: translationRtl ? TextDirection.rtl : TextDirection.ltr,
                        style: translationStyle,
                      ),
                    ],
                  ),
                ),
              ] else if (showMissingTranslation) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Text(
                    'Authentic $trLabel translation is not in the library yet. ISLAM 307 never invents Quran translations.',
                    style: const TextStyle(fontSize: 13, height: 1.45, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                  ),
                ),
              ],
              if (_tafsirSlug != null) ...[
                const SizedBox(height: 10),
                _tafsirPanel(),
              ],
              if ((_note ?? '').isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Islam307Theme.emeraldSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('Note: $_note', style: const TextStyle(fontSize: 13, height: 1.4)),
                ),
              ],
              ListenableBuilder(
                listenable: RecitationAudioService.instance,
                builder: (context, _) {
                  final audio = RecitationAudioService.instance;
                  if (!audio.isPlayingAyah(_surah, _ayahNo)) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Islam307Theme.emeraldSoft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Islam307Theme.emerald.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.graphic_eq_rounded, color: Islam307Theme.emerald, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Playing · ${audio.reciterName ?? 'Qari'} · tap verse for Stop',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Islam307Theme.emeraldDeep),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              await RecitationAudioService.instance.stop();
                              _toast('Recitation stopped');
                            },
                            child: const Text('Stop', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFB91C1C))),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              if (!_ready) const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openVerseActions({
    required String arabic,
    required String? translation,
    required String ttsLang,
    required String refLabel,
  }) async {
    final audio = RecitationAudioService.instance;
    final playingHere = audio.isPlayingAyah(_surah, _ayahNo);
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text('Ayah $_surah:$_ayahNo', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            ListTile(
              leading: Icon(_bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: Islam307Theme.emerald),
              title: Text(_bookmarked ? 'Remove bookmark' : 'Bookmark'),
              onTap: () => Navigator.pop(ctx, 'bookmark'),
            ),
            ListTile(
              leading: const Icon(Icons.highlight_rounded, color: Islam307Theme.emerald),
              title: Text(_highlight != null ? 'Remove highlight' : 'Highlight'),
              onTap: () => Navigator.pop(ctx, 'highlight'),
            ),
            ListTile(
              leading: const Icon(Icons.note_alt_outlined, color: Islam307Theme.emerald),
              title: const Text('Notes'),
              onTap: () => Navigator.pop(ctx, 'notes'),
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded, color: Islam307Theme.emerald),
              title: const Text('Copy'),
              onTap: () => Navigator.pop(ctx, 'copy'),
            ),
            ListTile(
              leading: const Icon(Icons.ios_share_rounded, color: Islam307Theme.emerald),
              title: const Text('Share'),
              onTap: () => Navigator.pop(ctx, 'share'),
            ),
            ListTile(
              leading: const Icon(Icons.volume_up_rounded, color: Islam307Theme.emerald),
              title: const Text('Speak'),
              onTap: () => Navigator.pop(ctx, 'speak'),
            ),
            if (playingHere)
              ListTile(
                leading: const Icon(Icons.stop_circle_rounded, color: Color(0xFFB91C1C)),
                title: const Text('Stop'),
                onTap: () => Navigator.pop(ctx, 'stop'),
              )
            else
              ListTile(
                leading: const Icon(Icons.play_circle_fill_rounded, color: Islam307Theme.emerald),
                title: const Text('Recite'),
                subtitle: const Text('Choose Qari · continues automatically'),
                onTap: () => Navigator.pop(ctx, 'recite'),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'bookmark') {
      await _toggleBookmark();
    } else if (choice == 'highlight') {
      await _toggleHighlight();
    } else if (choice == 'notes') {
      await _editNote();
    } else if (choice == 'copy') {
      await _copy(arabic, translation);
    } else if (choice == 'share') {
      await _share(arabic, translation, refLabel);
    } else if (choice == 'speak') {
      await _speakMenu(arabic, translation, ttsLang);
    } else if (choice == 'recite') {
      await _pickReciterAndPlay();
    } else if (choice == 'stop') {
      await RecitationAudioService.instance.stop();
      _toast('Recitation stopped');
    }
  }

  Widget _headerChoice({required String label, required bool active, required VoidCallback onTap}) {
    return Material(
      color: active ? Islam307Theme.emerald : const Color(0xFFF0FDFA),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: active ? Islam307Theme.emeraldDeep : const Color(0xFF99F6E4)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: active ? Colors.white : Islam307Theme.emeraldDeep,
            ),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic>? get _selectedTafsirSource {
    for (final source in _tafsirSources) {
      if (source['slug'] == _tafsirSlug) return source;
    }
    return null;
  }

  Widget _tafsirPanel() {
    final source = _selectedTafsirSource;
    final label = '${source?['name_en'] ?? _tafsirSlug}';
    final ready = source?['available'] == true;
    if (!ready) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Text(
          '${source?['notes'] ?? '$label is unavailable from an authorized official API.'} Nothing is generated with AI.',
          style: const TextStyle(fontSize: 13, height: 1.45, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
        ),
      );
    }
    if (_tafsirLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator(color: Islam307Theme.emerald)),
      );
    }
    final unavailable = _tafsirEntry == null || _tafsirEntry?['unavailable'] == true;
    final text = '${_tafsirEntry?['text'] ?? ''}';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep, letterSpacing: 0.3)),
          const SizedBox(height: 6),
          Text(
            unavailable
                ? (_tafsirEntry?['message'] as String? ?? TafsirRepository.unavailableMessage)
                : text,
            style: TextStyle(
              height: 1.7,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: unavailable ? const Color(0xFF92400E) : null,
            ),
          ),
          if (!unavailable) ...[
            const SizedBox(height: 10),
            Text(
              'Author: ${_tafsirEntry?['author'] ?? '—'}\n'
              'Source: ${_tafsirEntry?['source'] ?? '—'}\n'
              'Language: ${_tafsirEntry?['language'] ?? '—'}\n'
              'Citation: ${_tafsirEntry?['citation'] ?? '—'}',
              style: const TextStyle(
                height: 1.45,
                fontSize: 12,
                color: Islam307Theme.emeraldDeep,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickTranslationLang() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text('Translation language', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Translation stays hidden until you choose a language. Only authenticated texts are shown.',
                style: TextStyle(color: Islam307Theme.textMuted, fontSize: 13, height: 1.4),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined),
              title: const Text('Hide translation'),
              selected: _translationLang == null,
              onTap: () => Navigator.pop(ctx, ''),
            ),
            ..._translationOptions.map(
              (o) => ListTile(
                leading: const Icon(Icons.translate_rounded, color: Islam307Theme.emerald),
                title: Text(o.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(o.$3),
                selected: _translationLang == o.$1,
                onTap: () => Navigator.pop(ctx, o.$1),
              ),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    setState(() => _translationLang = choice.isEmpty ? null : choice);
  }

  Future<void> _pickTafsirSource() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text('Choose Tafseer', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Sources are discovered from the authenticated Quran Foundation registry. Unlicensed or unavailable works remain disabled.',
                style: TextStyle(color: Islam307Theme.textMuted, fontSize: 13, height: 1.4),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined),
              title: const Text('Hide tafseer'),
              selected: _tafsirSlug == null,
              onTap: () => Navigator.pop(ctx, ''),
            ),
            ..._tafsirSources.map(
              (source) => ListTile(
                leading: Icon(
                  source['available'] == true
                      ? Icons.menu_book_rounded
                      : Icons.block_rounded,
                  color: Islam307Theme.emerald,
                ),
                title: Text(
                  '${source['name_en']}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  source['available'] == true
                      ? '${source['author']} · ${source['language']} · official API'
                      : 'Unavailable — no authorized API resource',
                ),
                selected: _tafsirSlug == source['slug'],
                onTap: () => Navigator.pop(ctx, source['slug'] as String),
              ),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice.isEmpty) {
      setState(() {
        _tafsirSlug = null;
        _tafsirEntry = null;
      });
      return;
    }
    setState(() {
      _tafsirSlug = choice;
      _tafsirEntry = null;
      _tafsirLoading = true;
    });
    final entry = await _tafsirRepo.entry(choice, _surah, _ayahNo);
    if (!mounted) return;
    setState(() {
      _tafsirEntry = entry;
      _tafsirLoading = false;
    });
    ref.read(appSettingsProvider.notifier).setPreferredTafsir(choice);
  }

  Widget _tappableArabic(double scale) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Wrap(
        alignment: WrapAlignment.start,
        spacing: 6,
        runSpacing: 8,
        children: _words.map((w) {
          return InkWell(
            onTap: () => showQuranWordQuickSheet(context, w, preferredLang: _translationLang),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              child: Text(
                w.textAr,
                style: Islam307Theme.arabic(size: 24 * scale).copyWith(
                  decoration: TextDecoration.underline,
                  decorationColor: Islam307Theme.emerald.withValues(alpha: 0.35),
                  decorationThickness: 1.2,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _tool(IconData icon, String label, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
    );
  }

  Future<void> _speakMenu(String arabic, String? translation, String translationLang) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Speak with offline TTS', style: TextStyle(fontWeight: FontWeight.w800))),
            ListTile(
              leading: const Icon(Icons.menu_book_rounded),
              title: const Text('Entire verse (Arabic)'),
              onTap: () => Navigator.pop(ctx, 'verse'),
            ),
            if (translation != null)
              ListTile(
                leading: const Icon(Icons.translate_rounded),
                title: const Text('Translation'),
                onTap: () => Navigator.pop(ctx, 'translation'),
              ),
            ListTile(
              leading: const Icon(Icons.library_books_rounded),
              title: const Text('Tafsir'),
              onTap: () => Navigator.pop(ctx, 'tafsir'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    if (choice == 'verse') {
      await _speak(arabic, 'ar-SA');
    } else if (choice == 'translation' && translation != null) {
      await _speak(translation, translationLang);
    } else if (choice == 'tafsir') {
      final slug = ref.read(appSettingsProvider).preferredTafsirSlug;
      final entry = await _tafsirRepo.entry(slug, _surah, _ayahNo);
      final text = '${entry?['text'] ?? ''}';
      if (text.isEmpty || entry?['unavailable'] == true) {
        _toast(entry?['message'] as String? ?? TafsirRepository.unavailableMessage);
        return;
      }
      final lang = RegExp(r'[\u0600-\u06FF]').hasMatch(text) ? 'ar-SA' : 'en-US';
      await _speak(text, lang);
    }
  }

  Future<void> _speak(String text, String language) async {
    final ok = await TtsService.instance.speakOffline(text, language: language);
    if (!ok && mounted) {
      await TtsService.instance.showInstallVoiceGuide(context, language);
    }
  }

  Future<void> _toggleBookmark() async {
    final on = await UserLibraryStore.instance.toggleBookmark(_surah, _ayahNo);
    if (!mounted) return;
    setState(() => _bookmarked = on);
    _toast(on ? 'Bookmarked in your personal file' : 'Bookmark removed');
  }

  Future<void> _toggleHighlight() async {
    final color = await UserLibraryStore.instance.toggleHighlight(_surah, _ayahNo);
    if (!mounted) return;
    setState(() => _highlight = color);
    _toast(color == null ? 'Highlight cleared' : 'Ayah highlighted');
  }

  Future<void> _editNote() async {
    final controller = TextEditingController(text: _note ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Note · $_surah:$_ayahNo'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(hintText: 'Write your personal note…'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Save')),
        ],
      ),
    );
    if (result == null) return;
    await UserLibraryStore.instance.setNote(_surah, _ayahNo, result);
    if (!mounted) return;
    setState(() => _note = result.trim().isEmpty ? null : result.trim());
    _toast('Note saved to your personal file');
  }

  Future<void> _copy(String arabic, String? translation) async {
    final text = [
      '$_surah:$_ayahNo',
      arabic,
      if (translation != null) translation,
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    _toast('Copied');
  }

  Future<void> _share(String arabic, String? translation, String refLabel) async {
    final text = [
      'ISLAM 307 · Quran $refLabel',
      arabic,
      if (translation != null) translation,
    ].join('\n');
    await Share.share(text);
  }

  Future<void> _pickReciterAndPlay() async {
    final reciters = await RecitationAudioService.instance.reciters();
    if (!mounted) return;
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text('Choose Qari (KSA / Imam Al-Haram)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Recitation continues to the next ayah automatically. Press Stop anytime.',
                style: TextStyle(color: Islam307Theme.textMuted, fontSize: 13, height: 1.4),
              ),
            ),
            ...reciters.map((r) => ListTile(
                  leading: const Icon(Icons.record_voice_over_rounded, color: Islam307Theme.emerald),
                  title: Text('${r['name_en']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${r['title'] ?? ''} · ${r['name_ar'] ?? ''}'),
                  onTap: () => Navigator.pop(ctx, r['id'] as String),
                )),
          ],
        ),
      ),
    );
    if (chosen == null) return;

    // Continue through the end of this surah automatically.
    final endAyah = widget.surahAyahCount;
    final err = await RecitationAudioService.instance.playAyah(
      surah: _surah,
      ayah: _ayahNo,
      globalNumber: widget.ayah['global_number'] as int?,
      reciterId: chosen,
      continueThroughSurah: true,
      endAyah: endAyah,
    );
    if (err != null) {
      _toast(err);
    } else {
      final name = RecitationAudioService.instance.reciterName ?? 'Qari';
      _toast('Playing · $name · tap Stop to end');
    }
  }

  Future<void> _openTafsir(BuildContext context) async {
    final slug = ref.read(appSettingsProvider).preferredTafsirSlug;
    final entry = await _tafsirRepo.entry(slug, _surah, _ayahNo);
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: ListView(
            children: [
              Row(
                children: [
                  Expanded(child: Text('Tafsir · $_surah:$_ayahNo', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
                  if (entry != null && entry['unavailable'] != true)
                    IconButton(
                      tooltip: 'Speak tafsir',
                      onPressed: () async {
                        final text = '${entry['text'] ?? ''}';
                        final lang = RegExp(r'[\u0600-\u06FF]').hasMatch(text) ? 'ar-SA' : 'en-US';
                        await _speak(text, lang);
                      },
                      icon: const Icon(Icons.volume_up_rounded, color: Islam307Theme.emerald),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (entry == null || entry['unavailable'] == true)
                Text(entry?['message'] as String? ?? TafsirRepository.unavailableMessage,
                    style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w700))
              else ...[
                Text('${entry['source_name']}', style: const TextStyle(fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep)),
                const SizedBox(height: 10),
                Text('${entry['text']}', style: const TextStyle(height: 1.7)),
                const SizedBox(height: 12),
                Text(
                  'Author: ${entry['author'] ?? '—'}\n'
                  'Source: ${entry['source'] ?? '—'}\n'
                  'Language: ${entry['language'] ?? '—'}\n'
                  'Citation: ${entry['citation'] ?? '—'}',
                  style: const TextStyle(
                    height: 1.45,
                    fontSize: 12,
                    color: Islam307Theme.emeraldDeep,
                  ),
                ),
                TextButton(onPressed: () => context.push('/tafsir/$slug/$_surah/$_ayahNo'), child: const Text('Open in Tafsir module')),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
