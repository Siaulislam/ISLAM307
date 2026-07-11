import '../database/database_registry.dart';
import '../modules/module_catalog.dart';

/// Offline hadith access — authenticated database rows only.
class HadithRepository {
  HadithRepository(this._registry, {ModuleCatalog? catalog})
      : _catalog = catalog ?? ModuleCatalog.instance;

  final DatabaseRegistry _registry;
  final ModuleCatalog _catalog;

  static const gradeNotVerified = 'Grade not verified.';
  bool? _hasGradeTable;
  bool? _hasKitabNumber;

  Future<List<Map<String, dynamic>>> books({bool enabledOnly = true}) async {
    final db = await _registry.open('hadith');
    final rows = await db.query('books', orderBy: 'sort_order ASC');
    if (!enabledOnly) return rows;
    final allowed = (await _catalog.enabledHadithSlugs()).toSet();
    return rows.where((b) => allowed.contains(b['slug'])).toList();
  }

  Future<List<Map<String, dynamic>>> chapters(int bookId) async {
    final db = await _registry.open('hadith');
    final order = await _chapterOrderBy(db);
    return db.query('chapters', where: 'book_id = ?', whereArgs: [bookId], orderBy: order);
  }

  Future<List<Map<String, dynamic>>> hadithsForBook(int bookId, {int limit = 100, int offset = 0}) async {
    final db = await _registry.open('hadith');
    final rows = await db.query(
      'hadiths',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'hadith_number ASC',
      limit: limit,
      offset: offset,
    );
    return Future.wait(rows.map(_enrich));
  }

  Future<Map<String, dynamic>?> hadith(int bookId, int hadithNumber) async {
    final db = await _registry.open('hadith');
    final rows = await db.query(
      'hadiths',
      where: 'book_id = ? AND hadith_number = ?',
      whereArgs: [bookId, hadithNumber],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _enrich(rows.first);
  }

  Future<List<Map<String, dynamic>>> gradesForHadith(int hadithId, {String? legacyGrade}) async {
    final db = await _registry.open('hadith');
    if (await _supportsGradeTable(db)) {
      return db.query(
        'hadith_grades',
        where: 'hadith_id = ?',
        whereArgs: [hadithId],
        orderBy: 'sort_order ASC',
      );
    }
    final g = legacyGrade?.trim();
    if (g == null || g.isEmpty) return [];
    return [
      {'hadith_id': hadithId, 'grade': g, 'graded_by': null, 'language': 'en', 'sort_order': 0},
    ];
  }

  Future<List<Map<String, dynamic>>> search(String query, {int limit = 40}) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final db = await _registry.open('hadith');
    final allowed = await _catalog.enabledHadithSlugs();
    final placeholders = List.filled(allowed.length, '?').join(',');
    final number = int.tryParse(q);

    if (number != null) {
      final rows = await db.rawQuery(
        '''
        SELECT h.*, b.slug AS book_slug, b.name_en AS book_name
        FROM hadiths h
        JOIN books b ON b.id = h.book_id
        WHERE h.hadith_number = ? AND b.slug IN ($placeholders)
        ORDER BY h.book_id, h.hadith_number
        LIMIT ?
        ''',
        [number, ...allowed, limit],
      );
      return Future.wait(rows.map(_enrich));
    }

    final rows = await db.rawQuery(
      '''
      SELECT h.*, b.slug AS book_slug, b.name_en AS book_name
      FROM hadith_fts f
      JOIN hadiths h ON h.id = f.hadith_id
      JOIN books b ON b.id = h.book_id
      WHERE hadith_fts MATCH ? AND b.slug IN ($placeholders)
      ORDER BY h.book_id, h.hadith_number
      LIMIT ?
      ''',
      [q, ...allowed, limit],
    );
    return Future.wait(rows.map(_enrich));
  }

  Future<Map<String, dynamic>> _enrich(Map<String, dynamic> row) async {
    final map = Map<String, dynamic>.from(row);
    map['grades'] = await gradesForHadith(map['id'] as int, legacyGrade: map['grade'] as String?);
    map['reference_url'] ??= 'https://sunnah.com/${map['book_id']}:${map['hadith_number']}';
    return map;
  }

  Future<bool> _supportsGradeTable(dynamic db) async {
    if (_hasGradeTable != null) return _hasGradeTable!;
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='hadith_grades'",
    );
    _hasGradeTable = rows.isNotEmpty;
    return _hasGradeTable!;
  }

  Future<String> _chapterOrderBy(dynamic db) async {
    if (_hasKitabNumber != null) {
      return _hasKitabNumber! ? 'kitab_number, number ASC' : 'number ASC';
    }
    final cols = await db.rawQuery('PRAGMA table_info(chapters)');
    _hasKitabNumber = cols.any((c) => c['name'] == 'kitab_number');
    return _hasKitabNumber! ? 'kitab_number, number ASC' : 'number ASC';
  }

  static ({String grade, String? scholar, String referenceUrl}) gradingSummary(
    Map<String, dynamic> hadithRow,
  ) {
    final grades = hadithRow['grades'] as List<Map<String, dynamic>>? ?? [];
    if (grades.isEmpty) {
      final legacy = (hadithRow['grade'] as String?)?.trim();
      return (
        grade: (legacy == null || legacy.isEmpty) ? gradeNotVerified : legacy,
        scholar: null,
        referenceUrl: hadithRow['reference_url'] as String? ?? '',
      );
    }
    final primary = grades.first;
    return (
      grade: (primary['grade'] as String?)?.trim() ?? gradeNotVerified,
      scholar: (primary['graded_by'] as String?)?.trim(),
      referenceUrl: hadithRow['reference_url'] as String? ?? '',
    );
  }
}
