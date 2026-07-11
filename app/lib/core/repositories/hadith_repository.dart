import '../database/database_registry.dart';

/// Offline hadith data access — authenticated sources only (Sunnah.com).
class HadithRepository {
  HadithRepository(this._registry);
  final DatabaseRegistry _registry;

  static const gradeNotVerified = 'Grade not verified.';

  Future<List<Map<String, dynamic>>> books() async {
    final db = await _registry.open('hadith');
    return db.query('books', orderBy: 'sort_order ASC');
  }

  Future<List<Map<String, dynamic>>> chapters(int bookId) async {
    final db = await _registry.open('hadith');
    return db.query('chapters', where: 'book_id = ?', whereArgs: [bookId], orderBy: 'kitab_number, number ASC');
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
    final row = Map<String, dynamic>.from(rows.first);
    row['grades'] = await gradesForHadith(row['id'] as int);
    return row;
  }

  Future<List<Map<String, dynamic>>> gradesForHadith(int hadithId) async {
    final db = await _registry.open('hadith');
    return db.query(
      'hadith_grades',
      where: 'hadith_id = ?',
      whereArgs: [hadithId],
      orderBy: 'sort_order ASC',
    );
  }

  Future<List<Map<String, dynamic>>> search(String query, {int limit = 40}) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final db = await _registry.open('hadith');
    final rows = await db.rawQuery(
      '''
      SELECT h.*, b.slug AS book_slug, b.name_en AS book_name
      FROM hadith_fts f
      JOIN hadiths h ON h.id = f.hadith_id
      JOIN books b ON b.id = h.book_id
      WHERE hadith_fts MATCH ?
      ORDER BY h.book_id, h.hadith_number
      LIMIT ?
      ''',
      [q, limit],
    );
    final enriched = <Map<String, dynamic>>[];
    for (final row in rows) {
      final map = Map<String, dynamic>.from(row);
      map['grades'] = await gradesForHadith(map['id'] as int);
      enriched.add(map);
    }
    return enriched;
  }

  /// Primary grade + scholar for AI display; never hides grading.
  static ({String grade, String? scholar, String referenceUrl}) gradingSummary(
    Map<String, dynamic> hadithRow,
  ) {
    final grades = hadithRow['grades'] as List<Map<String, dynamic>>? ?? [];
    if (grades.isEmpty) {
      return (
        grade: gradeNotVerified,
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

  /// All gradings when multiple scholars graded the same hadith.
  static List<({String grade, String? scholar})> allGradings(Map<String, dynamic> hadithRow) {
    final grades = hadithRow['grades'] as List<Map<String, dynamic>>? ?? [];
    if (grades.isEmpty) {
      return [(grade: gradeNotVerified, scholar: null)];
    }
    return grades
        .map((g) => (
              grade: (g['grade'] as String?)?.trim() ?? gradeNotVerified,
              scholar: (g['graded_by'] as String?)?.trim(),
            ))
        .toList();
  }
}
