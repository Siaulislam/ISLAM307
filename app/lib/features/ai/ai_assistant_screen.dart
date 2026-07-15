import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/ai/evidence_scope.dart';
import '../../core/ai/query_language.dart';
import '../../core/ai/quran_navigation_resolver.dart';
import '../../core/ai/source_reference_search.dart';
import '../../core/audio/recitation_audio_service.dart';
import '../../core/audio/speech_input_service.dart';
import '../../core/audio/tts_service.dart';
import '../../core/database/database_registry.dart';
import '../../core/database/quran_database.dart';
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
  QueryLanguage _responseLanguage = QueryLanguage.urdu;
  bool _loading = false;
  bool _listening = false;
  String? _voiceStatus;
  String _lastQuestion = '';
  int _requestId = 0;

  Future<void> _run({
    EvidenceScope? scope,
    String? questionOverride,
  }) async {
    if (_loading && scope == null) return;
    final question = (questionOverride ?? _controller.text).trim();
    if (question.isEmpty) return;
    if (scope == null && await _handleQuranNavigation(question)) return;
    if (_isReadCommand(question) && _result != null) {
      await _speakAnswer(_result!);
      return;
    }
    if (scope == null) _lastQuestion = question;
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
    });
    try {
      final result = await _search.search(
        question,
        scopeOverride: scope,
        languageOverride: _responseLanguage,
      );
      if (!mounted || requestId != _requestId) return;
      await _startAnswerVoice(result);
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

  Future<void> _toggleListening() async {
    if (_listening) {
      await SpeechInputService.instance.stop();
      if (mounted) {
        setState(() {
          _listening = false;
          _voiceStatus = _stoppedListeningLabel(_responseLanguage);
        });
      }
      return;
    }
    await TtsService.instance.stop();
    if (mounted) {
      setState(() => _voiceStatus = _listeningLabel(_responseLanguage));
    }
    final active = await SpeechInputService.instance.start(
      localeId: _speechLocale(_responseLanguage),
      onResult: (words, isFinal) {
        if (!mounted) return;
        setState(() {
          _controller.text = words;
          _controller.selection = TextSelection.collapsed(
            offset: words.length,
          );
          _voiceStatus = isFinal
              ? _processingLabel(_responseLanguage)
              : _listeningLabel(_responseLanguage);
        });
        if (!isFinal) return;
        setState(() => _listening = false);
        unawaited(_processFinalVoice(words));
      },
      onError: (message) {
        if (!mounted) return;
        setState(() {
          _listening = false;
          _voiceStatus = message;
        });
      },
    );
    if (!mounted) return;
    setState(() {
      _listening = active;
      if (!active && _voiceStatus == _listeningLabel(_responseLanguage)) {
        _voiceStatus =
            'Microphone permission or speech recognition is unavailable.';
      }
    });
  }

  Future<void> _processFinalVoice(String words) async {
    if (await _handleQuranNavigation(words)) return;
    if (_handleVoiceScopeChoice(words)) return;
    if (_isReadCommand(words) && _result != null) {
      await _speakAnswer(_result!);
      return;
    }
    await _run(questionOverride: words);
  }

  Future<bool> _handleQuranNavigation(String command) async {
    try {
      final surahs = await QuranDatabase.instance.surahs();
      final match = QuranNavigationResolver.resolve(command, surahs);
      if (match == null || !mounted) return false;
      await TtsService.instance.stop();
      await RecitationAudioService.instance.stop();
      if (!mounted) return true;
      setState(() {
        _voiceStatus = match.autoPlay
            ? 'Opening ${match.displayName} with Sheikh Sudais recitation…'
            : 'Opening ${match.displayName}…';
      });
      final autoplay = match.autoPlay ? '1' : '0';
      context.push(
        '/quran/read/${match.surahNumber}/1'
        '?autoplay=$autoplay&reciter=sudais',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _handleVoiceScopeChoice(String words) {
    if (_result?.needsScopeChoice != true) return false;
    final value = words.toLowerCase();
    EvidenceScope? scope;
    if (RegExp(r'\bboth\b|دونوں|كلاهما').hasMatch(value)) {
      scope = EvidenceScope.both;
    } else if (RegExp(r'\bhadith\b|\bhadees\b|حدیث|الحديث').hasMatch(value)) {
      scope = EvidenceScope.hadith;
    } else if (RegExp(r'\bquran\b|قرآن|القرآن').hasMatch(value)) {
      scope = EvidenceScope.quran;
    }
    if (scope == null) return false;
    _run(scope: scope, questionOverride: _lastQuestion);
    return true;
  }

  bool _isReadCommand(String value) {
    final command = value.toLowerCase().trim();
    return RegExp(
      r'\bread (it|me|this|the answer|answer)\b|\bspeak (it|answer)\b|'
      r'\breplay\b|پڑھ کر سناؤ|مجھے پڑھ|جواب سناؤ|دوبارہ سناؤ|'
      r'اقرأ لي|اقرأ الإجابة|أعد القراءة',
    ).hasMatch(command);
  }

  Future<void> _startAnswerVoice(SourceReferenceResult result) {
    return _speakText(result.answerText, result.language);
  }

  Future<void> _speakAnswer(SourceReferenceResult result) {
    return _speakText(result.answerText, result.language);
  }

  Future<void> _speakText(String text, QueryLanguage language) async {
    final available = await TtsService.instance.speakOffline(
      text,
      language: _ttsLocale(language),
      waitForCompletion: false,
    );
    if (!available && mounted) {
      setState(
        () => _voiceStatus =
            'Install the ${_languageLabel(language)} device voice to read this answer.',
      );
    }
  }

  @override
  void dispose() {
    SpeechInputService.instance.cancel();
    TtsService.instance.stop();
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
          'Ziaulislam',
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
                suffixIcon: SizedBox(
                  width: 96,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: _listening ? 'Stop listening' : 'Ask by voice',
                        onPressed: _loading ? null : _toggleListening,
                        icon: Icon(
                          _listening
                              ? Icons.mic_rounded
                              : Icons.mic_none_rounded,
                          color: _listening ? Colors.red : null,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Ask',
                        onPressed: _loading ? null : _run,
                        icon: const Icon(Icons.arrow_forward_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_voiceStatus != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Text(
                _voiceStatus!,
                style: TextStyle(
                  color: _listening
                      ? Islam307Theme.emerald
                      : Islam307Theme.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                const Text(
                  'Answer:',
                  style: TextStyle(
                    color: Islam307Theme.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                ...QueryLanguage.values.map(
                  (language) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(_languageLabel(language)),
                      selected: _responseLanguage == language,
                      onSelected: (_) {
                        setState(() => _responseLanguage = language);
                        if (_controller.text.trim().isNotEmpty) _run();
                      },
                      selectedColor: Islam307Theme.emerald,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _responseLanguage == language
                            ? Colors.white
                            : null,
                      ),
                    ),
                  ),
                ),
              ],
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
                          _answerCard(
                            result.answerText,
                            language: result.language,
                            rtl: rtl,
                          ),
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

  Widget _answerCard(
    String answer, {
    required QueryLanguage language,
    required bool rtl,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.volume_up_rounded,
                  color: Islam307Theme.emerald,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  _voiceLabel(language),
                  style: const TextStyle(
                    color: Islam307Theme.emeraldDeep,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _speakText(answer, language),
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  label: Text(_readLabel(language)),
                ),
                IconButton(
                  tooltip: 'Stop voice',
                  onPressed: TtsService.instance.stop,
                  icon: const Icon(Icons.stop_circle_outlined),
                ),
              ],
            ),
            const Divider(),
            SelectableText(
              answer,
              textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
              textAlign: rtl ? TextAlign.right : TextAlign.left,
              style: const TextStyle(height: 1.65, fontSize: 15),
            ),
          ],
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
          onPressed: () => _run(
            scope: EvidenceScope.quran,
            questionOverride: _lastQuestion,
          ),
          child: Text(_scopeLabel(EvidenceScope.quran, language)),
        ),
        FilledButton(
          onPressed: () => _run(
            scope: EvidenceScope.hadith,
            questionOverride: _lastQuestion,
          ),
          child: Text(_scopeLabel(EvidenceScope.hadith, language)),
        ),
        FilledButton(
          onPressed: () => _run(
            scope: EvidenceScope.both,
            questionOverride: _lastQuestion,
          ),
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

  String _languageLabel(QueryLanguage language) {
    return switch (language) {
      QueryLanguage.urdu => 'اردو',
      QueryLanguage.english => 'English',
      QueryLanguage.arabic => 'العربية',
    };
  }

  String _speechLocale(QueryLanguage language) {
    return switch (language) {
      QueryLanguage.urdu => 'ur-PK',
      QueryLanguage.english => 'en-US',
      QueryLanguage.arabic => 'ar-SA',
    };
  }

  String _ttsLocale(QueryLanguage language) => _speechLocale(language);

  String _listeningLabel(QueryLanguage language) {
    return switch (language) {
      QueryLanguage.urdu => 'سن رہا ہوں…',
      QueryLanguage.arabic => 'أستمع الآن…',
      QueryLanguage.english => 'Listening…',
    };
  }

  String _processingLabel(QueryLanguage language) {
    return switch (language) {
      QueryLanguage.urdu => 'مقامی ڈیٹابیس تلاش ہو رہا ہے…',
      QueryLanguage.arabic => 'جارٍ البحث في قاعدة البيانات المحلية…',
      QueryLanguage.english => 'Searching the local database…',
    };
  }

  String _stoppedListeningLabel(QueryLanguage language) {
    return switch (language) {
      QueryLanguage.urdu => 'سننا بند کر دیا گیا۔',
      QueryLanguage.arabic => 'تم إيقاف الاستماع.',
      QueryLanguage.english => 'Listening stopped.',
    };
  }

  String _voiceLabel(QueryLanguage language) {
    return switch (language) {
      QueryLanguage.urdu => 'آواز پہلے',
      QueryLanguage.arabic => 'الصوت أولاً',
      QueryLanguage.english => 'Voice first',
    };
  }

  String _readLabel(QueryLanguage language) {
    return switch (language) {
      QueryLanguage.urdu => 'پڑھیں',
      QueryLanguage.arabic => 'اقرأ',
      QueryLanguage.english => 'Read',
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
