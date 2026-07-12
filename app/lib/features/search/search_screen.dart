import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/search/global_search_service.dart';
import '../../core/theme/islam307_theme.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _service = GlobalSearchService();
  List<GlobalSearchHit> _hits = [];
  bool _loading = false;

  Future<void> _run(String q) async {
    setState(() => _loading = true);
    final hits = await _service.search(q);
    if (!mounted) return;
    setState(() {
      _hits = hits;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search', style: TextStyle(fontWeight: FontWeight.w800)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => context.pop()),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _controller,
              onSubmitted: _run,
              onChanged: (q) {
                if (q.trim().length >= 2) _run(q);
                if (q.trim().isEmpty) setState(() => _hits = []);
              },
              decoration: const InputDecoration(
                hintText: 'Arabic, Urdu, English, root, word, morphology, ayah, surah, juz, page…',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Instant offline search across Quran, words/roots/grammar, Hadith, and Tafsir. Try: 2:255 · juz 1 · page 2 · root رحم · نماز',
              style: TextStyle(color: Islam307Theme.textMuted, fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Islam307Theme.emerald))
                : ListView.builder(
                    itemCount: _hits.length,
                    itemBuilder: (_, i) {
                      final h = _hits[i];
                      return ListTile(
                        leading: Chip(label: Text(h.kind, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                        title: Text(h.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(h.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                        onTap: () => context.push(h.route),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
