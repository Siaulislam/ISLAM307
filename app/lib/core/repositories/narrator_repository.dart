import '../database/database_registry.dart';
import '../modules/module_catalog.dart';

/// Narrator (Rijāl) Knowledge — authenticated classical sources only.
///
/// NEVER invent names, biographies, teachers, students, dates, or reliability.
/// NEVER assume a biography is "unavailable" in classical literature.
///
/// If a narrator row is not in the local `narrators.db` yet, return
/// [statusNotImported] so the UI can show an empty profile shell.
/// When authenticated datasets are imported later, the same APIs return
/// full profiles automatically — no UI rewrite required.
class NarratorRepository {
  NarratorRepository(this._registry, {ModuleCatalog? catalog})
      : _catalog = catalog ?? ModuleCatalog.instance;

  final DatabaseRegistry _registry;
  final ModuleCatalog _catalog;

  static const statusImported = 'imported';
  static const statusNotImported = 'not_imported';

  /// Shown only when this narrator has not been imported into local narrators.db yet.
  static const notImportedMessage =
      'This narrator profile has not been imported into the local database yet.';

  static const policyNeverInvent =
      'ISLAM 307 never generates narrator biographies with AI. '
      'Profiles appear only after authenticated narrator datasets are imported into narrators.db.';

  Future<Map<String, dynamic>> catalog() => _catalog.narratorSources();

