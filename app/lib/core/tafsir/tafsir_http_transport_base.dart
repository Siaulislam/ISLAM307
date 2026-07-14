class TafsirHttpResponse {
  const TafsirHttpResponse(this.statusCode, this.body);

  final int statusCode;
  final String body;
}

abstract class TafsirHttpTransport {
  Future<TafsirHttpResponse> get(
    Uri uri, {
    Map<String, String> headers = const {},
  });
}
