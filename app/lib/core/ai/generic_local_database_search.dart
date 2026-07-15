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
    List<String> terms, {
    required QueryLanguage language,
    Set<String>? databases,
    int limit = 20,
  }) async {
    if (terms.isEmpty) return const [];
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
          final searchableColumns = columns
              .where((column) {
                final type = '${column['type'] ?? ''}'.toUpperCase();
                final name = '${column['name'] ?? ''}';
                return !type.contains('BLOB') &&
                    name.isNotEmpty &&
                    _matchesLanguage(name, language);
              })
              .map((column) => '${column['name']}')
              .where((name) => name.isNotEmpty)
              .toList();
          if (searchableColumns.isEmpty) continue;
          final whereParts = <String>[];
          final arguments = <Object?>[];
          for (final column in searchableColumns) {
            for (final term in terms) {
              whereParts.add(
                'CAST(${_quoted(column)} AS TEXT) LIKE ? COLLATE NOCASE',
              );
              arguments.add(
                '%${term.replaceAll('%', '').replaceAll('_', '')}%',
              );
            }
          }
          final primaryKeys = columns
              .where((column) => (column['pk'] as int? ?? 0) > 0)
              .toList()
            ..sort(
              (a, b) =>
                  (a['pk'] as int? ?? 0).compareTo(b['pk'] as int? ?? 0),
            );
          final orderBy = primaryKeys.isEmpty
              ? ''
              : ' ORDER BY ${primaryKeys.map((column) => _quoted('${column['name']}')).join(', ')}';
          try {
            final rows = await db.rawQuery(
              'SELECT * FROM ${_quoted(table)} '
              'WHERE ${whereParts.join(' OR ')}$orderBy LIMIT ?',
              [...arguments, 2],
            );
            for (final row in rows) {
              results.add(
                _toHit(
                  databaseName,
                  table,
                  Map<String, dynamic>.from(row),
                  searchableColumns,
                  terms,
                  language,
                ),
              );
              if (results.length >= limit) break;
            }
          } catch (_) {
            // A virtual table may reject the generic query. Its dedicated
            // repository remains available.
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
    List<String> terms,
    QueryLanguage language,
  ) {
    final ordered = [...textColumns]..sort();
    final matching = ordered.where((column) {
      final value = '${row[column] ?? ''}'.trim();
      return terms.any(
        (term) => value.toLowerCase().contains(term.toLowerCase()),
      );
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
    final id = row['id'] ?? row['slug'];
    return '$database.$table${id == null ? '' : ' · $id'}';
  }

  bool _matchesLanguage(String column, QueryLanguage language) {
    final name = column.toLowerCase();
    if ({
      'text',
      'title',
      'name',
      'value',
      'notes',
      'description',
      'body',
      'quote',
    }.contains(name)) {
      return true;
    }
    return switch (language) {
      QueryLanguage.urdu =>
        name.contains('_ur') || name.contains('urdu'),
      QueryLanguage.arabic =>
        name.contains('_ar') ||
            name.contains('arabic') ||
            name.contains('uthmani'),
      QueryLanguage.english =>
        name.contains('_en') ||
            name.contains('english') ||
            name.contains('summary'),
    };
  }

  String _quoted(String identifier) {
    return '"${identifier.replaceAll('"', '""')}"';
  }
}
