import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/audio/recitation_audio_service.dart';
import '../../core/database/database_registry.dart';
import '../../core/repositories/tafsir_repository.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/islam307_theme.dart';
import '../../core/user/user_library_store.dart';

class AyahCard extends ConsumerStatefulWidget {
  const AyahCard({super.key, required this.ayah, this.surahName});

  final Map<String, dynamic> ayah;
  final String? surahName;

  @override
  ConsumerState<AyahCard> createState() => _AyahCardState();
}

class _AyahCardState extends ConsumerState<AyahCard> {
  bool _bookmarked = false;
  String? _highlight;
  String? _note;
  bool _ready = false;

  int get _surah => widget.ayah['surah_number'] as int;
  int get _ayahNo => widget.ayah['ayah_number'] as int;

  @override
  void initState() {
    super.initState();
    _loadPersonal();
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

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final scale = settings.fontScale;
    final lang = settings.quranLanguage;
    final arabic = '${widget.ayah['text_uthmani'] ?? ''}';
    final urdu = '${widget.ayah['translation_ur'] ?? ''}';
    final english = '${widget.ayah['translation_en'] ?? ''}';
    final refLabel = '$_surah:$_ayahNo';

    String? translation;
    TextStyle? translationStyle;
    String ttsLang = 'en-US';
    switch (lang) {
      case QuranDisplayLanguage.urdu:
        translation = urdu.isEmpty ? null : urdu;
        translationStyle = Islam307Theme.urdu(size: 17 * scale);
        ttsLang = 'ur-PK';
      case QuranDisplayLanguage.english:
        translation = english.isEmpty ? null : english;
        translationStyle = TextStyle(color: Theme.of(context).hintColor, height: 1.6, fontSize: 15 * scale);
        ttsLang = 'en-US';
      case QuranDisplayLanguage.arabicOnly:
        translation = null;
        translationStyle = null;
    }

    final highlighted = _highlight != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: highlighted ? const Color(0xFFFFF4CC) : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Islam307Theme.emeraldSoft, borderRadius: BorderRadius.circular(8)),
                  child: Text(refLabel, style: const TextStyle(fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep, fontSize: 12)),
                ),
                if (_bookmarked) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.bookmark_rounded, color: Islam307Theme.gold, size: 18),
                ],
                const Spacer(),
                Text('Juz ${widget.ayah['juz']} · Ruku ${widget.ayah['ruku']}', style: const TextStyle(fontSize: 11, color: Islam307Theme.textMuted)),
              ],
            ),
            const SizedBox(height: 12),
            Text(arabic, textAlign: TextAlign.right, style: Islam307Theme.arabic(size: 24 * scale)),
            if (translation != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.only(left: 12, right: 4),
                decoration: const BoxDecoration(border: Border(left: BorderSide(color: Islam307Theme.gold, width: 3))),
                child: Text(
                  translation,
                  textAlign: lang == QuranDisplayLanguage.urdu ? TextAlign.right : TextAlign.left,
                  textDirection: lang == QuranDisplayLanguage.urdu ? TextDirection.rtl : TextDirection.ltr,
                  style: translationStyle,
                ),
              ),
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
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _tool(Icons.text_increase_rounded, 'Aa', () => ref.read(appSettingsProvider.notifier).setFontScale(settings.fontScale + 0.1)),
                _tool(Icons.text_decrease_rounded, 'Aa-', () => ref.read(appSettingsProvider.notifier).setFontScale(settings.fontScale - 0.1)),
                _tool(Icons.dark_mode_rounded, 'Dark', () => ref.read(appSettingsProvider.notifier).toggleTheme()),
                _tool(_bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, 'Bookmark', _toggleBookmark),
                _tool(Icons.highlight_rounded, 'Highlight', _toggleHighlight),
                _tool(Icons.note_alt_outlined, 'Notes', _editNote),
                _tool(Icons.copy_rounded, 'Copy', () => _copy(arabic, translation)),
                _tool(Icons.ios_share_rounded, 'Share', () => _share(arabic, translation, refLabel)),
                _tool(Icons.menu_book_outlined, 'Tafsir', () => _openTafsir(context)),
                FilledButton.tonalIcon(
                  onPressed: _pickReciterAndPlay,
                  icon: const Icon(Icons.play_circle_fill_rounded, size: 18),
                  label: const Text('Recite'),
                ),
              ],
            ),
            if (!_ready) const SizedBox(height: 4),
          ],
        ),
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
    final err = await RecitationAudioService.instance.playAyah(
      surah: _surah,
      ayah: _ayahNo,
      globalNumber: widget.ayah['global_number'] as int?,
      reciterId: chosen,
    );
    if (err != null) _toast(err);
  }

  Future<void> _openTafsir(BuildContext context) async {
    final slug = ref.read(appSettingsProvider).preferredTafsirSlug;
    final repo = TafsirRepository(DatabaseRegistry.instance);
    final entry = await repo.entry(slug, _surah, _ayahNo);
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
              Text('Tafsir · $_surah:$_ayahNo', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 12),
              if (entry == null || entry['unavailable'] == true)
                Text(entry?['message'] as String? ?? TafsirRepository.unavailableMessage,
                    style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w700))
              else ...[
                Text('${entry['source_name']}', style: const TextStyle(fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep)),
                const SizedBox(height: 10),
                Text('${entry['text']}', style: const TextStyle(height: 1.7)),
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
