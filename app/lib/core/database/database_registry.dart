import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../datasets/dataset_license_registry.dart';

/// Copies bundled SQLite assets once; supports .db or .db.gz (modular registry).
class DatabaseRegistry {
  DatabaseRegistry._();
  static final DatabaseRegistry instance = DatabaseRegistry._();

  final _cache = <String, Database>{};

  /// Only datasets approved by DatasetLicenseRegistry may be added here.
  static const bundled = {
    'quran': 'assets/databases/quran.db',
  };
  static const datasetIds = {
    'quran': 'quran-arabic-tanzil',
  };

  bool isRegistered(String name) => bundled.containsKey(name);

  Future<Database> open(String name) async {
    if (_cache.containsKey(name)) return _cache[name]!;
    final asset = bundled[name];
    if (asset == null) {
      throw ArgumentError('Unknown database: $name');
    }
    final datasetId = datasetIds[name];
    final license = datasetId == null
        ? null
        : await DatasetLicenseRegistry.instance.dataset(datasetId);
    if (license?.mayBundle != true) {
      throw StateError(
        'Dataset $datasetId is not approved for offline commercial bundling.',
      );
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
