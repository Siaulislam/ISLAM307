import 'tafsir_http_transport_base.dart';

class UnsupportedTafsirHttpTransport implements TafsirHttpTransport {
  @override
  Future<TafsirHttpResponse> get(
    Uri uri, {
    Map<String, String> headers = const {},
  }) {
    throw UnsupportedError(
      'No HTTP Tafseer transport is available on this platform.',
    );
  }
}

TafsirHttpTransport createPlatformTafsirHttpTransport() =>
    UnsupportedTafsirHttpTransport();
