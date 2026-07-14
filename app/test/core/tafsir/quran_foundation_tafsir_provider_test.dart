import 'package:flutter_test/flutter_test.dart';
import 'package:islam307/core/tafsir/quran_foundation_tafsir_provider.dart';
import 'package:islam307/core/tafsir/tafsir_models.dart';

class _Request {
  const _Request(this.uri, this.headers);
  final Uri uri;
  final Map<String, String> headers;
}

class _FakeTransport implements TafsirHttpTransport {
  _FakeTransport({
    this.resourcesBody =
        '{"tafsirs":[{"id":999,"name":"Tafsir Ibn Kathir",'
        '"author_name":"Hafiz Ibn Kathir",'
        '"slug":"en-tafsir-ibn-kathir","language_name":"english",'
        '"translated_name":{"name":"Tafsir Ibn Kathir"}}]}',
    this.tafsirBody =
        '{"tafsirs":[{"resource_id":999,"verse_key":"2:255",'
        '"language_name":"english","resource_name":"Tafsir Ibn Kathir",'
        '"text":"<p>Authenticated explanation.</p>"}],'
        '"meta":{"tafsir_name":"Tafsir Ibn Kathir",'
        '"author_name":"Hafiz Ibn Kathir"}}',
  });

  final String resourcesBody;
  final String tafsirBody;
  final requests = <_Request>[];

  @override
  Future<TafsirHttpResponse> get(
    Uri uri, {
    Map<String, String> headers = const {},
  }) async {
    requests.add(_Request(uri, headers));
    if (uri.path.endsWith('/resources/tafsirs')) {
      return TafsirHttpResponse(200, resourcesBody);
    }
    return TafsirHttpResponse(200, tafsirBody);
  }
}

void main() {
  test('discovers resource IDs and fetches attributed Tafseer', () async {
    final transport = _FakeTransport();
    final provider = QuranFoundationTafsirProvider(
      config: const QuranFoundationApiConfig(
        apiBaseUrl: 'https://apis.quran.foundation',
        clientId: 'approved-client',
        accessToken: 'short-lived-token',
        tokenBrokerUrl: '',
      ),
      transport: transport,
    );

    final catalog = await provider.catalog(requestedTafsirSources);
    final ibnKathir =
        catalog.firstWhere((source) => source['slug'] == 'ibn-kathir');
    expect(ibnKathir['available'], isTrue);
    expect(ibnKathir['api_resource_id'], 999);

    final definition = requestedTafsirSources
        .firstWhere((source) => source.slug == 'ibn-kathir');
    final entry = await provider.fetch(
      source: definition,
      surah: 2,
      ayah: 255,
    );
    expect(entry.text, 'Authenticated explanation.');
    expect(entry.author, 'Hafiz Ibn Kathir');
    expect(entry.provider, 'Quran Foundation Content API');
    expect(entry.citation, contains('Quran 2:255'));
    expect(transport.requests, hasLength(2));
    expect(
      transport.requests.last.headers,
      containsPair('x-client-id', 'approved-client'),
    );
    expect(
      transport.requests.last.headers,
      containsPair('x-auth-token', 'short-lived-token'),
    );

    await provider.fetch(source: definition, surah: 2, ayah: 255);
    expect(transport.requests, hasLength(2), reason: 'ten-minute memory cache');
  });

  test('reports unavailable when credentials are absent', () async {
    final provider = QuranFoundationTafsirProvider(
      config: const QuranFoundationApiConfig(
        apiBaseUrl: 'https://apis.quran.foundation',
        clientId: '',
        accessToken: '',
        tokenBrokerUrl: '',
      ),
      transport: _FakeTransport(),
    );
    final catalog = await provider.catalog(requestedTafsirSources);
    expect(catalog.every((source) => source['available'] == false), isTrue);
  });

  test('rejects a response for the wrong verse or resource', () async {
    final transport = _FakeTransport(
      tafsirBody:
          '{"tafsirs":[{"resource_id":1000,"verse_key":"2:256",'
          '"text":"Wrong text"}]}',
    );
    final provider = QuranFoundationTafsirProvider(
      config: const QuranFoundationApiConfig(
        apiBaseUrl: 'https://apis.quran.foundation',
        clientId: 'approved-client',
        accessToken: 'short-lived-token',
        tokenBrokerUrl: '',
      ),
      transport: transport,
    );
    await provider.catalog(requestedTafsirSources);
    final definition = requestedTafsirSources
        .firstWhere((source) => source.slug == 'ibn-kathir');
    await expectLater(
      provider.fetch(source: definition, surah: 2, ayah: 255),
      throwsA(isA<Exception>()),
    );
  });

  test('refuses ambiguous matching resources', () async {
    final transport = _FakeTransport(
      resourcesBody:
          '{"tafsirs":['
          '{"id":999,"name":"Tafsir Ibn Kathir",'
          '"author_name":"Hafiz Ibn Kathir",'
          '"slug":"en-tafsir-ibn-kathir","language_name":"english"},'
          '{"id":1000,"name":"Tafsir Ibn Kathir",'
          '"author_name":"Hafiz Ibn Kathir",'
          '"slug":"en-tafsir-ibn-kathir","language_name":"english"}'
          ']}',
    );
    final provider = QuranFoundationTafsirProvider(
      config: const QuranFoundationApiConfig(
        apiBaseUrl: 'https://apis.quran.foundation',
        clientId: 'approved-client',
        accessToken: 'short-lived-token',
        tokenBrokerUrl: '',
      ),
      transport: transport,
    );
    final catalog = await provider.catalog(requestedTafsirSources);
    final ibnKathir =
        catalog.firstWhere((source) => source['slug'] == 'ibn-kathir');
    expect(ibnKathir['available'], isFalse);
    expect('${ibnKathir['notes']}', contains('multiple matching'));
  });
}
