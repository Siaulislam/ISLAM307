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

  Future<Database> open() async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'quran.db');
    final exists = await File(path).exists();
    if (!exists) {
      final data = await rootBundle.load('assets/databases/quran.db');
      await File(path).writeAsBytes(data.buffer.asUint8List(), flush: true);
    }
    _db = await openDatabase(path, readOnly: false);
    return _db!;
  }

  Future<List<Map<String, dynamic>>> search(String query, {int limit = 50}) async {
    final db = await open();
    final q = query.trim();
    if (q.isEmpty) return [];
    return db.rawQuery(
      '''
      SELECT a.*, s.name_en, s.name_ar
      FROM ayah_fts f
      JOIN ayahs a ON a.id = f.ayah_id
      JOIN surahs s ON s.number = a.surah_number
      WHERE ayah_fts MATCH ?
      ORDER BY a.global_number
      LIMIT ?
      ''',
      [q, limit],
    );
  }

  Future<List<Map<String, dynamic>>> surahs() async {
    final db = await open();
    return db.query('surahs', orderBy: 'number ASC');
  }

  Future<List<Map<String, dynamic>>> ayahsForSurah(int surah) async {
    final db = await open();
    return db.query('ayahs', where: 'surah_number = ?', whereArgs: [surah], orderBy: 'ayah_number ASC');
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
