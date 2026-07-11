import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/database/quran_database.dart';
import '../../core/theme/islam307_theme.dart';

class QuranReaderScreen extends StatefulWidget {
  const QuranReaderScreen({super.key, required this.surahNumber, this.startAyah = 1});

  final int surahNumber;
  final int startAyah;

  @override
  State<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends State<QuranReaderScreen> {
  List<Map<String, dynamic>> _ayahs = [];
  bool _loading = true;
  double _fontSize = 22;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await QuranDatabase.instance.ayahsForSurah(widget.surahNumber);
    if (!mounted) return;
    setState(() {
      _ayahs = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Islam307Theme.white,
      appBar: AppBar(
        title: Text('Surah ${widget.surahNumber}', style: const TextStyle(fontWeight: FontWeight.w800)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => context.pop()),
        actions: [
          IconButton(
            icon: const Icon(Icons.text_increase_rounded),
            onPressed: () => setState(() => _fontSize = (_fontSize + 2).clamp(16, 36)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Islam307Theme.emerald))
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _ayahs.length,
              itemBuilder: (_, i) {
                final a = _ayahs[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Islam307Theme.fieldFill,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Islam307Theme.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Islam307Theme.emeraldSoft, borderRadius: BorderRadius.circular(8)),
                            child: Text('${a['surah_number']}:${a['ayah_number']}', style: const TextStyle(fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep, fontSize: 12)),
                          ),
                          const Spacer(),
                          Text('Page ${a['page_madani']} · Juz ${a['juz']}', style: const TextStyle(fontSize: 11, color: Islam307Theme.textMuted)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${a['text_uthmani']}',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: _fontSize, height: 2, color: Islam307Theme.textPrimary),
                      ),
                      if ((a['translation_en'] as String?)?.isNotEmpty == true) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.only(left: 12),
                          decoration: const BoxDecoration(border: Border(left: BorderSide(color: Islam307Theme.gold, width: 3))),
                          child: Text('${a['translation_en']}', style: const TextStyle(color: Islam307Theme.textMuted, height: 1.6)),
                        ),
                      ],
                      if (a['has_sajda'] == 1)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('۩ Sajdah', style: TextStyle(color: Islam307Theme.gold, fontWeight: FontWeight.w800, fontSize: 12)),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
