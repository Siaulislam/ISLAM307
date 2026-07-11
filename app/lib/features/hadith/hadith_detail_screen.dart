import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
    return Scaffold(
      backgroundColor: Islam307Theme.white,
      appBar: AppBar(
        title: Text('Hadith ${widget.hadithNumber}', style: const TextStyle(fontWeight: FontWeight.w800)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => context.pop()),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Islam307Theme.emerald))
          : h == null
              ? const Center(child: Text('Hadith not found'))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if ((h['narrator'] as String?)?.isNotEmpty == true)
                      Text('Narrated ${h['narrator']}', style: const TextStyle(fontWeight: FontWeight.w700, color: Islam307Theme.emeraldDeep)),
                    const SizedBox(height: 12),
                    if ((h['text_ar'] as String?)?.isNotEmpty == true)
                      Text(
                        '${h['text_ar']}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 22, height: 1.9),
                      ),
                    const SizedBox(height: 14),
                    if ((h['text_en'] as String?)?.isNotEmpty == true)
                      Container(
                        padding: const EdgeInsets.only(left: 12),
                        decoration: const BoxDecoration(border: Border(left: BorderSide(color: Islam307Theme.gold, width: 3))),
                        child: Text('${h['text_en']}', style: const TextStyle(height: 1.6, color: Islam307Theme.textMuted)),
                      ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          label: Text(grade?.grade ?? HadithRepository.gradeNotVerified),
                          backgroundColor: Islam307Theme.goldLight.withValues(alpha: 0.45),
                        ),
                        if ((grade?.scholar ?? '').isNotEmpty) Chip(label: Text(grade!.scholar!)),
                      ],
                    ),
                    if ((h['text_ur'] as String?)?.isNotEmpty == true) ...[
                      const SizedBox(height: 18),
                      const Text('Urdu', style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text('${h['text_ur']}', textAlign: TextAlign.right, style: const TextStyle(height: 1.8)),
                    ],
                  ],
                ),
    );
  }
}
