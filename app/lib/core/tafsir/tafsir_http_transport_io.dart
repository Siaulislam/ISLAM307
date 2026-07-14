import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'tafsir_http_transport_base.dart';

class IoTafsirHttpTransport implements TafsirHttpTransport {
  IoTafsirHttpTransport({HttpClient? client})
      : _client = client ?? HttpClient() {
    _client.connectionTimeout = const Duration(seconds: 15);
    _client.userAgent = 'ISLAM307/1.0 QuranFoundation-Tafsir';
  }

  final HttpClient _client;

  @override
  Future<TafsirHttpResponse> get(
    Uri uri, {
    Map<String, String> headers = const {},
  }) async {
    final request =
        await _client.getUrl(uri).timeout(const Duration(seconds: 20));
    headers.forEach(request.headers.set);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close().timeout(const Duration(seconds: 30));
    final body = await utf8.decoder.bind(response).join();
    return TafsirHttpResponse(response.statusCode, body);
  }
}

TafsirHttpTransport createPlatformTafsirHttpTransport() =>
    IoTafsirHttpTransport();
