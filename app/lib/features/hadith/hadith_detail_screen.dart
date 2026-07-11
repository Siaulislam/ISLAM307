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

  @override
  Widget build(BuildContext context) {
    final h = _hadith;
    final grade = h == null ? null : HadithRepository.gradingSummary(h);
    final ravi = (h?['ravi'] as String?)?.trim();
    final reference = h?['reference'] as String? ?? '';
    final kitab = (h?['kitab'] as String?)?.trim();

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
                    _metaTable([
                      ('RAVI', (ravi == null || ravi.isEmpty) ? 'Ravi not available in authenticated source' : ravi),
                      ('Reference', reference.isEmpty ? 'Reference not available' : reference),
                      if ((kitab ?? '').isNotEmpty) ('Kitab / Baab', kitab!),
                      ('English Name', '${h['book_name'] ?? ''}'),
                      ('Status', grade?.grade ?? HadithRepository.gradeNotVerified),
                    ]),
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
                    if ((h['reference_url'] as String?)?.isNotEmpty == true)
                      Text('Source link: ${h['reference_url']}', style: const TextStyle(fontSize: 12, color: Islam307Theme.emerald, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
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
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(rows[i].$1, style: const TextStyle(fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep)),
                  ),
                  Expanded(
                    child: Text(rows[i].$2, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.4)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
