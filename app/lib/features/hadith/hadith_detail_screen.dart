import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/audio/tts_service.dart';
import '../../core/database/database_registry.dart';
import '../../core/repositories/hadith_repository.dart';
import '../../core/theme/islam307_theme.dart';

class HadithDetailScreen extends StatefulWidget {
  const HadithDetailScreen({super.key, required this.bookId, required this.hadithNumber});
  final int bookId;
  final int hadithNumber;

  @override
  State<HadithDetailScreen> createState() => _HadithDetailScreenState();
}

class _HadithDetailScreenState extends State<HadithDetailScreen> {
  final _repo = HadithRepository(DatabaseRegistry.instance);
  Map<String, dynamic>? _hadith;
  bool _loading = true;
  String _lang = 'ur'; // ur | en | ar
  String _audioMode = 'ibarat'; // ibarat | translation
  bool _speaking = false;

  static const _langOptions = [
    ('ur', 'Urdu'),
    ('en', 'English'),
    ('ar', 'Arabic'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final row = await _repo.hadith(widget.bookId, widget.hadithNumber);
    if (!mounted) return;
    setState(() {
      _hadith = row;
      _loading = false;
    });
  }

  String _translation() {
    final h = _hadith;
    if (h == null) return '';
    if (_lang == 'en') return (h['text_en'] as String?) ?? '';
    if (_lang == 'ar') return (h['text_ar'] as String?) ?? '';
    return (h['text_ur'] as String?) ?? '';
  }

  String _ttsLangCode(String lang) {
    if (lang == 'ur') return 'ur-PK';
    if (lang == 'ar') return 'ar-SA';
    return 'en-US';
  }

  Future<void> _playAudio() async {
    final h = _hadith;
    if (h == null) return;
    final ibarat = ((h['text_ar'] as String?) ?? '').trim();
    final translation = _translation().trim();
    final text = _audioMode == 'translation' ? translation : ibarat;
    final voiceLang = _audioMode == 'translation' ? _lang : 'ar';
    if (text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No authenticated text available for this audio mode.')),
      );
      return;
    }
    setState(() => _speaking = true);
    try {
      await TtsService.instance.speak(text, language: _ttsLangCode(voiceLang));
    } finally {
      if (mounted) setState(() => _speaking = false);
    }
  }

  Future<void> _stopAudio() async {
    await TtsService.instance.stop();
    if (mounted) setState(() => _speaking = false);
  }

  Map<String, String> _audioCopy() {
    switch (_lang) {
      case 'ur':
        return {
          'title': 'آڈیو',
          'ibarat': 'عبارت',
          'translation': 'ترجمہ',
          'hint': _audioMode == 'ibarat' ? 'ہمیشہ عربی · اصل حدیث کا متن' : 'منتخب زبان میں بولے گا · اردو',
          'play': 'چلائیں',
          'stop': 'روکیں',
        };
      case 'ar':
        return {
          'title': 'الصوت',
          'ibarat': 'العبارة',
          'translation': 'الترجمة',
          'hint': _audioMode == 'ibarat' ? 'دائماً بالعربية · نص الحديث الأصلي' : 'يتحدث بلغة الترجمة المختارة · العربية',
          'play': 'تشغيل',
          'stop': 'إيقاف',
        };
      default:
        return {
          'title': 'Audio',
          'ibarat': 'Ibarat',
          'translation': 'Translation',
          'hint': _audioMode == 'ibarat'
              ? 'Always Arabic · original Hadith text'
              : 'Speaks the selected language · English',
          'play': 'Play',
          'stop': 'Stop',
        };
    }
  }

  Map<String, String> _raviCopy() {
    switch (_lang) {
      case 'ur':
        return {
          'title': 'راوی',
          'first': 'پہلا راوی',
          'mid': 'پچھلے سے روایت',
          'last': 'آخری راوی · نبی ﷺ سے',
          'empty': 'اس حدیث کی مکمل سند ماخذ میں دستیاب نہیں۔',
          'isnad': 'سند (مستند)',
        };
      case 'ar':
        return {
          'title': 'الرواة',
          'first': 'أول راوٍ',
          'mid': 'روى عن السابق',
          'last': 'آخر راوٍ · عن النبي ﷺ',
          'empty': 'سلسلة الرواة الكاملة غير متوفرة في الإسناد الموثق لهذا الحديث.',
          'isnad': 'الإسناد (موثق)',
        };
      default:
        return {
          'title': 'Ravi',
          'first': 'First narrator',
          'mid': 'Narrated from previous',
          'last': 'Last narrator · from the Prophet ﷺ',
          'empty': 'Full ravi chain is not available in the authenticated isnad for this hadith.',
          'isnad': 'Isnad (authenticated)',
        };
    }
  }

  List<String> _raviChain() {
    final h = _hadith;
    if (h == null) return const [];
    final byLang = h['ravi_by_lang'];
    if (byLang is Map && byLang[_lang] is List) {
      return (byLang[_lang] as List).map((e) => '$e').where((e) => e.isNotEmpty).toList();
    }
    return (h['ravi_chain'] as List?)?.map((e) => '$e').toList() ?? const [];
  }

  String _isnadText() {
    final h = _hadith;
    if (h == null) return '';
    final byLang = h['isnad_by_lang'];
    if (byLang is Map && byLang[_lang] != null) {
      return '${byLang[_lang]}'.trim();
    }
    if (_lang == 'ur') return (h['isnad_ur'] as String?)?.trim() ?? '';
    return (h['isnad'] as String?)?.trim() ?? '';
  }

