import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/database/database_registry.dart';
import '../../core/repositories/narrator_repository.dart';
import '../../core/theme/islam307_theme.dart';

/// Narrator (Rijāl) profile shell.
///
/// Empty until an authenticated narrator dataset is imported into narrators.db.
/// The same screen fills automatically when rows exist — no UI rewrite required.
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

  @override
  State<NarratorProfileScreen> createState() => _NarratorProfileScreenState();
}

class _NarratorProfileScreenState extends State<NarratorProfileScreen> {
  final _repo = NarratorRepository(DatabaseRegistry.instance);
  Map<String, dynamic>? _profile;
  bool _loading = true;

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

  bool get _imported => _profile?['imported'] == true;

  @override
  Widget build(BuildContext context) {
    final authenticatedName = (widget.displayName ?? '').trim();
    final title = authenticatedName.isNotEmpty
        ? authenticatedName
        : ((_profile?['display_name'] as String?)?.trim().isNotEmpty == true
            ? _profile!['display_name'] as String
            : 'Narrator');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Narrator Profile', style: TextStyle(fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Islam307Theme.emerald))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, height: 1.35)),
                const SizedBox(height: 8),
                const Text(
                  'Narrator (Rijāl) · Authenticated imports only · Never AI-generated',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Islam307Theme.textMuted, height: 1.4),
                ),
                const SizedBox(height: 18),
                if (!_imported) ...[
                  _notImportedBanner(),
                  const SizedBox(height: 20),
                  // Empty profile architecture — same sections fill after import.
                  _emptyProfileShell(),
                ] else
                  ..._profileSections(_profile!),
                const SizedBox(height: 20),
                Text(
                  NarratorRepository.policyNeverInvent,
                  style: const TextStyle(fontSize: 11, color: Islam307Theme.textMuted, height: 1.4, fontWeight: FontWeight.w600),
                ),
              ],
            ),
    );
  }

  Widget _notImportedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Islam307Theme.cardBorder),
        color: Islam307Theme.fieldFill,
      ),
      child: const Text(
        NarratorRepository.notImportedMessage,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.45),
      ),
    );
  }

  /// Empty field scaffolding — remains blank until narrators.db import fills rows.
  Widget _emptyProfileShell() {
    const labels = [
      'Arabic Name',
      'Urdu Name',
      'English Name',
      'Full Name',
      'Kunyah',
      'Laqab',
      'Nasab',
      'Birth',
      'Death',
      'City',
      'Country',
      'Generation',
      'Companion',
      "Tabi'i",
      "Tabi' al-Tabi'in",
      'Teachers',
      'Students',
      'Reliability',
      'Jarḥ wa Taʿdīl',
      'Books where biography appears',
      'Hadith Collections narrated in',
      'Timeline',
      'References',
    ];
    return Column(
      children: [
        for (final label in labels)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Islam307Theme.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.04, color: Islam307Theme.textMuted),
                  ),
                  const SizedBox(height: 6),
                  const Text('—', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Islam307Theme.textMuted)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _profileSections(Map<String, dynamic> p) {
    return [
      _field('Arabic Name', p['name_ar']),
      _field('Urdu Name', p['name_ur']),
      _field('English Name', p['name_en']),
      _field('Full Name', p['full_name']),
      _field('Kunyah', p['kunyah']),
      _field('Laqab', p['laqab']),
      _field('Nasab', p['nasab']),
      _field('Birth', p['birth_text'] ?? p['birth_hijri']),
      _field('Death', p['death_text'] ?? p['death_hijri']),
      _field('City', p['city']),
      _field('Country', p['country']),
      _field('Generation', p['generation']),
      _boolField('Companion', p['is_companion'] == true),
      _boolField("Tabi'i", p['is_tabii'] == true),
      _boolField("Tabi' al-Tabi'in", p['is_tab_tabii'] == true),
      _field('Timeline', p['timeline_notes']),
      const SizedBox(height: 8),
      _opinionList('Teachers', p['teachers'] as List? ?? const [], nameKeys: const ['teacher_name_ar', 'teacher_name_en']),
      _opinionList('Students', p['students'] as List? ?? const [], nameKeys: const ['student_name_ar', 'student_name_en']),
      _opinionList('Reliability / Jarḥ wa Taʿdīl', p['reliability'] as List? ?? const [], nameKeys: const ['ruling_ar', 'ruling_en', 'ruling_ur']),
      _opinionList('Books where biography appears', p['books_mentioned'] as List? ?? const [], nameKeys: const ['source_name']),
      _opinionList('References', p['references'] as List? ?? const [], nameKeys: const ['text_ar', 'text_en', 'text_ur']),
      _hadithCollections(p['hadith_collections'] as List? ?? const []),
    ];
  }

  Widget _field(String label, Object? value) {
    final text = '${value ?? ''}'.trim();
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.04, color: Islam307Theme.textMuted)),
          const SizedBox(height: 4),
          Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.4)),
        ],
      ),
    );
  }

  Widget _boolField(String label, bool value) {
    if (!value) return const SizedBox.shrink();
    return _field(label, 'Yes');
  }

  Widget _opinionList(String title, List rows, {required List<String> nameKeys}) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Islam307Theme.emeraldDeep)),
          const SizedBox(height: 4),
          const Text(
            'Each opinion shown separately with its source — never merged.',
            style: TextStyle(fontSize: 11, color: Islam307Theme.textMuted, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          for (final raw in rows)
            _opinionCard(Map<String, dynamic>.from(raw as Map), nameKeys: nameKeys),
        ],
      ),
    );
  }

  Widget _opinionCard(Map<String, dynamic> row, {required List<String> nameKeys}) {
    String body = '';
    for (final k in nameKeys) {
      final v = '${row[k] ?? ''}'.trim();
      if (v.isNotEmpty) {
        body = v;
        break;
      }
    }
    if (body.isEmpty) {
      body = '${row['verbatim_en'] ?? row['verbatim_ar'] ?? row['notes'] ?? ''}'.trim();
    }
    final source = '${row['source_name'] ?? ''}'.trim();
    final cite = [
      if ('${row['volume'] ?? ''}'.trim().isNotEmpty) 'Vol. ${row['volume']}',
      if ('${row['page'] ?? ''}'.trim().isNotEmpty) 'p. ${row['page']}',
      if ('${row['entry_number'] ?? ''}'.trim().isNotEmpty) '§${row['entry_number']}',
    ].join(' · ');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Islam307Theme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (body.isNotEmpty) Text(body, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.45)),
          if (source.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Source Book: $source', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep)),
          ],
          if (cite.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(cite, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Islam307Theme.textMuted)),
          ],
        ],
      ),
    );
  }

  Widget _hadithCollections(List rows) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Hadith Collections narrated in', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Islam307Theme.emeraldDeep)),
          const SizedBox(height: 8),
          for (final raw in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${(raw as Map)['book_slug']} · ${(raw)['hadith_count']} hadith (verified mapping)',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}
