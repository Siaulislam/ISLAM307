import '../database/database_registry.dart';
import '../modules/module_catalog.dart';

/// Narrator (Rijāl) Knowledge — authenticated classical sources only.
///
/// NEVER invent names, biographies, teachers, students, dates, or reliability.
/// NEVER use AI, Wikipedia, blogs, forums, or unapproved websites.
///
/// Primary hadith narrator *display names* still come from [HadithRepository]
/// (authenticated hadith pack). Full profiles and hadith→narrator IDs come only
/// from licensed imports into `narrators.db`.
class NarratorRepository {
  NarratorRepository(this._registry, {ModuleCatalog? catalog})
      : _catalog = catalog ?? ModuleCatalog.instance;

  final DatabaseRegistry _registry;
  final ModuleCatalog _catalog;

  /// Exact product copy when verified rijāl data is absent.
  static const verifiedUnavailableMessage = 'Verified narrator biography is not available.';

  static const policyNeverInvent =
      'ISLAM 307 never generates narrator biographies with AI. '
      'Only approved classical Sunni references are used, and only with license/permission. '
      'Opinions from different books are never merged.';

  @Deprecated('Use verifiedUnavailableMessage')
  static const offlineUnavailableMessage = verifiedUnavailableMessage;

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

  Future<bool> hasBiographyRows() async {
    final m = await meta();
    return m['biography_rows'] != null && m['biography_rows'] != '0';
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

  /// Full profile by narrator ID. Returns unavailable map when missing.
  Future<Map<String, dynamic>> profileById(int narratorId, {String lang = 'en'}) async {
    if (!await isPackRegistered()) {
      return _unavailable(name: null, notes: 'narrators.db is not registered.');
    }
    try {
      final db = await _registry.open('narrators');
      final rows = await db.query('narrators', where: 'id = ?', whereArgs: [narratorId], limit: 1);
      if (rows.isEmpty) {
        return _unavailable(name: null, notes: 'No verified narrator row for id=$narratorId.');
      }
      return _assembleProfile(Map<String, dynamic>.from(rows.first), lang: lang);
    } catch (_) {
      return _unavailable(name: null, notes: 'Narrator database could not be opened.');
    }
  }

  /// Profile by slug.
  Future<Map<String, dynamic>> profileBySlug(String slug, {String lang = 'en'}) async {
    final clean = slug.trim();
    if (clean.isEmpty) return _unavailable(name: null, notes: 'Empty slug.');
    if (!await isPackRegistered()) {
      return _unavailable(name: clean, notes: 'narrators.db is not registered.');
    }
    try {
      final db = await _registry.open('narrators');
      final rows = await db.query('narrators', where: 'slug = ?', whereArgs: [clean], limit: 1);
      if (rows.isEmpty) {
        return _unavailable(name: clean, notes: 'No verified narrator for this slug.');
      }
      return _assembleProfile(Map<String, dynamic>.from(rows.first), lang: lang);
    } catch (_) {
      return _unavailable(name: clean, notes: 'Narrator database could not be opened.');
    }
  }

  /// Lookup by display name via aliases, or by verified hadith mapping when provided.
  /// Never invents a match with AI / prediction beyond exact normalized alias.
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

    if (name.isEmpty) {
      return _unavailable(name: null, notes: 'No authenticated narrator name was provided for this hadith.');
    }

    if (!await isPackRegistered()) {
      return _unavailable(name: name, notes: 'narrators.db is not registered.');
    }

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
      if (rows.isEmpty) {
        return _unavailable(
          name: name,
          notes: 'No licensed biography matched this authenticated narrator name.',
        );
      }
      return profileById(rows.first['id'] as int, lang: lang);
    } catch (_) {
      return _unavailable(name: name, notes: 'Narrator database could not be opened.');
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

    final hasAnyDetail = teachers.isNotEmpty ||
        students.isNotEmpty ||
        reliability.isNotEmpty ||
        cites.isNotEmpty ||
        books.isNotEmpty ||
        _hasIdentityContent(row);

    if (!hasAnyDetail) {
      return _unavailable(
        name: _displayName(row, lang),
        notes: 'Narrator row exists but no verified biography fields were imported yet.',
      );
    }

    return {
      'unavailable': false,
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

  Map<String, dynamic> _unavailable({required String? name, required String notes}) {
    return {
      'unavailable': true,
      'message': verifiedUnavailableMessage,
      'name': name,
      'notes': notes,
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
