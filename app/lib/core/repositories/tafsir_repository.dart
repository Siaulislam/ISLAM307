import '../database/database_registry.dart';
import '../modules/module_catalog.dart';

class TafsirRepository {
  TafsirRepository(this._registry, {ModuleCatalog? catalog})
      : _catalog = catalog ?? ModuleCatalog.instance;

  final DatabaseRegistry _registry;
  final ModuleCatalog _catalog;

  static const unavailableMessage =
      'Authentic tafsir is unavailable for this selection. ISLAM 307 never generates tafsir with AI.';

  Future<List<Map<String, dynamic>>> catalogSources() => _catalog.allTafsirs();

  Future<List<Map<String, dynamic>>> sources() async {
    final db = await _registry.open('tafsir');
    return db.query('sources', orderBy: 'sort_order ASC');
  }

  Future<Map<String, dynamic>?> entry(String sourceSlug, int surah, int ayah) async {
    final catalog = await _catalog.allTafsirs();
    Map<String, dynamic>? meta;
    for (final s in catalog) {
      if (s['slug'] == sourceSlug) {
        meta = s;
        break;
      }
    }
    if (meta == null) return null;
    if (meta['installed'] != true) {
      return {
        'unavailable': true,
        'message': unavailableMessage,
        'source_name': meta['name_en'],
        'slug': sourceSlug,
        'surah_number': surah,
        'ayah_number': ayah,
        'notes': meta['notes'],
      };
    }

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
    if (rows.isEmpty) {
      return {
        'unavailable': true,
        'message': unavailableMessage,
        'source_name': meta['name_en'],
        'slug': sourceSlug,
        'surah_number': surah,
        'ayah_number': ayah,
        'notes': 'No authenticated entry found in the offline pack for $surah:$ayah.',
      };
    }
    return rows.first;
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
