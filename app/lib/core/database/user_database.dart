import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class UserDatabase {
  UserDatabase._();
  static final UserDatabase instance = UserDatabase._();

  Database? _database;

  Future<Database> open() async {
    if (_database != null) return _database!;
    final documents = await getApplicationDocumentsDirectory();
    final path = p.join(documents.path, 'user.db');
    _database = await openDatabase(
      path,
      version: 3,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE schema_meta(
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE user_items(
            target_uri TEXT NOT NULL,
            item_type TEXT NOT NULL,
            title TEXT,
            subtitle TEXT,
            metadata_json TEXT NOT NULL DEFAULT '{}',
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            PRIMARY KEY(target_uri, item_type)
          )
        ''');
        await db.execute('''
          CREATE TABLE notes(
            target_uri TEXT PRIMARY KEY,
            body TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE highlights(
            target_uri TEXT PRIMARY KEY,
            color TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE reading_history(
            target_uri TEXT PRIMARY KEY,
            content_type TEXT NOT NULL,
            title TEXT,
            subtitle TEXT,
            position_json TEXT NOT NULL DEFAULT '{}',
            progress REAL,
            last_opened_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE collections(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE collection_items(
            collection_id INTEGER NOT NULL,
            target_uri TEXT NOT NULL,
            added_at INTEGER NOT NULL,
            PRIMARY KEY(collection_id, target_uri),
            FOREIGN KEY(collection_id) REFERENCES collections(id)
              ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE tasbeeh_sessions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            label TEXT NOT NULL,
            count INTEGER NOT NULL DEFAULT 0,
            target_count INTEGER,
            started_at INTEGER NOT NULL,
            completed_at INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE prayer_log(
            local_date TEXT NOT NULL,
            prayer TEXT NOT NULL,
            status TEXT NOT NULL,
            updated_at INTEGER NOT NULL,
            PRIMARY KEY(local_date, prayer)
          )
        ''');
        await db.execute('''
          CREATE TABLE installed_datasets(
            dataset_id TEXT PRIMARY KEY,
            source_url TEXT NOT NULL,
            license_name TEXT NOT NULL,
            license_evidence TEXT NOT NULL,
            version TEXT NOT NULL,
            downloaded_at INTEGER NOT NULL,
            attribution TEXT NOT NULL,
            checksum_sha256 TEXT NOT NULL,
            schema_version INTEGER NOT NULL,
            enabled INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE content_updates(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            dataset_id TEXT NOT NULL,
            version TEXT NOT NULL,
            checked_at INTEGER NOT NULL,
            installed_at INTEGER,
            status TEXT NOT NULL,
            FOREIGN KEY(dataset_id) REFERENCES installed_datasets(dataset_id)
              ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE licensed_search_documents(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            dataset_id TEXT NOT NULL,
            content_type TEXT NOT NULL,
            source_ref TEXT NOT NULL,
            title TEXT,
            body TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE user_search_documents(
            kind TEXT NOT NULL,
            title TEXT,
            body TEXT,
            target_uri TEXT NOT NULL,
            PRIMARY KEY(kind, target_uri)
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_licensed_search_dataset '
          'ON licensed_search_documents(dataset_id, content_type)',
        );
        await db.insert('schema_meta', {
          'key': 'schema_version',
          'value': '$version',
        });
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS installed_datasets(
              dataset_id TEXT PRIMARY KEY,
              source_url TEXT NOT NULL,
              license_name TEXT NOT NULL,
              license_evidence TEXT NOT NULL,
              version TEXT NOT NULL,
              downloaded_at INTEGER NOT NULL,
              attribution TEXT NOT NULL,
              checksum_sha256 TEXT NOT NULL,
              schema_version INTEGER NOT NULL,
              enabled INTEGER NOT NULL DEFAULT 0
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS content_updates(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              dataset_id TEXT NOT NULL,
              version TEXT NOT NULL,
              checked_at INTEGER NOT NULL,
              installed_at INTEGER,
              status TEXT NOT NULL,
              FOREIGN KEY(dataset_id)
                REFERENCES installed_datasets(dataset_id) ON DELETE CASCADE
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute('DROP TABLE IF EXISTS licensed_content_fts');
          await db.execute('DROP TABLE IF EXISTS user_search_fts');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS licensed_search_documents(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              dataset_id TEXT NOT NULL,
              content_type TEXT NOT NULL,
              source_ref TEXT NOT NULL,
              title TEXT,
              body TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS user_search_documents(
              kind TEXT NOT NULL,
              title TEXT,
              body TEXT,
              target_uri TEXT NOT NULL,
              PRIMARY KEY(kind, target_uri)
            )
          ''');
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_licensed_search_dataset '
            'ON licensed_search_documents(dataset_id, content_type)',
          );
        }
        await db.insert(
          'schema_meta',
          {'key': 'schema_version', 'value': '$newVersion'},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      },
    );
    return _database!;
  }

  Future<bool> hasItem(String type, String targetUri) async {
    final db = await open();
    final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM user_items WHERE item_type = ? AND target_uri = ?',
      [type, targetUri],
    ));
    return (count ?? 0) > 0;
  }

  Future<void> importLegacyLibrary(Map<String, dynamic> data) async {
    final db = await open();
    await db.transaction((txn) async {
      final migrated = await txn.query(
        'schema_meta',
        where: 'key = ?',
        whereArgs: ['legacy_library_json_migrated'],
        limit: 1,
      );
      if (migrated.isNotEmpty) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final raw in (data['bookmarks'] as List?) ?? const []) {
        final parts = '$raw'.split(':');
        if (parts.length != 2 ||
            int.tryParse(parts[0]) == null ||
            int.tryParse(parts[1]) == null) {
          continue;
        }
        final uri = 'quran://${parts[0]}/${parts[1]}';
        await txn.insert(
          'user_items',
          {
            'target_uri': uri,
            'item_type': 'bookmark',
            'title': 'Quran ${parts[0]}:${parts[1]}',
            'metadata_json': '{}',
            'created_at': now,
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      for (final entry
          in Map<String, dynamic>.from(data['notes'] as Map? ?? const {})
              .entries) {
        final parts = entry.key.split(':');
        if (parts.length != 2 ||
            int.tryParse(parts[0]) == null ||
            int.tryParse(parts[1]) == null) {
          continue;
        }
        final uri = 'quran://${parts[0]}/${parts[1]}';
        final inserted = await txn.insert(
          'notes',
          {
            'target_uri': uri,
            'body': '${entry.value}',
            'created_at': now,
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        if (inserted > 0) {
          await txn.insert('user_search_documents', {
            'kind': 'note',
            'title': 'Personal note',
            'body': '${entry.value}',
            'target_uri': uri,
          });
        }
      }
      for (final entry
          in Map<String, dynamic>.from(
            data['highlights'] as Map? ?? const {},
          ).entries) {
        final parts = entry.key.split(':');
        if (parts.length != 2 ||
            int.tryParse(parts[0]) == null ||
            int.tryParse(parts[1]) == null) {
          continue;
        }
        await txn.insert(
          'highlights',
          {
            'target_uri': 'quran://${parts[0]}/${parts[1]}',
            'color': '${entry.value}',
            'created_at': now,
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await txn.insert(
        'schema_meta',
        {
          'key': 'legacy_library_json_migrated',
          'value': DateTime.now().toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<bool> toggleItem(
    String type,
    String targetUri, {
    String? title,
    String? subtitle,
    Map<String, dynamic> metadata = const {},
  }) async {
    final db = await open();
    if (await hasItem(type, targetUri)) {
      await db.delete(
        'user_items',
        where: 'item_type = ? AND target_uri = ?',
        whereArgs: [type, targetUri],
      );
      return false;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('user_items', {
      'target_uri': targetUri,
      'item_type': type,
      'title': title,
      'subtitle': subtitle,
      'metadata_json': jsonEncode(metadata),
      'created_at': now,
      'updated_at': now,
    });
    return true;
  }

  Future<List<Map<String, dynamic>>> items(String type) async {
    final db = await open();
    return db.query(
      'user_items',
      where: 'item_type = ?',
      whereArgs: [type],
      orderBy: 'updated_at DESC',
    );
  }

  Future<String?> note(String targetUri) async {
    final db = await open();
    final rows = await db.query(
      'notes',
      columns: ['body'],
      where: 'target_uri = ?',
      whereArgs: [targetUri],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['body'] as String?;
  }

  Future<void> setNote(String targetUri, String body) async {
    final db = await open();
    final clean = body.trim();
    if (clean.isEmpty) {
      await db.delete(
        'notes',
        where: 'target_uri = ?',
        whereArgs: [targetUri],
      );
      await _replaceSearchEntry(targetUri, 'note', '', '');
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'notes',
      {
        'target_uri': targetUri,
        'body': clean,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _replaceSearchEntry(targetUri, 'note', 'Personal note', clean);
  }

  Future<List<Map<String, dynamic>>> notes({int limit = 100}) async {
    final db = await open();
    return db.query(
      'notes',
      orderBy: 'updated_at DESC',
      limit: limit,
    );
  }

  Future<String?> highlight(String targetUri) async {
    final db = await open();
    final rows = await db.query(
      'highlights',
      columns: ['color'],
      where: 'target_uri = ?',
      whereArgs: [targetUri],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['color'] as String?;
  }

  Future<String?> toggleHighlight(
    String targetUri, {
    String color = 'gold',
  }) async {
    final db = await open();
    if (await highlight(targetUri) == color) {
      await db.delete(
        'highlights',
        where: 'target_uri = ?',
        whereArgs: [targetUri],
      );
      return null;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'highlights',
      {
        'target_uri': targetUri,
        'color': color,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return color;
  }

  Future<void> recordHistory({
    required String targetUri,
    required String contentType,
    required String title,
    String? subtitle,
    Map<String, dynamic> position = const {},
    double? progress,
  }) async {
    final db = await open();
    await db.insert(
      'reading_history',
      {
        'target_uri': targetUri,
        'content_type': contentType,
        'title': title,
        'subtitle': subtitle,
        'position_json': jsonEncode(position),
        'progress': progress,
        'last_opened_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> history({int limit = 100}) async {
    final db = await open();
    return db.query(
      'reading_history',
      orderBy: 'last_opened_at DESC',
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> searchUserData(
    String query, {
    int limit = 30,
  }) async {
    final db = await open();
    final clean = query.trim();
    if (clean.isEmpty) return const [];
    final like = '%${clean.replaceAll('%', '').replaceAll('_', '')}%';
    return db.rawQuery(
      '''
      SELECT kind, title, body, target_uri
      FROM user_search_documents
      WHERE title LIKE ? OR body LIKE ?
      ORDER BY rowid DESC
      LIMIT ?
      ''',
      [like, like, limit],
    );
  }

  Future<void> _replaceSearchEntry(
    String targetUri,
    String kind,
    String title,
    String body,
  ) async {
    final db = await open();
    await db.delete(
      'user_search_documents',
      where: 'target_uri = ? AND kind = ?',
      whereArgs: [targetUri, kind],
    );
    if (body.isNotEmpty || title.isNotEmpty) {
      await db.insert(
        'user_search_documents',
        {
        'kind': kind,
        'title': title,
        'body': body,
        'target_uri': targetUri,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }
}
