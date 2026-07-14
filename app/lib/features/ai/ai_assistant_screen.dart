import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/ai/source_reference_search.dart';
import '../../core/database/database_registry.dart';
import '../../core/repositories/tafsir_repository.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/islam307_theme.dart';

/// Source-only AI assistant — never invents religious content.
class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final _controller = TextEditingController();
  final _search = SourceReferenceSearch(registry: DatabaseRegistry.instance);
  final _tafsirRepo = TafsirRepository();
  SourceReferenceResult? _result;
  List<Map<String, dynamic>> _tafsirSources = const [];
  String _tafsirSlug = 'ibn-kathir';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadTafsirSources();
  }

  Future<void> _loadTafsirSources() async {
    final sources = await _tafsirRepo.catalogSources();
    final preferred = ref.read(appSettingsProvider).preferredTafsirSlug;
    if (!mounted) return;
    setState(() {
      _tafsirSources = sources;
      _tafsirSlug = sources.any((source) => source['slug'] == preferred)
          ? preferred
          : 'ibn-kathir';
    });
  }

  Future<void> _run() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    setState(() => _loading = true);
    final result = await _search.search(
      q,
      tafsirSourceSlug: _tafsirSlug,
    );
    if (!mounted) return;
    setState(() {
      _result = result;
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
              onSubmitted: (_) => _run(),
              decoration: InputDecoration(
                hintText: 'Ask with a topic, e.g. نماز / prayer / صبر',
                prefixIcon: const Icon(Icons.auto_awesome_rounded),
                suffixIcon: IconButton(onPressed: _loading ? null : _run, icon: const Icon(Icons.search_rounded)),
              ),
            ),
          ),
          if (_tafsirSources.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: DropdownButtonFormField<String>(
                value: _tafsirSlug,
                decoration: const InputDecoration(
                  labelText: 'Tafseer source for verse explanations',
                ),
                items: _tafsirSources
                    .map(
                      (source) => DropdownMenuItem(
                        value: source['slug'] as String,
                        child: Text(
                          '${source['name_en']}${source['available'] == true ? '' : ' · unavailable'}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) async {
                  if (value == null) return;
                  setState(() => _tafsirSlug = value);
                  await ref
                      .read(appSettingsProvider.notifier)
                      .setPreferredTafsir(value);
                },
              ),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Quran and Hadith search locally. Explicit requests such as “Explain Quran 2:255” retrieve the selected Tafseer directly from an authorized official API. Tafseer is never generated or read from bundled files.',
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
            context.push(
              '/tafsir/${r.tafsirSlug ?? _tafsirSlug}/${r.surah}/${r.ayah}',
            );
          } else if (r.type == SourceType.word && r.surah != null && r.ayah != null) {
            context.push('/quran/read/${r.surah}/${r.ayah}');
          }
        },
      ),
    );
  }
}
