import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/database/database_registry.dart';
import '../../core/repositories/hadith_repository.dart';
import '../../core/theme/islam307_theme.dart';

/// Professional Hadith book browse: Topics (کتاب) first, then related hadiths.
class HadithBookScreen extends StatefulWidget {
  const HadithBookScreen({super.key, required this.bookId});
  final int bookId;

  @override
  State<HadithBookScreen> createState() => _HadithBookScreenState();
}

enum _BrowseMode { topics, numbers, topic }

class _HadithBookScreenState extends State<HadithBookScreen> {
  final _repo = HadithRepository(DatabaseRegistry.instance);
  Map<String, dynamic>? _book;
  List<Map<String, dynamic>> _topics = [];
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  int _offset = 0;
  static const _pageSize = 100;
  _BrowseMode _mode = _BrowseMode.topics;
  Map<String, dynamic>? _activeTopic;

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
    setState(() {
      _mode = _BrowseMode.topic;
      _activeTopic = topic;
      _items = [];
      _offset = 0;
      _loading = true;
    });
    final rows = await _repo.hadithsForChapter(
      widget.bookId,
      topic['id'] as int,
      limit: _pageSize,
      offset: 0,
    );
    if (!mounted) return;
    setState(() {
      _items = rows;
      _offset = rows.length;
      _loading = false;
    });
  }

  Future<void> _openAllNumbers() async {
    setState(() {
      _mode = _BrowseMode.numbers;
      _activeTopic = null;
      _items = [];
      _offset = 0;
      _loading = true;
    });
    final rows = await _repo.hadithsForBook(widget.bookId, limit: _pageSize, offset: 0);
    if (!mounted) return;
    setState(() {
      _items = rows;
      _offset = rows.length;
      _loading = false;
    });
  }

  Future<void> _backToTopics() async {
    setState(() {
      _mode = _BrowseMode.topics;
      _activeTopic = null;
      _items = [];
      _offset = 0;
      _loading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _mode == _BrowseMode.topics) return;
    setState(() => _loadingMore = true);
    final rows = _mode == _BrowseMode.topic && _activeTopic != null
        ? await _repo.hadithsForChapter(
            widget.bookId,
            _activeTopic!['id'] as int,
            limit: _pageSize,
            offset: _offset,
          )
        : await _repo.hadithsForBook(widget.bookId, limit: _pageSize, offset: _offset);
    if (!mounted) return;
    setState(() {
      _items = [..._items, ...rows];
      _offset += rows.length;
      _loadingMore = false;
    });
  }

  String _topicTitle(Map<String, dynamic> topic) {
    final ur = '${topic['title_ur'] ?? ''}'.trim();
    final en = '${topic['title_en'] ?? topic['title'] ?? ''}'.trim();
    if (ur.isNotEmpty && ur != en) return ur;
    final ar = '${topic['title_ar'] ?? ''}'.trim();
    if (ar.isNotEmpty) return ar;
    return ur.isNotEmpty ? ur : (en.isEmpty ? '—' : en);
  }

  String _kitabFromHadith(Map<String, dynamic> h) {
    final detail = h['reference_detail'];
    String kitab = '';
    if (detail is Map) {
      kitab = (detail['kitab'] ?? '').toString();
      final byLang = detail['by_lang'];
      if (byLang is Map) {
        final ur = byLang['ur'];
        if (ur is Map) {
          final values = ur['values'];
          if (values is Map && (values['kitab']?.toString().isNotEmpty ?? false)) {
            kitab = values['kitab'].toString();
          }
        }
      }
    }
    if (kitab.isEmpty) kitab = (h['kitab'] ?? h['chapter_title'] ?? '').toString();
    return kitab;
  }

  @override
  Widget build(BuildContext context) {
    final title = _book?['name_en']?.toString() ?? 'Hadith';
    final total = _book?['hadith_count'];
    final totalLabel = total == null ? title : '$title · $total';
    final topicTotal = _activeTopic?['hadith_count'];
    final hasMore = _mode == _BrowseMode.topic
        ? (topicTotal is int ? _items.length < topicTotal : true)
        : (total is int ? _items.length < total : true);

    return Scaffold(
      appBar: AppBar(
        title: Text(totalLabel, style: const TextStyle(fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () {
            if (_mode == _BrowseMode.topic) {
              _backToTopics();
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _modeToggle(),
          ),
          if (_mode == _BrowseMode.topic && _activeTopic != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _topicBanner(_activeTopic!),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Islam307Theme.emerald))
                : _mode == _BrowseMode.topics
                    ? _topicsList()
                    : _hadithList(hasMore: hasMore, total: _mode == _BrowseMode.topic ? topicTotal : total),
          ),
        ],
      ),
    );
  }

  Widget _modeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Islam307Theme.fieldFill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Islam307Theme.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _seg(
              label: 'Topics · موضوعات',
              selected: _mode == _BrowseMode.topics || _mode == _BrowseMode.topic,
              onTap: _backToTopics,
            ),
          ),
          Expanded(
            child: _seg(
              label: 'All numbers',
              selected: _mode == _BrowseMode.numbers,
              onTap: _openAllNumbers,
            ),
          ),
        ],
      ),
    );
  }

  Widget _seg({required String label, required bool selected, required VoidCallback onTap}) {
    return Material(
      color: selected ? Islam307Theme.emerald : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: selected ? Colors.white : Islam307Theme.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _topicBanner(Map<String, dynamic> topic) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Islam307Theme.emeraldSoft,
            Colors.white.withValues(alpha: 0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Islam307Theme.emerald.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _topicTitle(topic),
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.5, color: Islam307Theme.emeraldDeep),
          ),
          const SizedBox(height: 4),
          Text(
            '${topic['title_en'] ?? ''} · ${topic['hadith_count'] ?? _items.length} related hadith',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Islam307Theme.textMuted),
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
              'Tap a کتاب/topic to open every related hadith — e.g. کتاب وحی کے بیان میں.',
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
                          const SizedBox(height: 2),
                          Text(
                            '${topic['title_en'] ?? ''}',
                            style: const TextStyle(fontSize: 12, color: Islam307Theme.textMuted, fontWeight: FontWeight.w600),
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
                        const Text('hadith', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Islam307Theme.textMuted)),
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

  Widget _hadithList({required bool hasMore, required Object? total}) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (hasMore && n.metrics.pixels > n.metrics.maxScrollExtent - 240) _loadMore();
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _items.length + ((hasMore || _loadingMore) ? 1 : 0),
        itemBuilder: (_, i) {
          if (i >= _items.length) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: _loadingMore
                    ? const CircularProgressIndicator(color: Islam307Theme.emerald)
                    : Text(
                        'Scroll for more · ${_items.length}${total is int ? ' / $total' : ''} hadith',
                        style: const TextStyle(color: Colors.black54),
                      ),
              ),
            );
          }
          final h = _items[i];
          final kitab = _kitabFromHadith(h);
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => context.push('/hadith/read/${widget.bookId}/${h['hadith_number']}'),
                    child: Text(
                      'Hadith ${h['hadith_number']}',
                      style: const TextStyle(
                        color: Islam307Theme.emerald,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        // From all-numbers mode, open this hadith's topic.
                        if (_mode == _BrowseMode.numbers) {
                          final chapterId = h['chapter_id'];
                          Map<String, dynamic>? topic;
                          for (final t in _topics) {
                            if (t['id'] == chapterId) topic = t;
                          }
                          if (topic != null) {
                            _openTopic(topic);
                            return;
                          }
                        }
                        context.push('/hadith/read/${widget.bookId}/${h['hadith_number']}');
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              kitab.isEmpty ? '—' : kitab,
                              textAlign: TextAlign.right,
                              textDirection: TextDirection.rtl,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.55),
                            ),
                            if (_mode == _BrowseMode.numbers)
                              const Text(
                                'Open topic →',
                                textAlign: TextAlign.right,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Islam307Theme.emerald),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
