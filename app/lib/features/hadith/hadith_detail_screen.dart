import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/audio/tts_service.dart';
import '../../core/database/database_registry.dart';
import '../../core/repositories/hadith_repository.dart';
import '../../core/repositories/narrator_repository.dart';
import '../../core/theme/islam307_theme.dart';

/// Full Hadith Reader — opens directly after selecting a book/topic.
/// Arabic always visible; translation language is independent; separate Arabic vs translation audio.
class HadithDetailScreen extends StatefulWidget {
  const HadithDetailScreen({
    super.key,
    required this.bookId,
    required this.hadithNumber,
    this.chapterId,
  });

  final int bookId;
  final int hadithNumber;
  final int? chapterId;

  @override
  State<HadithDetailScreen> createState() => _HadithDetailScreenState();
}

class _HadithDetailScreenState extends State<HadithDetailScreen> {
  final _repo = HadithRepository(DatabaseRegistry.instance);
  final _narratorRepo = NarratorRepository(DatabaseRegistry.instance);
  final _scroll = ScrollController();

  Map<String, dynamic>? _hadith;
  List<int> _numbers = const [];
  int _index = 0;
  bool _loading = true;
  String _lang = 'ur'; // ur | en | hi
  String _audioMode = 'ibarat'; // ibarat | translation
  bool _speaking = false;
  bool _paused = false;
  double _speechRate = 1.0;
  bool _bookmarked = false;
  String _note = '';
  int? _prevNumber;
  int? _nextNumber;

  static const _langOptions = [
    ('ur', 'Urdu'),
    ('en', 'English'),
    ('hi', 'Hindi'),
  ];

