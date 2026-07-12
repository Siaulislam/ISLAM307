import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/database/database_registry.dart';
import '../../core/repositories/hadith_repository.dart';
import '../../core/theme/islam307_theme.dart';

/// Professional Hadith book browse: Topics (کتاب) only.
/// Tapping a topic opens the full Hadith Reader immediately — no number list.
class HadithBookScreen extends StatefulWidget {
  const HadithBookScreen({super.key, required this.bookId});
  final int bookId;

  @override
  State<HadithBookScreen> createState() => _HadithBookScreenState();
}

class _HadithBookScreenState extends State<HadithBookScreen> {
  final _repo = HadithRepository(DatabaseRegistry.instance);
  Map<String, dynamic>? _book;
  List<Map<String, dynamic>> _topics = [];
  bool _loading = true;
  bool _opening = false;

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
    final topics = await _repo.chaptersWithCounts(widget.bookId);
    if (!mounted) return;
    setState(() {
      _book = book;
      _topics = topics;
      _loading = false;
    });
  }

  Future<void> _openTopic(Map<String, dynamic> topic) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final chapterId = topic['id'] as int;
      final first = await _repo.firstHadithNumberForChapter(widget.bookId, chapterId);
      if (!mounted) return;
      if (first == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No authentic reference found.')),
        );
        return;
      }
      context.push('/hadith/read/${widget.bookId}/$first?chapterId=$chapterId');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _openAllReader() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final rows = await _repo.hadithsForBook(widget.bookId, limit: 1, offset: 0);
      if (!mounted) return;
      if (rows.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No authentic reference found.')),
        );
        return;
      }
      context.push('/hadith/read/${widget.bookId}/${rows.first['hadith_number']}');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  String _topicTitle(Map<String, dynamic> topic) {
    final ur = '${topic['title_ur'] ?? ''}'.trim();
    final en = '${topic['title_en'] ?? topic['title'] ?? ''}'.trim();
    if (ur.isNotEmpty && ur != en) return ur;
    final ar = '${topic['title_ar'] ?? ''}'.trim();
    if (ar.isNotEmpty) return ar;
    return ur.isNotEmpty ? ur : (en.isEmpty ? '—' : en);
  }

  @override
  Widget build(BuildContext context) {
    final title = _book?['name_en']?.toString() ?? 'Hadith';
    final total = _book?['hadith_count'];
    final totalLabel = total == null ? title : '$title · $total';

    return Scaffold(
      appBar: AppBar(
        title: Text(totalLabel, style: const TextStyle(fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _opening ? null : _openAllReader,
            child: const Text('Read all ▶', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      body: Stack(
        children: [
          _loading
              ? const Center(child: CircularProgressIndicator(color: Islam307Theme.emerald))
              : _topicsList(),
          if (_opening)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x33FFFFFF),
                child: Center(child: CircularProgressIndicator(color: Islam307Theme.emerald)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _topicsList() {
    if (_topics.isEmpty) {
      return const Center(child: Text('No topics found in authenticated source.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _topics.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Tap a کتاب/topic to open the full Hadith Reader immediately — e.g. کتاب وحی کے بیان میں. No number list.',
              style: TextStyle(color: Islam307Theme.textMuted, height: 1.45, fontSize: 13),
            ),
          );
        }
        final topic = _topics[i - 1];
        final count = topic['hadith_count'] ?? 0;
        final index = topic['number'] ?? i;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _openTopic(topic),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Islam307Theme.cardBorder),
                  gradient: LinearGradient(
                    colors: [
                      Islam307Theme.emeraldSoft.withValues(alpha: 0.7),
                      Theme.of(context).cardColor,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Islam307Theme.emeraldDeep,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '$index'.padLeft(2, '0'),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _topicTitle(topic),
                            textAlign: TextAlign.right,
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$count',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Islam307Theme.emeraldDeep),
                        ),
                        const Text('open ▶', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Islam307Theme.emerald)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
