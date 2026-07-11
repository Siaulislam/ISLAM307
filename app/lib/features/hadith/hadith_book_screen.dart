import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/database/database_registry.dart';
import '../../core/repositories/hadith_repository.dart';
import '../../core/theme/islam307_theme.dart';

class HadithBookScreen extends StatefulWidget {
  const HadithBookScreen({super.key, required this.bookId});
  final int bookId;

  @override
  State<HadithBookScreen> createState() => _HadithBookScreenState();
}

class _HadithBookScreenState extends State<HadithBookScreen> {
  final _repo = HadithRepository(DatabaseRegistry.instance);
  Map<String, dynamic>? _book;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  int _offset = 0;
  static const _pageSize = 40;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final books = await _repo.books(enabledOnly: false);
    Map<String, dynamic>? book;
    for (final b in books) {
      if (b['id'] == widget.bookId) book = b;
    }
    final rows = await _repo.hadithsForBook(widget.bookId, limit: _pageSize, offset: 0);
    if (!mounted) return;
    setState(() {
      _book = book;
      _items = rows;
      _offset = rows.length;
      _loading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    final rows = await _repo.hadithsForBook(widget.bookId, limit: _pageSize, offset: _offset);
    if (!mounted) return;
    setState(() {
      _items = [..._items, ...rows];
      _offset += rows.length;
      _loadingMore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = _book?['name_en']?.toString() ?? 'Hadith';
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => context.pop()),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Islam307Theme.emerald))
          : NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.pixels > n.metrics.maxScrollExtent - 240) _loadMore();
                return false;
              },
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: _items.length + (_loadingMore ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i >= _items.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator(color: Islam307Theme.emerald)),
                    );
                  }
                  final h = _items[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text('Hadith ${h['hadith_number']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(
                        'Tap number → Arabic + Urdu/English/Arabic · Ravi & Reference',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      isThreeLine: true,
                      onTap: () => context.push('/hadith/read/${widget.bookId}/${h['hadith_number']}'),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
