// ignore_for_file: deprecated_member_use

import 'dart:html' as html;

import 'tafsir_http_transport_base.dart';

class WebTafsirHttpTransport implements TafsirHttpTransport {
  @override
  Future<TafsirHttpResponse> get(
    Uri uri, {
    Map<String, String> headers = const {},
  }) async {
    final response = await html.HttpRequest.request(
      uri.toString(),
      method: 'GET',
      requestHeaders: {
        ...headers,
        'Accept': 'application/json',
      },
    );
    return TafsirHttpResponse(response.status ?? 0, response.responseText ?? '');
  }
}

TafsirHttpTransport createPlatformTafsirHttpTransport() =>
    WebTafsirHttpTransport();
