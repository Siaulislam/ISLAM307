import 'quran_foundation_tafsir_provider.dart';
import 'tafsir_models.dart';
import 'tafsir_provider.dart';

class TafsirProviderRegistry {
  TafsirProviderRegistry({TafsirProvider? quranFoundation})
      : _quranFoundation =
            quranFoundation ?? QuranFoundationTafsirProvider();

  static final TafsirProviderRegistry instance = TafsirProviderRegistry();

  final TafsirProvider _quranFoundation;
  Future<List<Map<String, dynamic>>>? _catalogRequest;

  Future<List<Map<String, dynamic>>> catalog() {
    return _catalogRequest ??=
        _quranFoundation.catalog(requestedTafsirSources);
  }

  Future<TafsirEntry> fetch(
    String sourceSlug,
    int surah,
    int ayah,
  ) async {
    TafsirSourceDefinition? definition;
    for (final source in requestedTafsirSources) {
      if (source.slug == sourceSlug) {
        definition = source;
        break;
      }
    }
    if (definition == null) {
      throw TafsirProviderException(
        'Unknown Tafseer source: $sourceSlug.',
      );
    }
    return _quranFoundation.fetch(
      source: definition,
      surah: surah,
      ayah: ayah,
    );
  }

  void refreshCatalog() {
    _catalogRequest = null;
  }
}
