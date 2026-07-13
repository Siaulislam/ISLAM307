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
  static const _schemaMarker = '2_urdu';

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
         OR CAST(a.surah_number AS TEXT) = ? OR CAST(a.ruku AS TEXT) = ?
      ORDER BY a.global_number
      LIMIT ?
      ''',
      [like, like, like, like, like, q, q, limit],
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
