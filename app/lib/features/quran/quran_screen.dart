import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/database/quran_database.dart';
import '../../core/theme/islam307_theme.dart';

class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _surahs = [];
  List<Map<String, dynamic>> _results = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await QuranDatabase.instance.surahs();
    if (!mounted) return;
    setState(() {
      _surahs = list;
      _loading = false;
    });
  }

  Future<void> _searchAyahs(String q) async {
    setState(() => _query = q);
    if (q.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    final rows = await QuranDatabase.instance.search(q);
    if (mounted) setState(() => _results = rows);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Islam307Theme.white,
      appBar: AppBar(
        title: const Text('Al-Quran', style: TextStyle(fontWeight: FontWeight.w800)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => context.pop()),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Islam307Theme.emerald))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: TextField(
                    controller: _search,
                    onChanged: _searchAyahs,
                    style: const TextStyle(color: Islam307Theme.textPrimary, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Instant search — surah, ayah, translation…',
                      prefixIcon: const Icon(Icons.search_rounded, color: Islam307Theme.textMuted),
                      filled: true,
                      fillColor: Islam307Theme.fieldFill,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                if (_query.isNotEmpty)
                  Expanded(
                    child: ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (_, i) {
                        final r = _results[i];
                        return ListTile(
                          title: Text('${r['name_en']} ${r['surah_number']}:${r['ayah_number']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('${r['text_uthmani']}', maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right),
                          onTap: () => context.push('/quran/read/${r['surah_number']}/${r['ayah_number']}'),
                        );
                      },
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: _surahs.length,
                      itemBuilder: (_, i) {
                        final s = _surahs[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Islam307Theme.emeraldSoft,
                            child: Text('${s['number']}', style: const TextStyle(fontWeight: FontWeight.w800, color: Islam307Theme.emerald)),
                          ),
                          title: Text('${s['name_en']}', style: const TextStyle(fontWeight: FontWeight.w700, color: Islam307Theme.textPrimary)),
                          subtitle: Text('${s['name_ar']} · ${s['ayah_count']} ayahs', style: const TextStyle(color: Islam307Theme.textMuted)),
                          onTap: () => context.push('/quran/read/${s['number']}/1'),
                        );
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}