  static const _rates = [0.75, 1.0, 1.25, 1.5];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    TtsService.instance.stop();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HadithDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hadithNumber != widget.hadithNumber ||
        oldWidget.bookId != widget.bookId ||
        oldWidget.chapterId != widget.chapterId) {
      _loadCurrent();
    }
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _lang = prefs.getString('i307_hadith_lang') ?? 'ur';
    if (_lang != 'ur' && _lang != 'en' && _lang != 'hi') _lang = 'ur';
    _audioMode = prefs.getString('i307_hadith_audio_mode') ?? 'ibarat';
    _speechRate = prefs.getDouble('i307_hadith_rate') ?? 1.0;
    if (!_rates.contains(_speechRate)) _speechRate = 1.0;

    if (widget.chapterId != null) {
      _numbers = await _repo.hadithNumbersForChapter(widget.bookId, widget.chapterId!);
      final i = _numbers.indexOf(widget.hadithNumber);
      _index = i >= 0 ? i : 0;
    }
    await _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    setState(() => _loading = true);
    final row = await _repo.hadith(widget.bookId, widget.hadithNumber);
    final chapterId = widget.chapterId ?? (row?['chapter_id'] as int?);

    if (widget.chapterId != null && _numbers.isNotEmpty) {
      final i = _numbers.indexOf(widget.hadithNumber);
      _index = i >= 0 ? i : 0;
      _prevNumber = _index > 0 ? _numbers[_index - 1] : null;
      _nextNumber = _index < _numbers.length - 1 ? _numbers[_index + 1] : null;
    } else {
      _prevNumber = await _repo.adjacentHadithNumber(
        widget.bookId,
        widget.hadithNumber,
        next: false,
        chapterId: chapterId,
      );
      _nextNumber = await _repo.adjacentHadithNumber(
        widget.bookId,
        widget.hadithNumber,
        next: true,
        chapterId: chapterId,
      );
      if (chapterId != null && _numbers.isEmpty) {
        _numbers = await _repo.hadithNumbersForChapter(widget.bookId, chapterId);
        final i = _numbers.indexOf(widget.hadithNumber);
        _index = i >= 0 ? i : 0;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final key = _bookmarkKey(widget.bookId, widget.hadithNumber);
    _bookmarked = prefs.getBool(key) ?? false;
    _note = prefs.getString('${key}_note') ?? '';

    if (!mounted) return;
    setState(() {
      _hadith = row;
      _loading = false;
      _speaking = false;
      _paused = false;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  /// Primary narrator name exactly as stored in the authenticated hadith pack.
  /// Never invent Arabic honorifics or alternate spellings.
  String _primaryNarratorName() {
    final h = _hadith;
    if (h == null) return '';
    final fromField = (h['ravi'] ?? h['narrator'] ?? '').toString().trim();
    if (fromField.isNotEmpty) return fromField;
    final chain = _raviChain();
    return chain.isEmpty ? '' : chain.first;
  }

  bool _hasAuthenticatedArabic(Object? raw) {
    final text = '$raw'.trim();
    if (text.isEmpty) return false;
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }

  String _bookSlug() => (_hadith?['book_slug'] ?? '').toString();

  void _openNarratorProfile([String? name, int? narratorId]) {
    final clean = (name ?? _primaryNarratorName()).trim();
    final params = <String, String>{
      'lang': _lang == 'hi' ? 'en' : _lang,
      if (clean.isNotEmpty) 'name': clean,
      if (narratorId != null) 'id': '$narratorId',
      if (_bookSlug().isNotEmpty) 'book': _bookSlug(),
      'n': '${widget.hadithNumber}',
    };
    final q = params.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&');
    context.push('/narrator?$q');
  }

  Future<void> _openRaviSheet() async {
    final h = _hadith;
    if (h == null) return;
    final lang = _lang == 'hi' ? 'en' : _lang;
    final imported = await _narratorRepo.isnadChainForHadith(_bookSlug(), widget.hadithNumber, lang: lang);
    if (!mounted) return;
    final chain = imported.isNotEmpty
        ? imported.map((e) => '${e['display_name'] ?? e['name_ar'] ?? ''}').where((e) => e.isNotEmpty).toList()
        : _raviChain();
    final isnad = _isnadText();
    final rtl = _lang == 'ur';
    final primary = _primaryNarratorName();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Narrator · Hadith ${widget.hadithNumber}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(
                    imported.isNotEmpty
                        ? 'Complete sanad imported from Arabic ibarat (verified). Never AI-generated.'
                        : 'Names come only from the authenticated hadith source. Never invented with AI.',
                    style: const TextStyle(fontSize: 12, color: Islam307Theme.textMuted, fontWeight: FontWeight.w600, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  if (primary.isNotEmpty) ...[
                    Text(primary, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, height: 1.4)),
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        final primaryId = imported.cast<Map<String, dynamic>?>().firstWhere(
                          (e) => e?['role'] == 'primary',
                          orElse: () => null,
                        )?['narrator_id'] as int?;
                        _openNarratorProfile(primary, primaryId);
                      },
                      child: const Text('More about this Narrator', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (chain.isEmpty && primary.isEmpty)
                    Text(
                      'Narrator is not available in the authenticated source for this hadith.',
                      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                    )
                  else if (chain.isNotEmpty) ...[
                    Text(
                      imported.isNotEmpty ? 'Isnad chain (Arabic ibarat order)' : 'Isnad chain (authenticated)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Islam307Theme.textMuted),
                    ),
                    const SizedBox(height: 10),
                    for (var i = 0; i < chain.length; i++)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: i == chain.length - 1 ? Islam307Theme.emeraldSoft : null,
                          border: Border.all(color: i == chain.length - 1 ? Islam307Theme.emerald : Islam307Theme.cardBorder),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: Islam307Theme.emerald,
                              child: Text(
                                '${imported.isNotEmpty ? (imported[i]['isnad_position'] ?? (i + 1)) : (i + 1)}',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    chain[i],
                                    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                                    style: const TextStyle(fontWeight: FontWeight.w700, height: 1.45, fontSize: 15),
                                  ),
                                  if (imported.isNotEmpty) ...[
                                    Text(
                                      [
                                        if ('${imported[i]['kunyah'] ?? ''}'.trim().isNotEmpty) 'كنية: ${imported[i]['kunyah']}',
                                        if ('${imported[i]['role'] ?? ''}'.trim().isNotEmpty) '${imported[i]['role']}',
                                      ].where((e) => e.isNotEmpty).join(' · '),
                                      style: const TextStyle(fontSize: 12, color: Islam307Theme.textMuted, height: 1.35),
                                    ),
                                  ],
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      final id = imported.isNotEmpty ? imported[i]['narrator_id'] as int? : null;
                                      _openNarratorProfile(chain[i], id);
                                    },
                                    child: const Text('More about this Narrator', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  if (isnad.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Isnad text', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Islam307Theme.textMuted)),
                    const SizedBox(height: 8),
                    Text(isnad, textDirection: rtl ? TextDirection.rtl : TextDirection.ltr, style: const TextStyle(height: 1.55)),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _bookmarkKey(int bookId, int n) => 'hadith_bm_${bookId}_$n';

  String _translation() {
    final h = _hadith;
    if (h == null) return '';
    if (_lang == 'en') return (h['text_en'] as String?) ?? '';
    if (_lang == 'hi') return (h['text_hi'] as String?) ?? (h['text_hindi'] as String?) ?? '';
    return (h['text_ur'] as String?) ?? '';
  }

  String _ttsLangCode(String lang) {
    if (lang == 'ur') return 'ur-PK';
    if (lang == 'ar') return 'ar-SA';
    if (lang == 'hi') return 'hi-IN';
    /* Prefer South-Asian English clarity over fast British/US female defaults. */
    return 'en-IN';
  }

  Future<void> _persistLang() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('i307_hadith_lang', _lang);
    await prefs.setString('i307_hadith_audio_mode', _audioMode);
    await prefs.setDouble('i307_hadith_rate', _speechRate);
  }

  Future<void> _playAudio({bool replay = false}) async {
    final h = _hadith;
    if (h == null) return;
    if (_paused && !replay) {
      // Device TTS often cannot resume; restart current track.
      _paused = false;
    }
    final ibarat = ((h['text_ar'] as String?) ?? '').trim();
    final translation = _translation().trim();
    final text = _audioMode == 'translation' ? translation : ibarat;
    final voiceLang = _audioMode == 'translation' ? _lang : 'ar';
    if (text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No authentic reference found.')),
      );
      return;
    }
    setState(() {
      _speaking = true;
      _paused = false;
    });
    try {
      final ok = await TtsService.instance.speakOffline(
        text,
        language: _ttsLangCode(voiceLang),
        rateMultiplier: _speechRate,
      );
      if (!ok && mounted) {
        await TtsService.instance.showInstallVoiceGuide(context, _ttsLangCode(voiceLang));
      }
    } finally {
      if (mounted) {
        setState(() {
          _speaking = false;
          _paused = false;
        });
      }
    }
  }

  Future<void> _pauseAudio() async {
    await TtsService.instance.pause();
    if (mounted) {
      setState(() {
        _paused = true;
        _speaking = false;
      });
    }
  }

  Future<void> _stopAudio() async {
    await TtsService.instance.stop();
    if (mounted) {
      setState(() {
        _speaking = false;
        _paused = false;
      });
    }
  }

  void _goTo(int number) {
    final chapter = widget.chapterId ?? _hadith?['chapter_id'];
    final q = chapter == null ? '' : '?chapterId=$chapter';
    context.replace('/hadith/read/${widget.bookId}/$number$q');
  }

  Future<void> _toggleBookmark() async {
    final prefs = await SharedPreferences.getInstance();
    final key = _bookmarkKey(widget.bookId, widget.hadithNumber);
    final next = !_bookmarked;
    await prefs.setBool(key, next);
    if (!mounted) return;
    setState(() => _bookmarked = next);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(next ? 'Bookmarked' : 'Bookmark removed')),
    );
  }

  Future<void> _editNote() async {
    final controller = TextEditingController(text: _note);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Note · Hadith ${widget.hadithNumber}'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(hintText: 'Personal note (offline)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Save')),
        ],
      ),
    );
    if (result == null) return;
    final prefs = await SharedPreferences.getInstance();
    final key = '${_bookmarkKey(widget.bookId, widget.hadithNumber)}_note';
    final trimmed = result.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, trimmed);
    }
    if (!mounted) return;
    setState(() => _note = trimmed);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note saved')));
  }

  String _copyShareText() {
    final h = _hadith;
    if (h == null) return '';
    return [
      '${h['book_name'] ?? 'Hadith'} · Hadith ${widget.hadithNumber}',
      h['kitab'] ?? '',
      h['text_ar'] ?? '',
      _translation(),
      h['reference'] ?? '',
    ].where((e) => '$e'.trim().isNotEmpty).join('\n\n');
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _copyShareText()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
  }

  Future<void> _share() async {
    final text = _copyShareText();
    await Share.share(text, subject: 'Hadith ${widget.hadithNumber}');
  }

  void _openReferenceSheet() {
    final h = _hadith;
    if (h == null) return;
    final grading = HadithRepository.gradingSummary(h);
    final rows = <(String, String)>[
      ('Book', h['book_name']?.toString() ?? ''),
      ('Chapter', h['kitab']?.toString() ?? h['chapter']?.toString() ?? ''),
      ('Hadith Number', '${widget.hadithNumber}'),
      ('Grade', grading.grade),
      ('Reference URL', h['reference_url']?.toString() ?? ''),
      ('Source Provider', h['source_provider']?.toString() ?? ''),
    ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFF111827),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reference · Hadith ${widget.hadithNumber}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      border: Border.all(color: const Color(0xFF334155)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < rows.length; i++)
                          Container(
                            decoration: BoxDecoration(
                              border: i == rows.length - 1 ? null : const Border(bottom: BorderSide(color: Color(0xFF334155))),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 120,
                                  child: Text(rows[i].$1, style: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w700)),
                                ),
                                Container(width: 1, height: 22, color: const Color(0xFF334155)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    rows[i].$2.isEmpty ? '—' : rows[i].$2,
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<String> _raviChain() {
    final h = _hadith;
    if (h == null) return const [];
    final byLang = h['ravi_by_lang'];
    final langKey = _lang == 'hi' ? 'en' : _lang;
    if (byLang is Map && byLang[langKey] is List) {
      return (byLang[langKey] as List).map((e) => '$e').where((e) => e.isNotEmpty).toList();
    }
    return (h['ravi_chain'] as List?)?.map((e) => '$e').toList() ?? const [];
  }

  String _isnadText() {
    final h = _hadith;
    if (h == null) return '';
    final byLang = h['isnad_by_lang'];
    final langKey = _lang == 'hi' ? 'en' : _lang;
    if (byLang is Map && byLang[langKey] != null) {
      return '${byLang[langKey]}'.trim();
    }
    if (_lang == 'ur') return (h['isnad_ur'] as String?)?.trim() ?? '';
    return (h['isnad'] as String?)?.trim() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final h = _hadith;
    final translation = _translation();
    final rtl = _lang == 'ur' || _lang == 'hi';
    final total = _numbers.isNotEmpty ? _numbers.length : 1;
    final pos = _numbers.isNotEmpty ? (_index + 1) : 1;
    final progress = pos / total;
    final bookName = h?['book_name']?.toString() ?? 'Hadith';
    final kitab = h?['kitab']?.toString() ?? '';

    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Islam307Theme.emerald))
            : h == null
                ? const Center(child: Text('Authentic hadith not found in offline database.'))
                : GestureDetector(
                    onHorizontalDragEnd: (details) {
                      final v = details.primaryVelocity ?? 0;
                      if (v < -400 && _nextNumber != null) {
                        _stopAudio();
                        _goTo(_nextNumber!);
                      } else if (v > 400 && _prevNumber != null) {
                        _stopAudio();
                        _goTo(_prevNumber!);
                      }
                    },
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                                onPressed: () => context.pop(),
                              ),
                              const Spacer(),
                              IconButton(
                                tooltip: 'Bookmark',
                                onPressed: _toggleBookmark,
                                icon: Icon(_bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
                              ),
                              IconButton(tooltip: 'Share', onPressed: _share, icon: const Icon(Icons.ios_share_rounded)),
                              IconButton(
                                tooltip: 'Search',
                                onPressed: () => context.push('/search'),
                                icon: const Icon(Icons.search_rounded),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            controller: _scroll,
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            children: [
                              Text(
                                bookName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.04,
                                  color: Islam307Theme.textMuted,
                                ),
                              ),
                              if (kitab.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  kitab,
                                  textAlign: TextAlign.right,
                                  textDirection: TextDirection.rtl,
                                  style: Islam307Theme.arabic(size: 26, weight: FontWeight.w700, color: Islam307Theme.emeraldDeep, height: 1.55),
                                ),
                              ],
                              const SizedBox(height: 6),
                              Text(
                                'Hadith $pos of $total',
                                style: const TextStyle(fontWeight: FontWeight.w800, color: Islam307Theme.emerald, fontSize: 13),
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 6,
                                  backgroundColor: const Color(0xFFE2E8F0),
                                  color: Islam307Theme.emerald,
                                ),
                              ),
                              const SizedBox(height: 22),
                              if (_hasAuthenticatedArabic(h['text_ar']))
                                Text(
                                  '${h['text_ar']}',
                                  textAlign: TextAlign.right,
                                  textDirection: TextDirection.rtl,
                                  style: Islam307Theme.arabic(size: 26, height: 2.15),
                                )
                              else
                                const Text('Arabic text unavailable in authenticated source.', style: TextStyle(color: Colors.orange)),
                              const SizedBox(height: 20),
                              InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Translation',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _lang,
                                    isExpanded: true,
                                    items: [
                                      for (final opt in _langOptions)
                                        DropdownMenuItem(value: opt.$1, child: Text(opt.$2, style: const TextStyle(fontWeight: FontWeight.w700))),
                                    ],
                                    onChanged: (v) async {
                                      if (v == null) return;
                                      await _stopAudio();
                                      setState(() => _lang = v);
                                      await _persistLang();
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              if (translation.isEmpty)
                                const Text('No authentic reference found.', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w700))
                              else
                                Text(
                                  translation,
                                  textAlign: rtl ? TextAlign.right : TextAlign.left,
                                  textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                                  style: _lang == 'ur'
                                      ? Islam307Theme.urdu(size: 18)
                                      : const TextStyle(height: 1.7, fontSize: 16, fontWeight: FontWeight.w600, color: Islam307Theme.textPrimary),
                                ),
                              const SizedBox(height: 18),
                              _audioBox(),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  FilledButton.tonal(onPressed: _openRaviSheet, child: const Text('Ravi')),
                                  FilledButton.tonal(onPressed: _openReferenceSheet, child: const Text('Reference')),
                                  FilledButton.tonal(onPressed: _copy, child: const Text('Copy')),
                                  FilledButton.tonal(onPressed: _share, child: const Text('Share')),
                                  FilledButton.tonal(onPressed: _toggleBookmark, child: Text(_bookmarked ? 'Bookmarked' : 'Bookmark')),
                                  FilledButton.tonal(onPressed: _editNote, child: Text(_note.isEmpty ? 'Notes' : 'Edit note')),
                                ],
                              ),
                              if (_note.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Islam307Theme.emeraldSoft,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(_note, style: const TextStyle(color: Islam307Theme.emeraldDeep, height: 1.45)),
                                ),
                              ],
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _prevNumber == null
                                          ? null
                                          : () {
                                              _stopAudio();
                                              _goTo(_prevNumber!);
                                            },
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size.fromHeight(52),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      ),
                                      child: const Text('◀ Previous Hadith', style: TextStyle(fontWeight: FontWeight.w800)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: _nextNumber == null
                                          ? null
                                          : () {
                                              _stopAudio();
                                              _goTo(_nextNumber!);
                                            },
                                      style: FilledButton.styleFrom(
                                        minimumSize: const Size.fromHeight(52),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      ),
                                      child: const Text('Next Hadith ▶', style: TextStyle(fontWeight: FontWeight.w800)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Swipe left / right to navigate · Offline',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 11, color: Islam307Theme.textMuted, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _audioBox() {
    final isTranslation = _audioMode == 'translation';
    final langHint = _lang == 'ur'
        ? 'Pakistani male Urdu'
        : (_lang == 'hi' ? 'Hindi male' : 'Pakistani/Indian male English · clear pace');
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFDF7), Colors.white],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Islam307Theme.goldLight),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Audio', style: TextStyle(fontWeight: FontWeight.w900, color: Islam307Theme.emeraldDeep)),
          const SizedBox(height: 4),
          Text(
            isTranslation
                ? 'Translation audio · $langHint'
                : 'Arabic audio · male KSA/Egyptian scholar voice · clear & slow',
            style: const TextStyle(fontSize: 12, color: Islam307Theme.textMuted, fontWeight: FontWeight.w600, height: 1.35),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                _audioModeChip('ibarat', 'Arabic Audio'),
                _audioModeChip('translation', 'Translation Audio'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: _speaking ? null : () => _playAudio(),
                style: FilledButton.styleFrom(
                  backgroundColor: Islam307Theme.emerald,
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                child: Text(_paused ? '▶ Resume' : '▶ Play', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              ),
              OutlinedButton(
                onPressed: _pauseAudio,
                style: OutlinedButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                child: const Text('Pause', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              ),
              OutlinedButton(
                onPressed: _stopAudio,
                style: OutlinedButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                child: const Text('Stop', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              ),
              OutlinedButton(
                onPressed: () => _playAudio(replay: true),
                style: OutlinedButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                child: const Text('Replay', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Speed', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Islam307Theme.textMuted)),
              for (final r in _rates)
                ChoiceChip(
                  label: Text('${r}×'),
                  selected: _speechRate == r,
                  onSelected: (_) async {
                    await _stopAudio();
                    setState(() => _speechRate = r);
                    await _persistLang();
                    await TtsService.instance.setRateMultiplier(r);
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Offline device TTS · prefers male scholar voices when installed',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Islam307Theme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _audioModeChip(String mode, String label) {
    final active = _audioMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          if (_audioMode == mode) return;
          await _stopAudio();
          setState(() => _audioMode = mode);
          await _persistLang();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: active ? Border.all(color: Islam307Theme.goldLight) : null,
            boxShadow: active
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 2))]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: active ? Islam307Theme.emeraldDeep : Islam307Theme.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
