import '../tafsir/legacy_tafsir_cleanup.dart';
import '../tafsir/tafsir_provider.dart';
import '../tafsir/tafsir_provider_registry.dart';

class TafsirRepository {
  TafsirRepository({TafsirProviderRegistry? providers})
      : _providers = providers ?? TafsirProviderRegistry.instance;

  final TafsirProviderRegistry _providers;

  static const unavailableMessage =
      'Licensed Tafseer is unavailable for this selection. ISLAM 307 never generates Tafseer with AI.';

  Future<List<Map<String, dynamic>>> catalogSources() async {
    await LegacyTafsirCleanup.run();
    return _providers.catalog();
  }

  Future<List<Map<String, dynamic>>> sources() => catalogSources();

  Future<Map<String, dynamic>?> entry(
    String sourceSlug,
    int surah,
    int ayah,
  ) async {
    final catalog = await catalogSources();
    Map<String, dynamic>? meta;
    for (final s in catalog) {
      if (s['slug'] == sourceSlug) {
        meta = s;
        break;
      }
    }
    if (meta == null) return null;
    if (meta['available'] != true) {
      return _unavailable(meta, sourceSlug, surah, ayah);
    }

    try {
      final entry = await _providers.fetch(sourceSlug, surah, ayah);
      return entry.toMap();
    } on TafsirProviderException catch (error) {
      return _unavailable(
        meta,
        sourceSlug,
        surah,
        ayah,
        message: error.message,
        retryable: error.retryable,
      );
    } catch (_) {
      return _unavailable(
        meta,
        sourceSlug,
        surah,
        ayah,
        message:
            'The official Tafseer service could not be reached. No substitute text was generated.',
        retryable: true,
      );
    }
  }

  /// Remote full-corpus search is deliberately unsupported. It would require
  /// scraping or maintaining a local Tafseer index, both forbidden by policy.
  Future<List<Map<String, dynamic>>> search(String query, {int limit = 30}) async {
    return const [];
  }

  Map<String, dynamic> _unavailable(
    Map<String, dynamic> meta,
    String sourceSlug,
    int surah,
    int ayah, {
    String? message,
    bool retryable = false,
  }) {
    return {
      'unavailable': true,
      'message': message ?? unavailableMessage,
      'source_name': meta['name_en'],
      'author': meta['author'],
      'source': meta['provider_name'] ?? 'Quran Foundation Content API',
      'language': meta['language'],
      'slug': sourceSlug,
      'source_slug': sourceSlug,
      'surah_number': surah,
      'ayah_number': ayah,
      'citation': 'Quran $surah:$ayah',
      'notes': meta['notes'],
      'retryable': retryable,
    };
  }
}
