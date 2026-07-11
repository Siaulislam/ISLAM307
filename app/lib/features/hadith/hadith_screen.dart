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
      final books = await _repo.books();
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
      backgroundColor: Islam307Theme.white,
      appBar: AppBar(
        title: const Text('Hadith', style: TextStyle(fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Islam307Theme.emerald))
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: TextField(
                        controller: _search,
                        onChanged: _onSearch,
                        decoration: InputDecoration(
                          hintText: 'Search hadith, narrator, grade…',
                          prefixIcon: const Icon(Icons.search_rounded),
                          filled: true,
                          fillColor: Islam307Theme.fieldFill,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _results.isNotEmpty
                          ? ListView.builder(
                              itemCount: _results.length,
                              itemBuilder: (_, i) {
                                final h = _results[i];
                                final grade = HadithRepository.gradingSummary(h);
                                return ListTile(
                                  title: Text('${h['book_name']} · ${h['hadith_number']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                  subtitle: Text(
                                    '${h['text_en'] ?? h['text_ar'] ?? ''}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Text(grade.grade, style: const TextStyle(fontSize: 11, color: Islam307Theme.gold, fontWeight: FontWeight.w700)),
                                  onTap: () => context.push('/hadith/read/${h['book_id']}/${h['hadith_number']}'),
                                );
                              },
                            )
                          : ListView.builder(
                              itemCount: _books.length,
                              itemBuilder: (_, i) {
                                final b = _books[i];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Islam307Theme.emeraldSoft,
                                    child: Text('${i + 1}', style: const TextStyle(color: Islam307Theme.emeraldDeep, fontWeight: FontWeight.w800)),
                                  ),
                                  title: Text('${b['name_en']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                  subtitle: Text('${b['name_ar']} · ${(b['hadith_count'] ?? 0)} hadith · Offline'),
                                  onTap: () => context.push('/hadith/book/${b['id']}'),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
