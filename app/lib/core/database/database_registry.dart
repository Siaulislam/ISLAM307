import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Copies bundled SQLite assets once; supports .db or .db.gz (modular registry).
class DatabaseRegistry {
  DatabaseRegistry._();
  static final DatabaseRegistry instance = DatabaseRegistry._();

  final _cache = <String, Database>{};

  /// Asset paths — add new databases here (no hardcoding in features).
  static const bundled = {
    'quran': 'assets/databases/quran.db',
    'hadith': 'assets/databases/hadith.db.gz',
    'tafsir': 'assets/databases/tafsir.db.gz',
  };

  Future<Database> open(String name) async {
    if (_cache.containsKey(name)) return _cache[name]!;
    final asset = bundled[name];
    if (asset == null) {
      throw ArgumentError('Unknown database: $name');
    }
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, '$name.db');
    if (!await File(path).exists()) {
      await _materializeAsset(asset, path);
    }
    final db = await openDatabase(path);
    _cache[name] = db;
    return db;
  }

  Future<void> _materializeAsset(String assetPath, String destPath) async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();
    if (assetPath.endsWith('.gz')) {
      final decoded = gzip.decode(bytes);
      await File(destPath).writeAsBytes(decoded, flush: true);
    } else {
      await File(destPath).writeAsBytes(bytes, flush: true);
    }
  }

  Future<void> closeAll() async {
    for (final db in _cache.values) {
      await db.close();
    }
    _cache.clear();
  }
}
