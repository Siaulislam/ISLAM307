import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/ai/source_reference_search.dart';
import '../../core/theme/islam307_theme.dart';

/// Source-only AI assistant — never invents religious content.
class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final _controller = TextEditingController();
  final _search = SourceReferenceSearch();
  SourceReferenceResult? _result;
  bool _loading = false;
  int _requestId = 0;

  Future<void> _run() async {
    if (_loading) return;
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    final requestId = ++_requestId;
    setState(() => _loading = true);
    try {
      final result = await _search.search(q);
      if (!mounted || requestId != _requestId) return;
      setState(() => _result = result);
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(
        () => _result = SourceReferenceResult.empty(
          'Authenticated sources could not be reached. No answer was generated.',
        ),
      );
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant', style: TextStyle(fontWeight: FontWeight.w800)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => context.pop()),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: _loading ? null : (_) => _run(),
              decoration: InputDecoration(
                hintText: 'Ask with a topic, e.g. نماز / prayer / صبر',
                prefixIcon: const Icon(Icons.auto_awesome_rounded),
                suffixIcon: IconButton(onPressed: _loading ? null : _run, icon: const Icon(Icons.search_rounded)),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Searches only approved local Arabic Quran text and your personal SQLite notes. Permission-pending Hadith, translations and Tafseer are not searched, streamed or generated.',
              style: TextStyle(color: Islam307Theme.textMuted, fontSize: 12, height: 1.4),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Islam307Theme.emerald))
                : result == null
                    ? const Center(child: Text('Enter a topic to search authenticated offline sources.', style: TextStyle(color: Islam307Theme.textMuted)))
                    : !result.hasReferences
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                result.answerExcerpt ?? SourceReferenceSearch.noReferenceMessage,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                              ),
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            children: [
                              _sectionHeader('Relevant Quran verses'),
                              ...result.byType(SourceType.quran).map(_refTile),
                              _sectionHeader('Relevant Hadith'),
                              ..._orEmpty(result.byType(SourceType.hadith)),
                              _sectionHeader('Relevant Tafsir'),
                              ..._orEmpty(result.byType(SourceType.tafsir)),
                              _sectionHeader('Word meanings / grammar'),
                              ..._orEmpty(result.byType(SourceType.word)),
                              _sectionHeader('Personal notes'),
                              ..._orEmpty(result.byType(SourceType.user)),
                              _sectionHeader('Application features'),
                              ..._orEmpty(result.byType(SourceType.feature)),
                              const SizedBox(height: 12),
                              const Text('References', style: TextStyle(fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep)),
                              const SizedBox(height: 6),
                              Text(
                                result.references.map((r) => '• ${r.title}').join('\n'),
                                style: const TextStyle(height: 1.5, fontSize: 13, color: Islam307Theme.textMuted),
                              ),
                            ],
                          ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep)),
    );
  }

  List<Widget> _orEmpty(List<SourceReference> refs) {
    if (refs.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(SourceReferenceSearch.noReferenceMessage, style: TextStyle(color: Islam307Theme.textMuted)),
        ),
      ];
    }
    return refs.map(_refTile).toList();
  }

  Widget _refTile(SourceReference r) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Text(r.excerpt, maxLines: 5, overflow: TextOverflow.ellipsis, style: const TextStyle(height: 1.45)),
            if (r.type == SourceType.hadith) ...[
              const SizedBox(height: 6),
              Text(r.hadithCitationLines.join('\n'), style: const TextStyle(fontSize: 12, color: Islam307Theme.emeraldDeep, height: 1.4)),
            ],
            if (r.type == SourceType.tafsir) ...[
              const SizedBox(height: 6),
              Text(
                r.tafsirCitationLines.join('\n'),
                style: const TextStyle(
                  fontSize: 12,
                  color: Islam307Theme.emeraldDeep,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
        onTap: () {
          if (r.type == SourceType.quran && r.surah != null && r.ayah != null) {
            context.push('/quran/read/${r.surah}/${r.ayah}');
          } else if (r.type == SourceType.hadith && r.hadithBook != null && r.hadithNumber != null) {
            // Book id is not always on the reference; stay on AI and keep citation visible.
          } else if (r.type == SourceType.tafsir && r.surah != null && r.ayah != null) {
            context.push('/feature/tafsir');
          } else if (r.type == SourceType.word && r.surah != null && r.ayah != null) {
            context.push('/quran/read/${r.surah}/${r.ayah}');
          } else if (r.type == SourceType.feature &&
              r.targetUri?.startsWith('/') == true) {
            context.push(r.targetUri!);
          } else if (r.type == SourceType.user &&
              r.targetUri?.startsWith('quran://') == true) {
            final match =
                RegExp(r'^quran://(\d+)/(\d+)$').firstMatch(r.targetUri!);
            if (match != null) {
              context.push('/quran/read/${match.group(1)}/${match.group(2)}');
            }
          }
        },
      ),
    );
  }
}
