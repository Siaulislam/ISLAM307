import '../tafsir/legacy_tafsir_cleanup.dart';
import '../tafsir/quran_verse_validator.dart';
import '../tafsir/tafsir_models.dart';

/// Offline-only Tafseer facade.
///
/// Provider code is retained for a future user-triggered licensed update
/// workflow, but normal reading never calls an internet API.
class TafsirRepository {
  static const unavailableMessage =
      'Offline Tafseer is permission pending. No content is installed, streamed, or generated.';

  Future<List<Map<String, dynamic>>> catalogSources() async {
    await LegacyTafsirCleanup.run();
    return requestedTafsirSources
        .map(
          (source) => source.toCatalogMap(
            unavailableReason:
                '${source.licenseNote} Permanent offline commercial redistribution permission is required.',
          ),
        )
        .toList();
  }

  Future<List<Map<String, dynamic>>> sources() => catalogSources();

  Future<Map<String, dynamic>?> entry(
    String sourceSlug,
    int surah,
    int ayah,
  ) async {
    await LegacyTafsirCleanup.run();
    return {
      'unavailable': true,
      'message': QuranVerseValidator.isValid(surah, ayah)
          ? unavailableMessage
          : 'Invalid Quran verse reference: $surah:$ayah.',
      'source_name': 'Offline Tafseer',
      'author': 'Permission pending',
      'source': 'No dataset installed',
      'language': '—',
      'slug': sourceSlug,
      'source_slug': sourceSlug,
      'surah_number': surah,
      'ayah_number': ayah,
      'citation': 'Quran $surah:$ayah',
      'notes': 'See LICENSES/tafsir.md and LICENSE_REQUEST.md.',
      'retryable': false,
    };
  }

  Future<List<Map<String, dynamic>>> search(
    String query, {
    int limit = 30,
  }) async {
    return const [];
  }
}
