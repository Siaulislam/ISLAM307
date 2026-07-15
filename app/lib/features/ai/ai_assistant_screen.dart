import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/ai/evidence_scope.dart';
import '../../core/ai/query_language.dart';
import '../../core/ai/source_reference_search.dart';
import '../../core/database/database_registry.dart';
import '../../core/theme/islam307_theme.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _controller = TextEditingController();
  final _search =
      SourceReferenceSearch(registry: DatabaseRegistry.instance);

  SourceReferenceResult? _result;
  bool _loading = false;
  int _requestId = 0;

  Future<void> _run({EvidenceScope? scope}) async {
    if (_loading && scope == null) return;
    final question = _controller.text.trim();
    if (question.isEmpty) return;
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
    });
    try {
      final result = await _search.search(
        question,
        scopeOverride: scope,
      );
      if (!mounted || requestId != _requestId) return;
      setState(() => _result = result);
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      final language = QueryLanguageDetector.detect(question);
      setState(
        () => _result = SourceReferenceResult.empty(
          _errorMessage(language),
          language: language,
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
    final rtl = result?.language != QueryLanguage.english;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Zia Assistant',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
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
                hintText: 'Ask in Urdu, English, or Arabic…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  onPressed: _loading ? null : _run,
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Answers use retrieved local app data only. No local result means no answer is generated.',
              style: TextStyle(
                color: Islam307Theme.textMuted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Islam307Theme.emerald,
                    ),
                  )
                : result == null
                    ? const Center(
                        child: Text(
                          'Ask a question to search all local knowledge.',
                          style: TextStyle(color: Islam307Theme.textMuted),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [
                          _answerCard(result.answerText, rtl: rtl),
                          if (result.needsScopeChoice) ...[
                            const SizedBox(height: 12),
                            _scopeChoices(result.language),
                          ],
                          if (result.hasReferences) ...[
                            const SizedBox(height: 18),
                            Text(
                              _evidenceHeading(result.language),
                              textDirection:
                                  rtl ? TextDirection.rtl : TextDirection.ltr,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Islam307Theme.emeraldDeep,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...result.references.map(_referenceCard),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _answerCard(String answer, {required bool rtl}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          answer,
          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
          textAlign: rtl ? TextAlign.right : TextAlign.left,
          style: const TextStyle(height: 1.65, fontSize: 15),
        ),
      ),
    );
  }

  Widget _scopeChoices(QueryLanguage language) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton(
          onPressed: () => _run(scope: EvidenceScope.quran),
          child: Text(_scopeLabel(EvidenceScope.quran, language)),
        ),
        FilledButton(
          onPressed: () => _run(scope: EvidenceScope.hadith),
          child: Text(_scopeLabel(EvidenceScope.hadith, language)),
        ),
        FilledButton(
          onPressed: () => _run(scope: EvidenceScope.both),
          child: Text(_scopeLabel(EvidenceScope.both, language)),
        ),
      ],
    );
  }

  String _scopeLabel(EvidenceScope scope, QueryLanguage language) {
    return switch ((scope, language)) {
      (EvidenceScope.quran, QueryLanguage.urdu) => 'قرآن',
      (EvidenceScope.hadith, QueryLanguage.urdu) => 'حدیث',
      (EvidenceScope.both, QueryLanguage.urdu) => 'دونوں',
      (EvidenceScope.quran, QueryLanguage.arabic) => 'القرآن',
      (EvidenceScope.hadith, QueryLanguage.arabic) => 'الحديث',
      (EvidenceScope.both, QueryLanguage.arabic) => 'كلاهما',
      (EvidenceScope.quran, QueryLanguage.english) => 'Quran',
      (EvidenceScope.hadith, QueryLanguage.english) => 'Hadith',
      (EvidenceScope.both, QueryLanguage.english) => 'Both',
    };
  }

  Widget _referenceCard(SourceReference reference) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Islam307Theme.emeraldSoft,
          child: Icon(
            _sourceIcon(reference.type),
            color: Islam307Theme.emerald,
            size: 18,
          ),
        ),
        title: Text(
          reference.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reference.excerpt,
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(height: 1.45),
              ),
              const SizedBox(height: 6),
              Text(
                reference.citationLines.join('\n'),
                style: const TextStyle(
                  color: Islam307Theme.emeraldDeep,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        onTap: reference.route == null
            ? null
            : () => context.push(reference.route!),
      ),
    );
  }

  IconData _sourceIcon(SourceType type) {
    return switch (type) {
      SourceType.quran => Icons.menu_book_rounded,
      SourceType.hadith => Icons.auto_stories_rounded,
      SourceType.word => Icons.translate_rounded,
      SourceType.narrator => Icons.person_search_rounded,
      SourceType.personal => Icons.person_rounded,
      SourceType.app => Icons.storage_rounded,
    };
  }

  String _evidenceHeading(QueryLanguage language) {
    return switch (language) {
      QueryLanguage.urdu => 'مقامی حوالے',
      QueryLanguage.arabic => 'المراجع المحلية',
      QueryLanguage.english => 'Local references',
    };
  }

  String _errorMessage(QueryLanguage language) {
    return switch (language) {
      QueryLanguage.urdu =>
        'مقامی ڈیٹابیس تلاش نہیں ہو سکا۔ کوئی جواب تیار نہیں کیا گیا۔',
      QueryLanguage.arabic =>
        'تعذر البحث في قاعدة البيانات المحلية. لم يتم إنشاء أي إجابة.',
      QueryLanguage.english =>
        'The local database search failed. No answer was generated.',
    };
  }
}
