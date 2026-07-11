import '../database/database_registry.dart';

class TafsirRepository {
  TafsirRepository(this._registry);
  final DatabaseRegistry _registry;

  Future<List<Map<String, dynamic>>> sources() async {
    final db = await _registry.open('tafsir');
    return db.query('sources', orderBy: 'sort_order ASC');
  }

  Future<Map<String, dynamic>?> entry(String sourceSlug, int surah, int ayah) async {
    final db = await _registry.open('tafsir');
    final rows = await db.rawQuery(
      '''
      SELECT e.*, s.slug, s.name_en AS source_name
      FROM entries e
      JOIN sources s ON s.id = e.source_id
      WHERE s.slug = ? AND e.surah_number = ? AND e.ayah_number = ?
      LIMIT 1
      ''',
      [sourceSlug, surah, ayah],
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> search(String query, {int limit = 30}) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final db = await _registry.open('tafsir');
    return db.rawQuery(
      '''
      SELECT e.*, s.name_en AS source_name, s.slug AS source_slug
      FROM tafsir_fts f
      JOIN entries e ON e.id = f.entry_id
      JOIN sources s ON s.id = e.source_id
      WHERE tafsir_fts MATCH ?
      LIMIT ?
      ''',
      [q, limit],
    );
  }
}
