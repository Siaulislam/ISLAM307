import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/repositories/quran_repository.dart';
import '../../core/theme/islam307_theme.dart';

class QuranSurahListScreen extends StatefulWidget {
  const QuranSurahListScreen({super.key});

  @override
  State<QuranSurahListScreen> createState() => _QuranSurahListScreenState();
}

class _QuranSurahListScreenState extends State<QuranSurahListScreen> {
  final _repo = QuranRepository();
  final _search = TextEditingController();
  List<Map<String, dynamic>> _surahs = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _repo.surahs();
    if (!mounted) return;
    setState(() {
      _surahs = list;
      _filtered = list;
      _loading = false;
    });
  }

  void _filter(String q) {
    final query = q.trim().toLowerCase();
    setState(() {
      _filtered = _surahs.where((s) {
        if (query.isEmpty) return true;
        return '${s['number']}'.contains(query) ||
            '${s['name_en']}'.toLowerCase().contains(query) ||
            '${s['name_ar']}'.contains(q) ||
            '${s['name_transliteration']}'.toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse by Surah', style: TextStyle(fontWeight: FontWeight.w800)),
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
                    onChanged: _filter,
                    decoration: const InputDecoration(
                      hintText: 'Search surah name or number…',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final s = _filtered[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Islam307Theme.emeraldSoft,
                          child: Text('${s['number']}', style: const TextStyle(fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep)),
                        ),
                        title: Text('${s['name_en']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${s['name_ar']} · ${s['ayah_count']} ayahs · ${s['revelation_place']}'),
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
