import '../database/database_registry.dart';
import 'query_language.dart';

class GenericKnowledgeHit {
  const GenericKnowledgeHit({
    required this.database,
    required this.table,
    required this.title,
    required this.excerpt,
    required this.reference,
  });

  final String database;
  final String table;
  final String title;
  final String excerpt;
  final String reference;
}

/// Discovers searchable TEXT columns at runtime, so newly registered local
/// databases become available without prompt or intent changes.
class GenericLocalDatabaseSearch {
  GenericLocalDatabaseSearch(this._registry);

  final DatabaseRegistry _registry;

  Future<List<GenericKnowledgeHit>> search(
    String query, {
    required QueryLanguage language,
    Set<String>? databases,
    int limit = 20,
  }) async {
    final clean = query.trim();
    if (clean.isEmpty) return const [];
    final results = <GenericKnowledgeHit>[];
    for (final databaseName in _registry.registeredNames) {
      if (databases != null && !databases.contains(databaseName)) continue;
      try {
        final db = await _registry.open(databaseName);
        final tableRows = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
        );
        for (final tableRow in tableRows) {
          if (results.length >= limit) break;
          final table = '${tableRow['name']}';
          if (_skipTable(table)) continue;
          final columns = await db.rawQuery(
            'PRAGMA table_info(${_quoted(table)})',
          );
          final textColumns = columns
              .where((column) {
                final type = '${column['type'] ?? ''}'.toUpperCase();
                return type.contains('TEXT') ||
                    type.contains('CHAR') ||
                    type.contains('CLOB');
              })
              .map((column) => '${column['name']}')
              .where((name) => name.isNotEmpty)
              .toList();
          if (textColumns.isEmpty) continue;
          final like = '%${clean.replaceAll('%', '').replaceAll('_', '')}%';
          final where =
              textColumns.map((column) => '${_quoted(column)} LIKE ?').join(' OR ');
          try {
            final rows = await db.rawQuery(
              'SELECT rowid AS __rowid__, * FROM ${_quoted(table)} '
              'WHERE $where LIMIT ?',
              [...List.filled(textColumns.length, like), 2],
            );
            for (final row in rows) {
              results.add(
                _toHit(
                  databaseName,
                  table,
                  Map<String, dynamic>.from(row),
                  textColumns,
                  clean,
                  language,
                ),
              );
              if (results.length >= limit) break;
            }
          } catch (_) {
            // A virtual/WITHOUT ROWID table may reject the generic query.
            // Its dedicated repository remains available.
          }
        }
      } catch (_) {
        // One unavailable local pack must not prevent other evidence sources.
      }
    }
    return results;
  }

  bool _skipTable(String table) {
    return table.startsWith('sqlite_') ||
        table.endsWith('_data') ||
        table.endsWith('_idx') ||
        table.endsWith('_content') ||
        table.endsWith('_docsize') ||
        table.endsWith('_config') ||
        table.contains('_fts');
  }

  GenericKnowledgeHit _toHit(
    String database,
    String table,
    Map<String, dynamic> row,
    List<String> textColumns,
    String query,
    QueryLanguage language,
  ) {
    final preferredColumns = switch (language) {
      QueryLanguage.urdu => ['text_ur', 'name_ur', 'translation_ur'],
      QueryLanguage.arabic => ['text_ar', 'name_ar', 'text_uthmani'],
      QueryLanguage.english => ['text_en', 'name_en', 'translation_en', 'text'],
    };
    final ordered = <String>[
      ...preferredColumns.where(textColumns.contains),
      ...textColumns.where((column) => !preferredColumns.contains(column)),
    ];
    final matching = ordered.where((column) {
      final value = '${row[column] ?? ''}'.trim();
      return value.toLowerCase().contains(query.toLowerCase());
    });
    final values = <String>[
      ...matching.map((column) => '${row[column]}'.trim()),
      ...ordered
          .map((column) => '${row[column] ?? ''}'.trim())
          .where((value) => value.isNotEmpty),
    ];
    final excerpt = values.toSet().take(3).join('\n');
    final reference = _reference(database, table, row);
    return GenericKnowledgeHit(
      database: database,
      table: table,
      title: '${database.toUpperCase()} · $table',
      excerpt: excerpt,
      reference: reference,
    );
  }

  String _reference(
    String database,
    String table,
    Map<String, dynamic> row,
  ) {
    final surah = row['surah_number'] ?? row['surah'];
    final ayah = row['ayah_number'] ?? row['ayah'];
    if (surah != null && ayah != null) {
      final word = row['word_number'];
      return word == null
          ? 'Quran $surah:$ayah'
          : 'Quran $surah:$ayah · Word $word';
    }
    final hadith = row['hadith_number'];
    if (hadith != null) {
      final book = row['book_id'] ?? row['book_slug'] ?? database;
      return 'Hadith · Book $book · $hadith';
    }
    final id = row['id'] ?? row['slug'] ?? row['__rowid__'];
    return '$database.$table${id == null ? '' : ' · $id'}';
  }

  String _quoted(String identifier) {
    return '"${identifier.replaceAll('"', '""')}"';
  }
}
