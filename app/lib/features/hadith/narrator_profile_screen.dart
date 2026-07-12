import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/database/database_registry.dart';
import '../../core/repositories/narrator_repository.dart';
import '../../core/theme/islam307_theme.dart';

/// Standard Narrator Detail page — exact RTL table template.
///
/// Fixed Urdu field labels on the right; values on the left.
/// Empty cells stay empty until authenticated data is imported.
/// Never invents biography content with AI.
class NarratorProfileScreen extends StatefulWidget {
  const NarratorProfileScreen({
    super.key,
    this.narratorId,
    this.slug,
    this.displayName,
    this.bookSlug,
    this.hadithNumber,
    this.lang = 'en',
  });

  final int? narratorId;
  final String? slug;
  final String? displayName;
  final String? bookSlug;
  final int? hadithNumber;
  final String lang;

  /// Fixed field labels matching the standard راوی معلومات template.
  static const fieldLabels = <String>[
    'راوی آئی ڈی',
    'پورا نام (عربی)',
    'پورا نام (اردو)',
    'کنیت',
    'لقب',
    'نسب / نسبت',
    'قبیلہ',
    'ولادت (ہجری)',
    'وفات (ہجری)',
    'ولادت کا مقام',
    'وفات کا مقام',
    'حالت',
    'طبقہ (دور)',
    'شغل',
    'وثاقت',
    'مشہور کیوں ہیں',
    'اہم اساتذہ',
    'اہم شاگرد',
    'اہم کتب',
    'اضافی نوٹس',
  ];

  @override
  State<NarratorProfileScreen> createState() => _NarratorProfileScreenState();
}

class _NarratorProfileScreenState extends State<NarratorProfileScreen> {
  final _repo = NarratorRepository(DatabaseRegistry.instance);
  Map<String, dynamic>? _profile;
  bool _loading = true;

