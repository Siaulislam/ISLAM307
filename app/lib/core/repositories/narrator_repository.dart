import '../database/database_registry.dart';
import '../modules/module_catalog.dart';

/// Offline narrator biography lookup — authenticated packs only.
///
/// Primary hadith narrator *names* come from [HadithRepository] (Sunnah.com /
/// licensed hadith.db). This repository never invents names or biographies.
/// When a licensed `narrators.db` pack is not installed, callers receive an
/// explicit unavailable result so the UI can show the offline message.
class NarratorRepository {
  NarratorRepository(this._registry, {ModuleCatalog? catalog})
      : _catalog = catalog ?? ModuleCatalog.instance;

  final DatabaseRegistry _registry;
  final ModuleCatalog _catalog;

  /// Exact product copy required by Narrator Data Policy when bio pack is absent.
  static const offlineUnavailableMessage =
      'Additional narrator information is not available offline.';

  static const policyNeverInvent =
      'ISLAM 307 never generates narrator biographies with AI. '
      'Only authenticated, licensed offline packs are shown.';

  Future<Map<String, dynamic>> catalog() => _catalog.narratorSources();

  Future<bool> isBiographyPackInstalled() async {
    final sources = await _catalog.allNarratorSources();
    return sources.any((s) => s['slug'] == 'licensed-rijal' && s['installed'] == true);
  }

  /// Lookup biography / type for a display name from the hadith chain.
  /// Returns a map with either authenticated fields or `{unavailable: true, message: …}`.
  Future<Map<String, dynamic>> lookup(String displayName, {String lang = 'en'}) async {
    final name = displayName.trim();
    if (name.isEmpty) {
      return {
        'unavailable': true,
        'message': offlineUnavailableMessage,
        'notes': 'No authenticated narrator name was provided for this hadith.',
        'policy': policyNeverInvent,
      };
    }

    final catalog = await catalog();
    final message = (catalog['offline_unavailable_message'] as String?)?.trim().isNotEmpty == true
        ? catalog['offline_unavailable_message'] as String
        : offlineUnavailableMessage;

    if (!await isBiographyPackInstalled()) {
      return {
        'unavailable': true,
        'message': message,
        'name': name,
        'notes': 'Licensed narrator biography pack is not installed.',
        'policy': policyNeverInvent,
      };
    }

    if (!_registry.isRegistered('narrators')) {
      return {
        'unavailable': true,
        'message': message,
        'name': name,
        'notes': 'narrators.db is not registered in DatabaseRegistry.',
        'policy': policyNeverInvent,
      };
    }

    try {
      final db = await _registry.open('narrators');
      final normalized = normalizeNarratorKey(name);
      final rows = await db.rawQuery(
        '''
        SELECT n.*, s.name_en AS source_name, s.attribution AS source_attribution, s.url AS source_url
        FROM name_aliases a
        JOIN narrators n ON n.id = a.narrator_id
        LEFT JOIN sources s ON s.id = n.source_id
        WHERE a.alias_normalized = ?
        LIMIT 1
        ''',
        [normalized],
      );
      if (rows.isEmpty) {
        return {
          'unavailable': true,
          'message': message,
          'name': name,
          'notes': 'No licensed biography matched this authenticated narrator name.',
          'policy': policyNeverInvent,
        };
      }
      final row = Map<String, dynamic>.from(rows.first);
      row['unavailable'] = false;
      row['requested_name'] = name;
      row['display_bio'] = _bioForLang(row, lang);
      row['display_name'] = _nameForLang(row, lang) ?? name;
      return row;
    } catch (_) {
      return {
        'unavailable': true,
        'message': message,
        'name': name,
        'notes': 'Narrator database could not be opened.',
        'policy': policyNeverInvent,
      };
    }
  }

  static String? _nameForLang(Map<String, dynamic> row, String lang) {
    if (lang == 'ar') return (row['name_ar'] as String?)?.trim();
    if (lang == 'ur') return (row['name_ur'] as String?)?.trim();
    return (row['name_en'] as String?)?.trim();
  }

  static String? _bioForLang(Map<String, dynamic> row, String lang) {
    if (lang == 'ar') return (row['bio_ar'] as String?)?.trim();
    if (lang == 'ur') return (row['bio_ur'] as String?)?.trim();
    return (row['bio_en'] as String?)?.trim();
  }

  /// Fold display names for alias matching — does not invent content.
  static String normalizeNarratorKey(String raw) {
    var s = raw.trim().toLowerCase();
    s = s.replaceAll(RegExp(r"[ʼ'`´]"), "'");
    s = s.replaceAll(RegExp(r'[^\w\u0600-\u06ff\s-]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }
}
