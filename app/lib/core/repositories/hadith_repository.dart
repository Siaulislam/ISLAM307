import 'dart:convert';

import 'package:flutter/services.dart';

import '../database/database_registry.dart';
import '../modules/module_catalog.dart';
import '../../features/hadith/hadith_meta.dart';

/// Offline hadith access — authenticated database rows only.
class HadithRepository {
  HadithRepository(this._registry, {ModuleCatalog? catalog})
      : _catalog = catalog ?? ModuleCatalog.instance;

  final DatabaseRegistry _registry;
  final ModuleCatalog _catalog;

  static const gradeNotVerified = 'Grade not verified.';
  bool? _hasGradeTable;
  bool? _hasKitabNumber;
  bool _i18nLoaded = false;

  Future<void> _ensureChapterI18n() async {
    if (_i18nLoaded) return;
    _i18nLoaded = true;
    try {
      final raw = await rootBundle.loadString('assets/modules/hadith_chapter_i18n.json');
      setChapterI18n(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Optional asset — English chapter titles remain if missing.
    }
  }

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

  /// Topics (کتاب) with hadith counts for professional browse.
  Future<List<Map<String, dynamic>>> chaptersWithCounts(int bookId) async {
    await _ensureChapterI18n();
    final db = await _registry.open('hadith');
    final hasKitabNumber = await _chapterHasKitabNumber(db);
    final order = hasKitabNumber ? 'c.kitab_number ASC, c.number ASC' : 'c.number ASC';
    final rows = await db.rawQuery(
      '''
      SELECT c.id, c.book_id, c.number, c.title, c.hadith_start, c.hadith_end,
             COUNT(h.id) AS hadith_count
      FROM chapters c
      LEFT JOIN hadiths h ON h.chapter_id = c.id
      WHERE c.book_id = ? AND TRIM(IFNULL(c.title, '')) != ''
      GROUP BY c.id
      ORDER BY $order
      ''',
      [bookId],
    );
    final bookRows = await db.query('books', where: 'id = ?', whereArgs: [bookId], limit: 1);
    final slug = bookRows.isEmpty ? 'hadith' : '${bookRows.first['slug']}';
    return rows.map((row) {
      final map = Map<String, dynamic>.from(row);
      final titleEn = '${map['title'] ?? ''}';
      map['title_en'] = titleEn;
      map['title_ur'] = localizedChapterTitle(slug, titleEn, 'ur');
      map['title_ar'] = localizedChapterTitle(slug, titleEn, 'ar');
      return map;
    }).toList();
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

  Future<List<Map<String, dynamic>>> hadithsForChapter(
    int bookId,
    int chapterId, {
    int limit = 200,
    int offset = 0,
  }) async {
    final db = await _registry.open('hadith');
    final rows = await db.query(
      'hadiths',
      where: 'book_id = ? AND chapter_id = ?',
      whereArgs: [bookId, chapterId],
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
    await _ensureChapterI18n();
    final map = Map<String, dynamic>.from(row);
    map['grades'] = await gradesForHadith(map['id'] as int, legacyGrade: map['grade'] as String?);

    final db = await _registry.open('hadith');
    final bookRows = await db.query('books', where: 'id = ?', whereArgs: [map['book_id']], limit: 1);
    final book = bookRows.isEmpty ? null : bookRows.first;
    final bookName = book?['name_en'] as String? ?? map['book_name'] as String? ?? 'Hadith';
    final slug = book?['slug'] as String? ?? map['book_slug'] as String? ?? 'hadith';
    final hadithNo = map['hadith_number'] as int;
    final refBook = map['reference_book'];
    final refHadith = map['reference_hadith'] ?? hadithNo;

    String reference = '$bookName · Hadith $refHadith';
    if (refBook != null && '$refBook' != '0' && '$refBook'.trim().isNotEmpty) {
      reference = '$bookName · Book $refBook · Hadith $refHadith';
    }

    String? kitab;
    dynamic kitabNumber;
    final chapterId = map['chapter_id'];
    if (chapterId != null) {
      final chapters = await db.query('chapters', where: 'id = ?', whereArgs: [chapterId], limit: 1);
      if (chapters.isNotEmpty) {
        kitab = chapters.first['title'] as String?;
        kitabNumber = chapters.first['number'];
        map['kitab_number'] = kitabNumber;
      }
    }

    final ravi = (map['narrator'] as String?)?.trim();
    final textAr = map['text_ar'] as String?;
    final textEn = map['text_en'] as String?;
    final textUr = map['text_ur'] as String?;
    final bookNameAr = book?['name_ar'] as String?;
    map['ravi'] = (ravi == null || ravi.isEmpty) ? null : ravi;
    final raviByLang = extractRaviByLang(textAr, primary: ravi, textEn: textEn, textUr: textUr);
    map['ravi_by_lang'] = raviByLang;
    map['ravi_chain'] = raviByLang['ar'] ?? const <String>[];
    final isnads = isnadByLang(textAr, textEn: textEn, textUr: textUr);
    map['isnad_by_lang'] = isnads;
    map['isnad'] = isnads['ar'] ?? '';
    map['isnad_ur'] = isnads['ur'] ?? '';
    map['reference'] = reference;
    map['kitab'] = kitab;
    map['book_name'] ??= bookName;
    map['book_slug'] ??= slug;
    map['book_name_ar'] ??= bookNameAr;
    map['reference_detail'] = buildReferenceDetail(
      bookName: bookName,
      bookSlug: slug,
      bookNameAr: bookNameAr,
      hadithNumber: hadithNo,
      referenceBook: refBook,
      referenceHadith: refHadith,
      chapterTitle: kitab,
      chapterNumber: kitabNumber,
      grade: map['grade'] as String?,
    );
    map['reference_url'] =
        (map['reference_detail'] as Map)['source_url']?.toString() ?? 'https://sunnah.com/$slug:$hadithNo';
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
    await _chapterHasKitabNumber(db);
    return _hasKitabNumber! ? 'kitab_number, number ASC' : 'number ASC';
  }

  Future<bool> _chapterHasKitabNumber(dynamic db) async {
    if (_hasKitabNumber != null) return _hasKitabNumber!;
    final cols = await db.rawQuery('PRAGMA table_info(chapters)');
    _hasKitabNumber = cols.any((c) => c['name'] == 'kitab_number');
    return _hasKitabNumber!;
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