  static const _border = Color(0xFFE0E0E0);
  static const _headerBg = Color(0xFFF0F4F8);
  static const _labelColor = Color(0xFF1E293B);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    Map<String, dynamic> result;
    if (widget.narratorId != null) {
      result = await _repo.profileById(widget.narratorId!, lang: widget.lang);
    } else if (widget.slug != null && widget.slug!.trim().isNotEmpty) {
      result = await _repo.profileBySlug(widget.slug!, lang: widget.lang);
    } else {
      result = await _repo.lookup(
        widget.displayName ?? '',
        lang: widget.lang,
        bookSlug: widget.bookSlug,
        hadithNumber: widget.hadithNumber,
      );
    }
    if (!mounted) return;
    setState(() {
      _profile = result;
      _loading = false;
    });
  }

  List<String> _valuesFor(Map<String, dynamic>? p) {
    final imported = p?['imported'] == true;
    if (!imported || p == null) {
      // Structure only — leave values empty until authenticated import fills them.
      // Narrator ID may still show when opened via a known imported id lookup miss.
      final id = widget.narratorId;
      return [
        id != null ? '$id' : '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
      ];
    }

    String joinPeople(List? rows, List<String> keys) {
      if (rows == null || rows.isEmpty) return '';
      final out = <String>[];
      for (final raw in rows) {
        final m = Map<String, dynamic>.from(raw as Map);
        for (final k in keys) {
          final v = '${m[k] ?? ''}'.trim();
          if (v.isNotEmpty) {
            out.add(v);
            break;
          }
        }
      }
      return out.join('\n');
    }

    String joinReliability(List? rows) {
      if (rows == null || rows.isEmpty) return '';
      final out = <String>[];
      for (final raw in rows) {
        final m = Map<String, dynamic>.from(raw as Map);
        final ruling = [
          '${m['ruling_ur'] ?? ''}'.trim(),
          '${m['ruling_ar'] ?? ''}'.trim(),
          '${m['ruling_en'] ?? ''}'.trim(),
        ].firstWhere((e) => e.isNotEmpty, orElse: () => '');
        final source = '${m['source_name'] ?? ''}'.trim();
        if (ruling.isEmpty && source.isEmpty) continue;
        out.add(source.isEmpty ? ruling : '$ruling ($source)');
      }
      return out.join('\n');
    }

    String joinBooks(List? rows) {
      if (rows == null || rows.isEmpty) return '';
      return rows
          .map((raw) {
            final m = Map<String, dynamic>.from(raw as Map);
            return '${m['source_name'] ?? m['source_name_ar'] ?? ''}'.trim();
          })
          .where((e) => e.isNotEmpty)
          .join('\n');
    }

    String status() {
      if (p['is_companion'] == true) return 'صحابی';
      if (p['is_tabii'] == true) return 'تابعی';
      if (p['is_tab_tabii'] == true) return 'تبع تابعین';
      return '';
    }

    final birthHijri = '${p['birth_hijri'] ?? ''}'.trim().isNotEmpty
        ? '${p['birth_hijri']}'
        : '${p['birth_text'] ?? ''}'.trim();
    final deathHijri = '${p['death_hijri'] ?? ''}'.trim().isNotEmpty
        ? '${p['death_hijri']}'
        : '${p['death_text'] ?? ''}'.trim();

    return [
      '${p['id'] ?? ''}',
      () {
        final ar = '${p['name_ar'] ?? ''}'.trim();
        if (ar.isNotEmpty) return ar;
        final full = '${p['full_name'] ?? ''}'.trim();
        // Prefer Arabic full name when present; never invent.
        if (full.isNotEmpty && RegExp(r'[\u0600-\u06FF]').hasMatch(full)) return full;
        return '';
      }(),
      () {
        final ur = '${p['name_ur'] ?? ''}'.trim();
        if (ur.isNotEmpty) return ur;
        final full = '${p['full_name'] ?? ''}'.trim();
        if (full.isNotEmpty && RegExp(r'[\u0600-\u06FF]').hasMatch(full)) return full;
        // Authenticated English attribution from hadith pack (identity only).
        return '${p['name_en'] ?? ''}'.trim();
      }(),
      '${p['kunyah'] ?? ''}',
      '${p['laqab'] ?? ''}',
      '${p['nasab'] ?? ''}',
      '', // قبیلہ — empty until classical import
      birthHijri,
      deathHijri,
      '${p['city'] ?? ''}',
      '', // وفات کا مقام — empty until classical import
      status(),
      '${p['generation'] ?? ''}',
      '', // شغل — empty until classical import
      joinReliability(p['reliability'] as List?),
      '', // مشہور کیوں ہیں — empty until classical import
      joinPeople(p['teachers'] as List?, const ['teacher_name_ar', 'teacher_name_en']),
      joinPeople(p['students'] as List?, const ['student_name_ar', 'student_name_en']),
      joinBooks(p['books_mentioned'] as List?),
      '${p['timeline_notes'] ?? ''}',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final values = _valuesFor(_profile);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'راوی معلومات',
          style: Islam307Theme.urdu(size: 20, color: Islam307Theme.textPrimary).copyWith(fontWeight: FontWeight.w800),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Islam307Theme.emerald))
          : LayoutBuilder(
              builder: (context, constraints) {
                final pad = constraints.maxWidth > 720 ? 24.0 : 12.0;
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(pad, 12, pad, 28),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: _narratorTable(values),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _narratorTable(List<String> values) {
    final labels = NarratorProfileScreen.fieldLabels;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _border, width: 1),
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: _headerBg,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              alignment: Alignment.center,
              child: Text(
                'راوی معلومات',
                textAlign: TextAlign.center,
                style: Islam307Theme.urdu(size: 18, color: _labelColor).copyWith(fontWeight: FontWeight.w800, height: 1.6),
              ),
            ),
            for (var i = 0; i < labels.length; i++) ...[
              Container(height: 1, color: _border),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // In RTL this appears on the right (label column).
                    Expanded(
                      flex: 38,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        alignment: Alignment.centerRight,
                        decoration: const BoxDecoration(
                          border: Border(left: BorderSide(color: _border, width: 1)),
                        ),
                        child: Text(
                          labels[i],
                          textAlign: TextAlign.right,
                          style: Islam307Theme.urdu(size: 15, color: _labelColor).copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.7,
                          ),
                        ),
                      ),
                    ),
                    // In RTL this appears on the left (value column).
                    Expanded(
                      flex: 62,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        alignment: Alignment.centerRight,
                        color: Colors.white,
                        child: Text(
                          values[i].trim(),
                          textAlign: TextAlign.right,
                          style: Islam307Theme.urdu(size: 15, color: Islam307Theme.textPrimary).copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.7,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