  Future<List<Map<String, dynamic>>> approvedSources() async {
    final m = await catalog();
    return (m['approved_sources'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
  }

  Future<bool> isPackRegistered() async => _registry.isRegistered('narrators');

  Future<Map<String, String>> meta() async {
    if (!await isPackRegistered()) return const {};
    try {
      final db = await _registry.open('narrators');
      final rows = await db.query('meta');
      return {for (final r in rows) '${r['key']}': '${r['value']}'};
    } catch (_) {
      return const {};
    }
  }

  /// Resolve verified narrator ID for a hadith (mapping table only — never AI).
  Future<int?> narratorIdForHadith(String bookSlug, int hadithNumber) async {
    if (!await isPackRegistered()) return null;
    try {
      final db = await _registry.open('narrators');
      final rows = await db.query(
        'hadith_relations',
        columns: ['narrator_id'],
        where: "book_slug = ? AND hadith_number = ? AND role = 'primary'",
        whereArgs: [bookSlug, hadithNumber],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return rows.first['narrator_id'] as int?;
    } catch (_) {
      return null;
    }
  }

  /// Full authenticated sanad chain for a hadith (ordered by isnad_position).
  /// Returns empty list when no imported mapping exists — never invents names.
  Future<List<Map<String, dynamic>>> isnadChainForHadith(
    String bookSlug,
    int hadithNumber, {
    String lang = 'en',
  }) async {
    if (!await isPackRegistered()) return const [];
    try {
      final db = await _registry.open('narrators');
      final rows = await db.rawQuery(
        '''
        SELECT hr.isnad_position, hr.role, hr.narrator_id,
               n.slug, n.name_ar, n.name_ur, n.name_en, n.full_name,
               n.kunyah, n.laqab, n.nasab, n.generation,
               n.is_companion, n.is_tabii, n.is_tab_tabii
        FROM hadith_relations hr
        JOIN narrators n ON n.id = hr.narrator_id
        WHERE hr.book_slug = ? AND hr.hadith_number = ?
        ORDER BY hr.isnad_position ASC
        ''',
        [bookSlug, hadithNumber],
      );
      return rows.map((r) {
        final map = Map<String, dynamic>.from(r);
        map['display_name'] = _displayName(map, lang);
        map['is_companion'] = r['is_companion'] == 1;
        map['is_tabii'] = r['is_tabii'] == 1;
        map['is_tab_tabii'] = r['is_tab_tabii'] == 1;
        return map;
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<Map<String, dynamic>> profileById(int narratorId, {String lang = 'en'}) async {
    if (!await isPackRegistered()) {
      return _notImported(name: null);
    }
    try {
      final db = await _registry.open('narrators');
      final rows = await db.query('narrators', where: 'id = ?', whereArgs: [narratorId], limit: 1);
      if (rows.isEmpty) return _notImported(name: null);
      return _assembleProfile(Map<String, dynamic>.from(rows.first), lang: lang);
    } catch (_) {
      return _notImported(name: null);
    }
  }

  Future<Map<String, dynamic>> profileBySlug(String slug, {String lang = 'en'}) async {
    final clean = slug.trim();
    if (clean.isEmpty) return _notImported(name: null);
    if (!await isPackRegistered()) return _notImported(name: clean);
    try {
      final db = await _registry.open('narrators');
      final rows = await db.query('narrators', where: 'slug = ?', whereArgs: [clean], limit: 1);
      if (rows.isEmpty) return _notImported(name: clean);
      return _assembleProfile(Map<String, dynamic>.from(rows.first), lang: lang);
    } catch (_) {
      return _notImported(name: clean);
    }
  }

  /// Lookup by verified hadith mapping first, then exact alias match.
  /// Never invents a match. Missing local row → [statusNotImported].
  Future<Map<String, dynamic>> lookup(
    String displayName, {
    String lang = 'en',
    String? bookSlug,
    int? hadithNumber,
  }) async {
    final name = displayName.trim();

    if (bookSlug != null && hadithNumber != null) {
      final id = await narratorIdForHadith(bookSlug, hadithNumber);
      if (id != null) return profileById(id, lang: lang);
    }

    if (name.isEmpty) return _notImported(name: null);

    if (!await isPackRegistered()) return _notImported(name: name);

    try {
      final db = await _registry.open('narrators');
      final normalized = normalizeNarratorKey(name);
      final rows = await db.rawQuery(
        '''
        SELECT n.id
        FROM name_aliases a
        JOIN narrators n ON n.id = a.narrator_id
        WHERE a.alias_normalized = ?
        LIMIT 1
        ''',
        [normalized],
      );
      if (rows.isEmpty) return _notImported(name: name);
      return profileById(rows.first['id'] as int, lang: lang);
    } catch (_) {
      return _notImported(name: name);
    }
  }

  Future<Map<String, dynamic>> _assembleProfile(Map<String, dynamic> row, {required String lang}) async {
    final db = await _registry.open('narrators');
    final id = row['id'] as int;

    final teachers = await db.rawQuery(
      '''
      SELECT t.*, s.name_en AS source_name, s.name_ar AS source_name_ar, s.slug AS source_slug
      FROM teachers t JOIN sources s ON s.id = t.source_id
      WHERE t.narrator_id = ?
      ORDER BY s.sort_order, t.id
      ''',
      [id],
    );
    final students = await db.rawQuery(
      '''
      SELECT st.*, s.name_en AS source_name, s.name_ar AS source_name_ar, s.slug AS source_slug
      FROM students st JOIN sources s ON s.id = st.source_id
      WHERE st.narrator_id = ?
      ORDER BY s.sort_order, st.id
      ''',
      [id],
    );
    final reliability = await db.rawQuery(
      '''
      SELECT r.*, s.name_en AS source_name, s.name_ar AS source_name_ar, s.slug AS source_slug
      FROM reliability r JOIN sources s ON s.id = r.source_id
      WHERE r.narrator_id = ?
      ORDER BY s.sort_order, r.id
      ''',
      [id],
    );
    final cites = await db.rawQuery(
      '''
      SELECT c.*, s.name_en AS source_name, s.name_ar AS source_name_ar, s.slug AS source_slug
      FROM references_cite c JOIN sources s ON s.id = c.source_id
      WHERE c.narrator_id = ?
      ORDER BY s.sort_order, c.id
      ''',
      [id],
    );
    final books = await db.rawQuery(
      '''
      SELECT b.*, s.name_en AS source_name, s.name_ar AS source_name_ar, s.slug AS source_slug
      FROM books_mentioned b JOIN sources s ON s.id = b.source_id
      WHERE b.narrator_id = ?
      ORDER BY s.sort_order, b.id
      ''',
      [id],
    );
    final hadithCollections = await db.rawQuery(
      '''
      SELECT book_slug, COUNT(*) AS hadith_count
      FROM hadith_relations
      WHERE narrator_id = ?
      GROUP BY book_slug
      ORDER BY book_slug
      ''',
      [id],
    );

    // Row exists but no imported biography content yet → treat as not imported.
    if (!_hasIdentityContent(row) &&
        teachers.isEmpty &&
        students.isEmpty &&
        reliability.isEmpty &&
        cites.isEmpty &&
        books.isEmpty) {
      return _notImported(name: _displayName(row, lang));
    }

    return {
      'status': statusImported,
      'imported': true,
      'id': id,
      'slug': row['slug'],
      'name_ar': row['name_ar'],
      'name_ur': row['name_ur'],
      'name_en': row['name_en'],
      'full_name': row['full_name'],
      'kunyah': row['kunyah'],
      'laqab': row['laqab'],
      'nasab': row['nasab'],
      'birth_text': row['birth_text'],
      'death_text': row['death_text'],
      'birth_hijri': row['birth_hijri'],
      'death_hijri': row['death_hijri'],
      'city': row['city'],
      'country': row['country'],
      'generation': row['generation'],
      'is_companion': row['is_companion'] == 1,
      'is_tabii': row['is_tabii'] == 1,
      'is_tab_tabii': row['is_tab_tabii'] == 1,
      'timeline_notes': row['timeline_notes'],
      'display_name': _displayName(row, lang),
      'teachers': teachers,
      'students': students,
      'reliability': reliability,
      'references': cites,
      'books_mentioned': books,
      'hadith_collections': hadithCollections,
      'policy': policyNeverInvent,
    };
  }

  bool _hasIdentityContent(Map<String, dynamic> row) {
    for (final key in [
      'name_ar',
      'name_ur',
      'name_en',
      'full_name',
      'kunyah',
      'laqab',
      'nasab',
      'birth_text',
      'death_text',
      'city',
      'country',
      'generation',
      'timeline_notes',
    ]) {
      if ('${row[key] ?? ''}'.trim().isNotEmpty) return true;
    }
    return row['is_companion'] == 1 || row['is_tabii'] == 1 || row['is_tab_tabii'] == 1;
  }

  String? _displayName(Map<String, dynamic> row, String lang) {
    if (lang == 'ar') {
      final ar = (row['name_ar'] as String?)?.trim();
      if (ar != null && ar.isNotEmpty) return ar;
    }
    if (lang == 'ur') {
      final ur = (row['name_ur'] as String?)?.trim();
      if (ur != null && ur.isNotEmpty) return ur;
    }
    final en = (row['name_en'] as String?)?.trim();
    if (en != null && en.isNotEmpty) return en;
    final full = (row['full_name'] as String?)?.trim();
    if (full != null && full.isNotEmpty) return full;
    return (row['name_ar'] as String?)?.trim();
  }

  Map<String, dynamic> _notImported({required String? name}) {
    return {
      'status': statusNotImported,
      'imported': false,
      'message': notImportedMessage,
      'name': name,
      'display_name': name,
      // Empty profile shell — fields fill automatically after import.
      'name_ar': null,
      'name_ur': null,
      'name_en': null,
      'full_name': null,
      'kunyah': null,
      'laqab': null,
      'nasab': null,
      'birth_text': null,
      'death_text': null,
      'city': null,
      'country': null,
      'generation': null,
      'is_companion': false,
      'is_tabii': false,
      'is_tab_tabii': false,
      'timeline_notes': null,
      'teachers': const <Map<String, dynamic>>[],
      'students': const <Map<String, dynamic>>[],
      'reliability': const <Map<String, dynamic>>[],
      'references': const <Map<String, dynamic>>[],
      'books_mentioned': const <Map<String, dynamic>>[],
      'hadith_collections': const <Map<String, dynamic>>[],
      'policy': policyNeverInvent,
    };
  }

  /// Fold display names for alias matching — does not invent content.
  static String normalizeNarratorKey(String raw) {
    var s = raw.trim().toLowerCase();
    s = s.replaceAll(RegExp(r"[ʼ'`´]"), "'");
    s = s.replaceAll(RegExp(r'[^\w\u0600-\u06ff\s-]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }
}
