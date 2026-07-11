import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/database/database_registry.dart';
import '../../core/repositories/hadith_repository.dart';
import '../../core/theme/islam307_theme.dart';

class HadithScreen extends StatefulWidget {
  const HadithScreen({super.key});

  @override
  State<HadithScreen> createState() => _HadithScreenState();
}

class _HadithScreenState extends State<HadithScreen> {
  final _repo = HadithRepository(DatabaseRegistry.instance);
  final _search = TextEditingController();
  List<Map<String, dynamic>> _books = [];
  List<Map<String, dynamic>> _results = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final books = await _repo.books(enabledOnly: true);
      if (!mounted) return;
      setState(() {
        _books = books;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _onSearch(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    final rows = await _repo.search(q);
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
      appBar: AppBar(
        title: const Text('Hadith', style: TextStyle(fontWeight: FontWeight.w800)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => context.pop()),
        actions: [
          IconButton(onPressed: () => context.push('/search'), icon: const Icon(Icons.search_rounded)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Islam307Theme.emerald))
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
              : Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: Text(
                        'Authentic collections only · never AI-generated',
                        style: TextStyle(color: Islam307Theme.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: TextField(
                        controller: _search,
                        onChanged: _onSearch,
                        decoration: const InputDecoration(
                          hintText: 'Search hadith number or keywords…',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _results.isNotEmpty
                          ? ListView.builder(
                              itemCount: _results.length,
                              itemBuilder: (_, i) {
                                final h = _results[i];
                                return ListTile(
                                  title: Text('${h['book_name']} · ${h['hadith_number']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                  subtitle: Text(
                                    [
                                      if (((h['ravi'] as String?) ?? '').isNotEmpty) 'RAVI: ${h['ravi']}',
                                      'Reference: ${h['reference'] ?? ''}',
                                      '${h['text_en'] ?? h['text_ar'] ?? ''}',
                                    ].where((e) => e.trim().isNotEmpty).join('\n'),
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  isThreeLine: true,
                                  onTap: () => context.push('/hadith/read/${h['book_id']}/${h['hadith_number']}'),
                                );
                              },
                            )
                          : ListView.builder(
                              itemCount: _books.length,
                              itemBuilder: (_, i) {
                                final b = _books[i];
                                return Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Islam307Theme.emeraldSoft,
                                      child: Text('${i + 1}', style: const TextStyle(color: Islam307Theme.emeraldDeep, fontWeight: FontWeight.w800)),
                                    ),
                                    title: Text('${b['name_en']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                    subtitle: Text('${b['name_ar']} · ${(b['hadith_count'] ?? 0)} hadith · Offline'),
                                    onTap: () => context.push('/hadith/book/${b['id']}'),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
