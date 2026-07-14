import 'tafsir_models.dart';

abstract class TafsirProvider {
  String get id;
  String get displayName;

  Future<List<Map<String, dynamic>>> catalog(
    List<TafsirSourceDefinition> requested,
  );

  Future<TafsirEntry> fetch({
    required TafsirSourceDefinition source,
    required int surah,
    required int ayah,
  });

  void refresh();
}

class TafsirProviderException implements Exception {
  const TafsirProviderException(this.message, {this.retryable = false});

  final String message;
  final bool retryable;

  @override
  String toString() => message;
}
