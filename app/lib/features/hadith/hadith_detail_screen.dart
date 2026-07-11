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

  void _openRaviSheet() {
    final h = _hadith;
    if (h == null) return;
    final primary = (h['ravi'] as String?)?.trim() ?? '';
    final chain = (h['ravi_chain'] as List?)?.cast<String>() ?? const <String>[];
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
                  const SizedBox(height: 14),
                  if (primary.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Islam307Theme.emeraldSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('PRIMARY RAVI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep)),
                          const SizedBox(height: 4),
                          Text(primary, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (chain.isEmpty)
                    const Text('Full ravi / isnad chain is not available in the authenticated source for this hadith.')
                  else
                    ...[
                      for (var i = 0; i < chain.length; i++)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Islam307Theme.cardBorder),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: Islam307Theme.emerald,
                                child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  chain[i],
                                  textDirection: TextDirection.rtl,
                                  style: const TextStyle(fontWeight: FontWeight.w700, height: 1.45, fontSize: 15),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  if (isnad.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('ISNAD (AUTHENTICATED ARABIC)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Islam307Theme.textMuted)),
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
      ('Hadith Number', d['hadith_number'] ?? '${widget.hadithNumber}'),
      ('Takhreej', d['takhreej'] ?? ''),
      ('Status', (d['status']?.isNotEmpty == true) ? d['status']! : (grade.grade)),
      ('Wazahat', d['wazahat'] ?? ''),
    ];
    final sourceUrl = d['source_url'] ?? h['reference_url']?.toString() ?? '';

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
                  Text('Reference · Hadith ${widget.hadithNumber}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  _metaTable(rows),
                  if (sourceUrl.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(sourceUrl, style: const TextStyle(fontSize: 12, color: Islam307Theme.emerald, fontWeight: FontWeight.w600)),
                  ],
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
    final grade = h == null ? null : HadithRepository.gradingSummary(h);

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
                        FilledButton.tonal(
                          onPressed: _openRaviSheet,
                          child: const Text('Ravi'),
                        ),
                        FilledButton.tonal(
                          onPressed: _openReferenceSheet,
                          child: const Text('Reference'),
                        ),
                        if (grade != null)
                          Chip(
                            label: Text(grade.grade),
                            backgroundColor: Islam307Theme.emeraldSoft,
                            labelStyle: const TextStyle(color: Islam307Theme.emeraldDeep, fontWeight: FontWeight.w700),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if ((h['text_ar'] as String?)?.isNotEmpty == true)
                      Text('${h['text_ar']}', textAlign: TextAlign.right, style: Islam307Theme.arabic(size: 22)),
                    const SizedBox(height: 16),
                    if ((h['text_ur'] as String?)?.isNotEmpty == true) ...[
                      const Text('اردو', style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text('${h['text_ur']}', textAlign: TextAlign.right, textDirection: TextDirection.rtl, style: Islam307Theme.urdu()),
                      const SizedBox(height: 16),
                    ] else
                      const Text('Urdu translation unavailable for this hadith in the authenticated database.', style: TextStyle(color: Colors.orange)),
                    if ((h['text_en'] as String?)?.isNotEmpty == true) ...[
                      const Text('English', style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.only(left: 12),
                        decoration: const BoxDecoration(border: Border(left: BorderSide(color: Islam307Theme.gold, width: 3))),
                        child: Text('${h['text_en']}', style: const TextStyle(height: 1.6, color: Islam307Theme.textMuted)),
                      ),
                    ],
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

  Widget _metaTable(List<(String, String)> rows) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Islam307Theme.cardBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Container(
              decoration: BoxDecoration(
                border: i == rows.length - 1 ? null : const Border(bottom: BorderSide(color: Islam307Theme.cardBorder)),
                color: i.isEven ? Islam307Theme.emeraldSoft.withValues(alpha: 0.35) : null,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(rows[i].$1, style: const TextStyle(fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep)),
                  ),
                  Expanded(
                    child: Text(
                      rows[i].$2,
                      style: const TextStyle(fontWeight: FontWeight.w600, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
