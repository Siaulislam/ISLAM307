import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/audio/tts_service.dart';
import '../../core/database/database_registry.dart';
import '../../core/repositories/hadith_repository.dart';
import '../../core/theme/islam307_theme.dart';

class HadithDetailScreen extends StatefulWidget {
  const HadithDetailScreen({super.key, required this.bookId, required this.hadithNumber});
  final int bookId;
  final int hadithNumber;

  @override
  State<HadithDetailScreen> createState() => _HadithDetailScreenState();
}

class _HadithDetailScreenState extends State<HadithDetailScreen> {
  final _repo = HadithRepository(DatabaseRegistry.instance);
  Map<String, dynamic>? _hadith;
  bool _loading = true;
  String _lang = 'ur'; // ur | en | ar

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final row = await _repo.hadith(widget.bookId, widget.hadithNumber);
    if (!mounted) return;
    setState(() {
      _hadith = row;
      _loading = false;
    });
  }

  String _translation() {
    final h = _hadith;
    if (h == null) return '';
    if (_lang == 'en') return (h['text_en'] as String?) ?? '';
    if (_lang == 'ar') return (h['text_ar'] as String?) ?? '';
    return (h['text_ur'] as String?) ?? '';
  }

  void _openRaviSheet() {
    final h = _hadith;
    if (h == null) return;
    final chain = (h['ravi_chain'] as List?)?.cast<String>() ?? const <String>[];
    final isnadUr = (h['isnad_ur'] as String?)?.trim() ?? '';
    final isnad = (h['isnad'] as String?)?.trim() ?? '';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ravi · Hadith ${widget.hadithNumber}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  const Text(
                    'Names only · first ravi → each heard from the next → Holy Prophet Muhammad ﷺ',
                    style: TextStyle(color: Islam307Theme.textMuted, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  if (chain.isEmpty)
                    const Text('Full ravi chain is not available in the authenticated source for this hadith.')
                  else
                    ...[
                      for (var i = 0; i < chain.length; i++)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: i == chain.length - 1 ? Islam307Theme.emeraldSoft : null,
                            border: Border.all(color: i == chain.length - 1 ? Islam307Theme.emerald : Islam307Theme.cardBorder),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: Islam307Theme.emerald,
                                child: Text(
                                  i == chain.length - 1 ? 'ﷺ' : '${i + 1}',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      chain[i],
                                      textDirection: TextDirection.rtl,
                                      style: const TextStyle(fontWeight: FontWeight.w700, height: 1.45, fontSize: 15),
                                    ),
                                    Text(
                                      i == 0
                                          ? 'First narrator'
                                          : (i == chain.length - 1 ? 'Final · Holy Prophet' : 'Heard from previous'),
                                      style: const TextStyle(fontSize: 11, color: Islam307Theme.textMuted, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  if (isnadUr.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('ISNAD (URDU · AUTHENTICATED)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Islam307Theme.textMuted)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12)),
                      child: Text(
                        isnadUr,
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                        style: Islam307Theme.urdu().copyWith(color: const Color(0xFF1D4ED8)),
                      ),
                    ),
                  ] else if (isnad.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('ISNAD (ARABIC · AUTHENTICATED)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Islam307Theme.textMuted)),
                    const SizedBox(height: 8),
                    Text(isnad, textAlign: TextAlign.right, textDirection: TextDirection.rtl, style: Islam307Theme.arabic(size: 18)),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openReferenceSheet() {
    final h = _hadith;
    if (h == null) return;
    final d = Map<String, String>.from((h['reference_detail'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ?? {});
    final grade = HadithRepository.gradingSummary(h);
    final rows = <(String, String)>[
      ('Kitab', d['kitab'] ?? h['kitab']?.toString() ?? ''),
      ('Baab', d['baab'] ?? h['kitab']?.toString() ?? ''),
      ('Volume', d['volume'] ?? ''),
      ('English Kitab', d['english_kitab'] ?? h['kitab']?.toString() ?? ''),
      ('English Name', d['english_name'] ?? h['book_name']?.toString() ?? ''),
      ('Takhreej', d['takhreej'] ?? ''),
      ('Status', (d['status']?.isNotEmpty == true) ? d['status']! : grade.grade),
      ('Wazahat', d['wazahat'] ?? ''),
    ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFF111827),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reference · Hadith ${widget.hadithNumber}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      border: Border.all(color: const Color(0xFF334155)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < rows.length; i++)
                          Container(
                            decoration: BoxDecoration(
                              border: i == rows.length - 1
                                  ? null
                                  : const Border(bottom: BorderSide(color: Color(0xFF334155))),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 120,
                                  child: Text(rows[i].$1, style: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w700)),
                                ),
                                Container(width: 1, height: 22, color: const Color(0xFF334155)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    rows[i].$2,
                                    textAlign: TextAlign.right,
                                    textDirection: TextDirection.rtl,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = _hadith;
    final translation = _translation();
    final rtl = _lang == 'ur' || _lang == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text('Hadith ${widget.hadithNumber}', style: const TextStyle(fontWeight: FontWeight.w800)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => context.pop()),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Islam307Theme.emerald))
          : h == null
              ? const Center(child: Text('Authentic hadith not found in offline database.'))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonal(onPressed: _openRaviSheet, child: const Text('Ravi')),
                        FilledButton.tonal(onPressed: _openReferenceSheet, child: const Text('Reference')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final opt in const [('ur', 'Urdu'), ('en', 'English'), ('ar', 'Arabic')])
                          ChoiceChip(
                            label: Text(opt.$2),
                            selected: _lang == opt.$1,
                            onSelected: (_) => setState(() => _lang = opt.$1),
                            selectedColor: Islam307Theme.emeraldSoft,
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _lang == opt.$1 ? Islam307Theme.emeraldDeep : Islam307Theme.textMuted,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if ((h['text_ar'] as String?)?.isNotEmpty == true)
                      Text('${h['text_ar']}', textAlign: TextAlign.right, style: Islam307Theme.arabic(size: 22))
                    else
                      const Text('Arabic text unavailable in authenticated source.', style: TextStyle(color: Colors.orange)),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    if (translation.isEmpty)
                      Text(
                        '${_lang.toUpperCase()} translation unavailable in authenticated source.',
                        style: const TextStyle(color: Colors.orange),
                      )
                    else
                      Text(
                        translation,
                        textAlign: rtl ? TextAlign.right : TextAlign.left,
                        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                        style: _lang == 'ar'
                            ? Islam307Theme.arabic(size: 20)
                            : (_lang == 'ur' ? Islam307Theme.urdu() : const TextStyle(height: 1.6, color: Islam307Theme.textMuted)),
                      ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if ((h['text_en'] as String?)?.isNotEmpty == true)
                          OutlinedButton.icon(
                            onPressed: () => TtsService.instance.speak('${h['text_en']}', language: 'en-US'),
                            icon: const Icon(Icons.volume_up_rounded),
                            label: const Text('Read English'),
                          ),
                        if ((h['text_ur'] as String?)?.isNotEmpty == true)
                          OutlinedButton.icon(
                            onPressed: () => TtsService.instance.speak('${h['text_ur']}', language: 'ur-PK'),
                            icon: const Icon(Icons.volume_up_rounded),
                            label: const Text('Read Urdu'),
                          ),
                      ],
                    ),
                  ],
                ),
    );
  }
}
