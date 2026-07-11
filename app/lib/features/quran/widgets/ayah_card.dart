import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/audio/recitation_audio_service.dart';
import '../../core/audio/tts_service.dart';
import '../../core/database/database_registry.dart';
import '../../core/repositories/tafsir_repository.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/islam307_theme.dart';

class AyahCard extends ConsumerWidget {
  const AyahCard({
    super.key,
    required this.ayah,
    this.surahName,
  });

  final Map<String, dynamic> ayah;
  final String? surahName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final scale = settings.fontScale;
    final lang = settings.quranLanguage;
    final arabic = '${ayah['text_uthmani'] ?? ''}';
    final urdu = '${ayah['translation_ur'] ?? ''}';
    final english = '${ayah['translation_en'] ?? ''}';
    final refLabel = '${ayah['surah_number']}:${ayah['ayah_number']}';

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

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
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
                const Spacer(),
                Text('Juz ${ayah['juz']} · Ruku ${ayah['ruku']}', style: const TextStyle(fontSize: 11, color: Islam307Theme.textMuted)),
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
            ] else if (lang == QuranDisplayLanguage.urdu) ...[
              const SizedBox(height: 10),
              const Text(
                'Urdu translation unavailable for this ayah in the authenticated database.',
                style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openTafsir(context, ref),
                  icon: const Icon(Icons.menu_book_outlined, size: 18),
                  label: const Text('View Tafsir'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _playRecitation(context),
                  icon: const Icon(Icons.graphic_eq_rounded, size: 18),
                  label: const Text('Play Recitation'),
                ),
                OutlinedButton.icon(
                  onPressed: translation == null
                      ? null
                      : () => TtsService.instance.speak(translation!, language: ttsLang),
                  icon: const Icon(Icons.record_voice_over_rounded, size: 18),
                  label: const Text('Play Translation'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _readAll(context, ref, arabic, translation, ttsLang),
                  icon: const Icon(Icons.play_circle_fill_rounded, size: 18),
                  label: const Text('Read it to me'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _playRecitation(BuildContext context) async {
    final global = ayah['global_number'] as int?;
    if (global == null) {
      _toast(context, 'Recitation reference missing for this ayah.');
      return;
    }
    final err = await RecitationAudioService.instance.playAyah(globalNumber: global);
    if (err != null && context.mounted) _toast(context, err);
  }

  Future<void> _openTafsir(BuildContext context, WidgetRef ref) async {
    final slug = ref.read(appSettingsProvider).preferredTafsirSlug;
    final surah = ayah['surah_number'] as int;
    final number = ayah['ayah_number'] as int;
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TafsirSheet(surah: surah, ayah: number, initialSlug: slug),
    );
  }

  Future<void> _readAll(
    BuildContext context,
    WidgetRef ref,
    String arabic,
    String? translation,
    String ttsLang,
  ) async {
    await _playRecitation(context);
    if (translation != null) {
      await TtsService.instance.speak(translation, language: ttsLang);
    }
    final slug = ref.read(appSettingsProvider).preferredTafsirSlug;
    final repo = TafsirRepository(DatabaseRegistry.instance);
    final entry = await repo.entry(slug, ayah['surah_number'] as int, ayah['ayah_number'] as int);
    final text = entry == null || entry['unavailable'] == true ? null : '${entry['text'] ?? ''}';
    if (text == null || text.trim().isEmpty) {
      if (context.mounted) {
        _toast(context, TafsirRepository.unavailableMessage);
      }
      return;
    }
    await TtsService.instance.speak(text, language: 'en-US');
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _TafsirSheet extends StatefulWidget {
  const _TafsirSheet({required this.surah, required this.ayah, required this.initialSlug});
  final int surah;
  final int ayah;
  final String initialSlug;

  @override
  State<_TafsirSheet> createState() => _TafsirSheetState();
}

class _TafsirSheetState extends State<_TafsirSheet> {
  final _repo = TafsirRepository(DatabaseRegistry.instance);
  late String _slug;
  Map<String, dynamic>? _entry;
  List<Map<String, dynamic>> _sources = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _slug = widget.initialSlug;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final sources = await _repo.catalogSources();
    final entry = await _repo.entry(_slug, widget.surah, widget.ayah);
    if (!mounted) return;
    setState(() {
      _sources = sources;
      _entry = entry;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final unavailable = _entry == null || _entry!['unavailable'] == true;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Tafsir · ${widget.surah}:${widget.ayah}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 8),
            const Text(
              'Only authentic classical sources. Never AI-generated.',
              style: TextStyle(color: Islam307Theme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _slug,
              items: _sources
                  .map((s) => DropdownMenuItem(
                        value: s['slug'] as String,
                        child: Text('${s['name_en']}${s['installed'] == true ? '' : ' (not installed)'}'),
                      ))
                  .toList(),
              onChanged: (v) async {
                if (v == null) return;
                _slug = v;
                await _load();
              },
              decoration: const InputDecoration(labelText: 'Tafsir source'),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Islam307Theme.emerald))
                  : SingleChildScrollView(
                      child: unavailable
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_entry?['message'] as String? ?? TafsirRepository.unavailableMessage,
                                    style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.orange)),
                                const SizedBox(height: 8),
                                Text('${_entry?['notes'] ?? ''}', style: const TextStyle(color: Islam307Theme.textMuted)),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${_entry!['source_name']}', style: const TextStyle(fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep)),
                                const SizedBox(height: 10),
                                Text('${_entry!['text']}', style: const TextStyle(height: 1.7, fontSize: 15)),
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  onPressed: () => TtsService.instance.speak('${_entry!['text']}', language: 'en-US'),
                                  icon: const Icon(Icons.volume_up_rounded),
                                  label: const Text('Play Tafsir'),
                                ),
                                TextButton(
                                  onPressed: () => context.push('/tafsir/$_slug/${widget.surah}/${widget.ayah}'),
                                  child: const Text('Open in Tafsir module'),
                                ),
                              ],
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
