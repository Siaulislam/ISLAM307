import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Opens bundled quran.db — app NEVER reads PDF at runtime.
class QuranDatabase {
  QuranDatabase._();
  static final QuranDatabase instance = QuranDatabase._();

  Database? _db;
  static const _asset = 'assets/databases/quran.db';
  static const _schemaMarker = '3_knowledge';

  Future<Database> open() async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'quran.db');
    final exists = await File(path).exists();
    var needsCopy = !exists;
    if (exists) {
      final probe = await openDatabase(path, readOnly: true);
      try {
        final rows = await probe.query('meta', where: 'key = ?', whereArgs: ['schema_version'], limit: 1);
        final version = rows.isEmpty ? null : rows.first['value'] as String?;
        if (version != _schemaMarker) needsCopy = true;
      } catch (_) {
        needsCopy = true;
      } finally {
        await probe.close();
      }
    }
    if (needsCopy) {
      final data = await rootBundle.load(_asset);
      await File(path).writeAsBytes(data.buffer.asUint8List(), flush: true);
    }
    _db = await openDatabase(path, readOnly: false);
    return _db!;
  }

  Future<bool> hasWordKnowledge() async {
    final db = await open();
    try {
      final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='quran_words' LIMIT 1",
      );
      if (rows.isEmpty) return false;
      final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM quran_words'));
      return (count ?? 0) > 0;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> wordsForAyah(int surah, int ayah) async {
    final db = await open();
    if (!await hasWordKnowledge()) return [];
    return db.query(
      'quran_words',
      where: 'surah = ? AND ayah = ?',
      whereArgs: [surah, ayah],
      orderBy: 'word_number ASC',
    );
  }

  Future<Map<String, dynamic>?> wordById(int id) async {
    final db = await open();
    final rows = await db.query('quran_words', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, dynamic>?> wordAt(int surah, int ayah, int wordNumber) async {
    final db = await open();
    final rows = await db.query(
      'quran_words',
      where: 'surah = ? AND ayah = ? AND word_number = ?',
      whereArgs: [surah, ayah, wordNumber],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> wordParts(int wordId) async {
    final db = await open();
    return db.query(
      'quran_word_parts',
      where: 'word_id = ?',
      whereArgs: [wordId],
      orderBy: 'part_index ASC',
    );
  }

  Future<List<Map<String, dynamic>>> wordsByRoot(String root, {int limit = 12, int? excludeId}) async {
    final db = await open();
    if (excludeId == null) {
      return db.query(
        'quran_words',
        where: 'root = ?',
        whereArgs: [root],
        orderBy: 'surah ASC, ayah ASC, word_number ASC',
        limit: limit,
      );
    }
    return db.query(
      'quran_words',
      where: 'root = ? AND id != ?',
      whereArgs: [root, excludeId],
      orderBy: 'surah ASC, ayah ASC, word_number ASC',
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> searchWords(String query, {int limit = 40}) async {
    final db = await open();
    final q = query.trim();
    if (q.isEmpty || !await hasWordKnowledge()) return [];

    final rootRef = RegExp(r'^(?:root|جذر)\s*[:=]?\s*(.+)$', caseSensitive: false).firstMatch(q);
    if (rootRef != null) {
      final term = '%${rootRef.group(1)!.trim()}%';
      return db.query(
        'quran_words',
        where: 'root LIKE ? OR lemma LIKE ?',
        whereArgs: [term, term],
        orderBy: 'surah ASC, ayah ASC',
        limit: limit,
      );
    }

    final morphRef = RegExp(r'^(?:morph|morphology|grammar|pos)\s*[:=]?\s*(.+)$', caseSensitive: false).firstMatch(q);
    if (morphRef != null) {
      final term = '%${morphRef.group(1)!.trim()}%';
      return db.query(
        'quran_words',
        where: 'morphology LIKE ? OR grammar_summary LIKE ? OR pos LIKE ? OR syntax_summary LIKE ?',
        whereArgs: [term, term, term, term],
        orderBy: 'surah ASC, ayah ASC',
        limit: limit,
      );
    }

    try {
      final fts = await db.rawQuery(
        '''
        SELECT w.*
        FROM quran_words_fts f
        JOIN quran_words w ON w.id = f.rowid
        WHERE quran_words_fts MATCH ?
        LIMIT ?
        ''',
        ['"$q"', limit],
      );
      if (fts.isNotEmpty) return fts;
    } catch (_) {
      // Fall through to LIKE search when FTS query syntax fails.
    }

    final like = '%${q.replaceAll('%', '')}%';
    return db.query(
      'quran_words',
      where: '''
        text_ar LIKE ? OR meaning_en LIKE ? OR meaning_ur LIKE ?
        OR transliteration LIKE ? OR root LIKE ? OR lemma LIKE ?
        OR morphology LIKE ? OR grammar_summary LIKE ? OR pos LIKE ?
      ''',
      whereArgs: [like, like, like, like, like, like, like, like, like],
      orderBy: 'surah ASC, ayah ASC',
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> search(String query, {int limit = 50}) async {
    final db = await open();
    final q = query.trim();
    if (q.isEmpty) return [];

    final ayahRef = RegExp(r'^(\d{1,3})\s*[:\-/]\s*(\d{1,3})$').firstMatch(q);
    if (ayahRef != null) {
      return db.rawQuery(
        '''
        SELECT a.*, s.name_en, s.name_ar
        FROM ayahs a JOIN surahs s ON s.number = a.surah_number
        WHERE a.surah_number = ? AND a.ayah_number = ?
        LIMIT 1
        ''',
        [int.parse(ayahRef.group(1)!), int.parse(ayahRef.group(2)!)],
      );
    }

    final juzRef = RegExp(r'^(?:juz|جزء|پارہ)\s*(\d{1,2})$', caseSensitive: false).firstMatch(q);
    if (juzRef != null) {
      return db.rawQuery(
        '''
        SELECT a.*, s.name_en, s.name_ar
        FROM ayahs a JOIN surahs s ON s.number = a.surah_number
        WHERE a.juz = ?
        ORDER BY a.global_number
        LIMIT ?
        ''',
        [int.parse(juzRef.group(1)!), limit],
      );
    }

    final pageRef = RegExp(r'^(?:page|صفحہ|صفحة)\s*(\d{1,3})$', caseSensitive: false).firstMatch(q);
    if (pageRef != null) {
      return db.rawQuery(
        '''
        SELECT a.*, s.name_en, s.name_ar
        FROM ayahs a JOIN surahs s ON s.number = a.surah_number
        WHERE a.page_madani = ? OR IFNULL(a.page_13_line, -1) = ?
        ORDER BY a.global_number
        LIMIT ?
        ''',
        [int.parse(pageRef.group(1)!), int.parse(pageRef.group(1)!), limit],
      );
    }

    final rukuRef = RegExp(r'^(?:ruku|رکوع)\s*(\d{1,3})$', caseSensitive: false).firstMatch(q);
    if (rukuRef != null) {
      return db.rawQuery(
        '''
        SELECT a.*, s.name_en, s.name_ar
        FROM ayahs a JOIN surahs s ON s.number = a.surah_number
        WHERE a.ruku = ?
        ORDER BY a.global_number
        LIMIT ?
        ''',
        [int.parse(rukuRef.group(1)!), limit],
      );
    }

    final like = '%${q.replaceAll('%', '')}%';
    return db.rawQuery(
      '''
      SELECT a.*, s.name_en, s.name_ar
      FROM ayahs a
      JOIN surahs s ON s.number = a.surah_number
      WHERE s.name_en LIKE ? OR s.name_ar LIKE ? OR s.name_transliteration LIKE ?
         OR a.translation_en LIKE ? OR IFNULL(a.translation_ur,'') LIKE ?
         OR a.text_uthmani LIKE ?
         OR CAST(a.surah_number AS TEXT) = ? OR CAST(a.ruku AS TEXT) = ?
         OR CAST(a.juz AS TEXT) = ?
      ORDER BY a.global_number
      LIMIT ?
      ''',
      [like, like, like, like, like, like, q, q, q, limit],
    );
  }

  Future<List<Map<String, dynamic>>> surahs() async {
    final db = await open();
    return db.query('surahs', orderBy: 'number ASC');
  }

  Future<List<Map<String, dynamic>>> rukus() async {
    final db = await open();
    return db.rawQuery('''
      SELECT r.number, r.surah_number, r.start_ayah, r.end_ayah, r.juz,
             s.name_en, s.name_ar
      FROM ruku r
      JOIN surahs s ON s.number = r.surah_number
      ORDER BY r.number ASC
    ''');
  }

  Future<List<Map<String, dynamic>>> ayahsForSurah(int surah) async {
    final db = await open();
    return db.query('ayahs', where: 'surah_number = ?', whereArgs: [surah], orderBy: 'ayah_number ASC');
  }

  Future<List<Map<String, dynamic>>> ayahsForRuku(int rukuNumber) async {
    final db = await open();
    return db.query('ayahs', where: 'ruku = ?', whereArgs: [rukuNumber], orderBy: 'global_number ASC');
  }

  Future<Map<String, dynamic>?> ayah(int surah, int ayah) async {
    final db = await open();
    final rows = await db.query('ayahs', where: 'surah_number = ? AND ayah_number = ?', whereArgs: [surah, ayah], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, dynamic>?> meta(String key) async {
    final db = await open();
    final rows = await db.query('meta', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }
}
