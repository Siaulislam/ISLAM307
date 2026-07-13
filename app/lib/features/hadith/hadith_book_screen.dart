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
      final unassigned = topic['is_unassigned'] == true;
      if (unassigned) {
        final nums = await _repo.hadithNumbersUnassigned(widget.bookId);
        if (!mounted) return;
        if (nums.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No authentic reference found.')),
          );
          return;
        }
        context.push('/hadith/read/${widget.bookId}/${nums.first}?unassigned=1');
        return;
      }
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

  String _topicRangeLabel(Map<String, dynamic> topic) {
    final count = int.tryParse('${topic['hadith_count'] ?? ''}') ?? 0;
    final start = topic['hadith_start'] ?? topic['first_hadith'] ?? topic['first'];
    final end = topic['hadith_end'] ?? topic['last_hadith'] ?? topic['last'];
    final nums = (topic['hadith_numbers'] as List?)?.cast<int>();

    if (count == 1 || (start != null && end != null && '$start' == '$end')) {
      return 'Hadith $start';
    }
    if (start == null || end == null || '$start'.isEmpty || '$end'.isEmpty) {
      return count > 0 ? '$count Hadith' : '';
    }

    final span = (int.tryParse('$end') ?? 0) - (int.tryParse('$start') ?? 0) + 1;
    final dense = span > 0 && count / span >= 0.5;
    if (dense) return 'Hadith $start to $end';

    if (nums != null && nums.isNotEmpty) {
      if (nums.length <= 8) return 'Hadith ${nums.join(', ')}';
      return 'Hadith ${nums.take(4).join(', ')}… (+${nums.length - 4} more)';
    }
    return '$count hadith · from $start to $end';
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
      itemCount: _topics.length,
      itemBuilder: (_, i) {
        final topic = _topics[i];
        final count = topic['hadith_count'] ?? 0;
        final unassigned = topic['is_unassigned'] == true;
        final indexLabel = unassigned ? '—' : '${topic['number'] ?? (i + 1)}'.padLeft(2, '0');
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
                        indexLabel,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _topicTitle(topic),
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.5),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _topicRangeLabel(topic),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Islam307Theme.emeraldDeep),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$count Hadith',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Islam307Theme.textMuted),
                        ),
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
