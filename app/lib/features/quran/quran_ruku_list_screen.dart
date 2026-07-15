import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/repositories/quran_repository.dart';
import '../../core/theme/islam307_theme.dart';

class QuranRukuListScreen extends StatefulWidget {
  const QuranRukuListScreen({super.key});

  @override
  State<QuranRukuListScreen> createState() => _QuranRukuListScreenState();
}

class _QuranRukuListScreenState extends State<QuranRukuListScreen> {
  final _repo = QuranRepository();
  final _search = TextEditingController();
  List<Map<String, dynamic>> _rukus = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _repo.rukus();
    if (!mounted) return;
    setState(() {
      _rukus = list;
      _filtered = list;
      _loading = false;
    });
  }

  void _filter(String q) {
    final query = q.trim().toLowerCase();
    setState(() {
      _filtered = _rukus.where((r) {
        if (query.isEmpty) return true;
        return '${r['number']}'.contains(query) ||
            '${r['surah_number']}'.contains(query) ||
            '${r['name_en']}'.toLowerCase().contains(query) ||
            '${r['name_ar']}'.contains(q) ||
            'ruku $query' == 'ruku ${r['number']}';
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
        title: const Text('Browse by Ruku', style: TextStyle(fontWeight: FontWeight.w800)),
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
                      hintText: 'Search ruku number or surah…',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final r = _filtered[i];
                      final end = r['end_ayah'] ?? '?';
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Islam307Theme.emeraldSoft,
                          child: Text('${r['number']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep)),
                        ),
                        title: Text('Ruku ${r['number']} · ${r['name_en']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${r['name_ar']} · ${r['surah_number']}:${r['start_ayah']}–$end · Juz ${r['juz']}'),
                        onTap: () => context.push('/quran/ruku/${r['number']}'),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