  void _openRaviSheet() {
    final h = _hadith;
    if (h == null) return;
    final chain = _raviChain();
    final isnad = _isnadText();
    final t = _raviCopy();
    final rtl = _lang == 'ur' || _lang == 'ar';

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
                  Text('${t['title']} · Hadith ${widget.hadithNumber}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  if (chain.isEmpty)
                    Text(t['empty']!, textDirection: rtl ? TextDirection.rtl : TextDirection.ltr)
                  else
                    ...[
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
                                child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
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
                                    Text(
                                      i == 0 ? t['first']! : (i == chain.length - 1 ? t['last']! : t['mid']!),
                                      style: const TextStyle(fontSize: 11, color: Islam307Theme.textMuted, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  if (isnad.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(t['isnad']!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Islam307Theme.textMuted)),
                    const SizedBox(height: 8),
                    Text(
                      isnad,
                      textAlign: rtl ? TextAlign.right : TextAlign.left,
                      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                      style: _lang == 'ar'
                          ? Islam307Theme.arabic(size: 18)
                          : (_lang == 'ur' ? Islam307Theme.urdu().copyWith(color: const Color(0xFF1D4ED8)) : const TextStyle(height: 1.5)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openReferenceSheet() {
    final h = _hadith;
    if (h == null) return;
    final detail = h['reference_detail'];
    List<(String, String)> rows = [];
    if (detail is Map && detail['by_lang'] is Map && (detail['by_lang'] as Map)[_lang] is Map) {
      final localized = Map<String, dynamic>.from((detail['by_lang'] as Map)[_lang] as Map);
      final rawRows = localized['rows'];
      if (rawRows is List) {
        for (final row in rawRows) {
          if (row is List && row.length >= 2) {
            rows.add(('${row[0]}', '${row[1]}'));
          }
        }
      }
    }
    if (rows.isEmpty) {
      final d = Map<String, String>.from((detail as Map?)?.map((k, v) => MapEntry('$k', '$v')) ?? {});
      rows = [
        ('Kitab', d['kitab'] ?? h['kitab']?.toString() ?? ''),
        ('Baab', d['baab'] ?? h['kitab']?.toString() ?? ''),
        ('Volume', d['volume'] ?? ''),
        ('English Kitab', d['english_kitab'] ?? ''),
        ('English Name', d['english_name'] ?? h['book_name']?.toString() ?? ''),
        ('Takhreej', d['takhreej'] ?? ''),
        ('Status', d['status'] ?? ''),
        ('Wazahat', d['wazahat'] ?? ''),
      ];
    }

    final title = {'en': 'Reference', 'ur': 'حوالہ', 'ar': 'المرجع'}[_lang] ?? 'Reference';

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
                  Text('$title · Hadith ${widget.hadithNumber}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
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
                                    rows[i].$2,
                                    textAlign: TextAlign.right,
                                    textDirection: TextDirection.rtl,
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

  @override
  Widget build(BuildContext context) {
    final h = _hadith;
    final translation = _translation();
    final rtl = _lang == 'ur' || _lang == 'ar';
    final raviLabel = {'en': 'Ravi', 'ur': 'راوی', 'ar': 'الرواة'}[_lang]!;
    final refLabel = {'en': 'Reference', 'ur': 'حوالہ', 'ar': 'المرجع'}[_lang]!;

    return Scaffold(
      appBar: AppBar(
        title: Text('Hadith ${widget.hadithNumber}', style: const TextStyle(fontWeight: FontWeight.w800)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => context.pop()),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Islam307Theme.emerald))
          : h == null
              ? const Center(child: Text('Authentic hadith not found in offline database.'))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonal(onPressed: _openRaviSheet, child: Text(raviLabel)),
                        FilledButton.tonal(onPressed: _openReferenceSheet, child: Text(refLabel)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Language',
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
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _audioBox(),
                    const SizedBox(height: 16),
                    if ((h['text_ar'] as String?)?.isNotEmpty == true)
                      Text('${h['text_ar']}', textAlign: TextAlign.right, style: Islam307Theme.arabic(size: 22))
                    else
                      const Text('Arabic text unavailable in authenticated source.', style: TextStyle(color: Colors.orange)),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    if (translation.isEmpty)
                      Text(
                        '${_lang.toUpperCase()} translation unavailable in authenticated source.',
                        style: const TextStyle(color: Colors.orange),
                      )
                    else
                      Text(
                        translation,
                        textAlign: rtl ? TextAlign.right : TextAlign.left,
                        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                        style: _lang == 'ar'
                            ? Islam307Theme.arabic(size: 20)
                            : (_lang == 'ur' ? Islam307Theme.urdu() : const TextStyle(height: 1.6, color: Islam307Theme.textMuted)),
                      ),
                  ],
                ),
    );
  }

  Widget _audioBox() {
    final copy = _audioCopy();
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
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(copy['title']!, style: const TextStyle(fontWeight: FontWeight.w900, color: Islam307Theme.emeraldDeep)),
                    const SizedBox(height: 4),
                    Text(copy['hint']!, style: const TextStyle(fontSize: 12, color: Islam307Theme.textMuted, fontWeight: FontWeight.w600, height: 1.35)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _speaking ? null : _playAudio,
                style: FilledButton.styleFrom(
                  backgroundColor: Islam307Theme.emerald,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                child: Text(copy['play']!, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: _stopAudio,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Islam307Theme.emeraldDeep,
                  side: const BorderSide(color: Islam307Theme.cardBorder),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                child: Text(copy['stop']!, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ],
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
                _audioModeChip('ibarat', copy['ibarat']!),
                _audioModeChip('translation', copy['translation']!),
              ],
            ),
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
