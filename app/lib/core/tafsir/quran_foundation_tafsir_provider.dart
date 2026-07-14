import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'tafsir_models.dart';
import 'tafsir_provider.dart';

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
    final request = await _client.getUrl(uri).timeout(const Duration(seconds: 20));
    headers.forEach(request.headers.set);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close().timeout(const Duration(seconds: 30));
    final body = await utf8.decoder.bind(response).join();
    return TafsirHttpResponse(response.statusCode, body);
  }
}

class QuranFoundationApiConfig {
  const QuranFoundationApiConfig({
    required this.apiBaseUrl,
    required this.clientId,
    required this.accessToken,
    required this.tokenBrokerUrl,
  });

  factory QuranFoundationApiConfig.fromEnvironment() {
    return const QuranFoundationApiConfig(
      apiBaseUrl: String.fromEnvironment(
        'QF_API_BASE_URL',
        defaultValue: 'https://apis.quran.foundation',
      ),
      clientId: String.fromEnvironment('QF_CLIENT_ID'),
      accessToken: String.fromEnvironment('QF_ACCESS_TOKEN'),
      tokenBrokerUrl: String.fromEnvironment('QF_TOKEN_BROKER_URL'),
    );
  }

  final String apiBaseUrl;
  final String clientId;
  final String accessToken;
  final String tokenBrokerUrl;

  bool get isConfigured =>
      (clientId.trim().isNotEmpty && accessToken.trim().isNotEmpty) ||
      tokenBrokerUrl.trim().isNotEmpty;
}

class _ApiCredentials {
  const _ApiCredentials({
    required this.clientId,
    required this.accessToken,
    required this.expiresAt,
  });

  final String clientId;
  final String accessToken;
  final DateTime expiresAt;

  bool get isUsable =>
      clientId.isNotEmpty &&
      accessToken.isNotEmpty &&
      DateTime.now().isBefore(expiresAt.subtract(const Duration(minutes: 2)));
}

class _CachedEntry {
  const _CachedEntry(this.entry, this.fetchedAt);

  final TafsirEntry entry;
  final DateTime fetchedAt;
}

/// Runtime-only Quran Foundation integration.
///
/// The OAuth client secret must stay on a backend. This client accepts either:
/// 1) a short-lived client id/access token pair through dart-define, or
/// 2) a secure token broker URL that returns access_token, client_id, expires_in.
///
/// Tafsir text is cached in memory for ten minutes and is never written to disk.
class QuranFoundationTafsirProvider implements TafsirProvider {
  QuranFoundationTafsirProvider({
    QuranFoundationApiConfig? config,
    TafsirHttpTransport? transport,
  })  : _config = config ?? QuranFoundationApiConfig.fromEnvironment(),
        _transport = transport ?? IoTafsirHttpTransport();

  final QuranFoundationApiConfig _config;
  final TafsirHttpTransport _transport;

  _ApiCredentials? _credentials;
  Future<List<TafsirApiResource>>? _resourceRequest;
  final Map<String, TafsirApiResource> _resolvedResources = {};
  final Map<String, _CachedEntry> _entryCache = {};

  @override
  String get id => 'quran_foundation';

  @override
  String get displayName => 'Quran Foundation Content API';

  @override
  Future<List<Map<String, dynamic>>> catalog(
    List<TafsirSourceDefinition> requested,
  ) async {
    if (!_config.isConfigured) {
      return requested
          .map(
            (source) => source.toCatalogMap(
              unavailableReason:
                  '${source.licenseNote} Quran Foundation API credentials are not configured.',
            ),
          )
          .toList();
    }

    try {
      final resources = await _resources();
      _resolvedResources.clear();
      for (final source in requested) {
        final matches = resources.where(source.matchesApiResource).toList();
        if (matches.isEmpty) continue;
        matches.sort((a, b) {
          final aPreferred =
              a.language.toLowerCase() == source.preferredLanguage.toLowerCase();
          final bPreferred =
              b.language.toLowerCase() == source.preferredLanguage.toLowerCase();
          if (aPreferred == bPreferred) return a.id.compareTo(b.id);
          return aPreferred ? -1 : 1;
        });
        _resolvedResources[source.slug] = matches.first;
      }

      return requested
          .map(
            (source) => source.toCatalogMap(
              resource: _resolvedResources[source.slug],
              unavailableReason:
                  '${source.licenseNote} This work is not present in the authorized API resource registry.',
            ),
          )
          .toList();
    } on TafsirProviderException catch (error) {
      return requested
          .map(
            (source) => source.toCatalogMap(
              unavailableReason: '${source.licenseNote} ${error.message}',
            ),
          )
          .toList();
    }
  }

  @override
  Future<TafsirEntry> fetch({
    required TafsirSourceDefinition source,
    required int surah,
    required int ayah,
  }) async {
    if (surah < 1 || surah > 114 || ayah < 1) {
      throw const TafsirProviderException('Invalid Quran verse reference.');
    }
    if (!_config.isConfigured) {
      throw const TafsirProviderException(
        'Quran Foundation API access is not configured. No local Tafseer copy is used.',
      );
    }

    if (!_resolvedResources.containsKey(source.slug)) {
      await catalog(requestedTafsirSources);
    }
    final resource = _resolvedResources[source.slug];
    if (resource == null) {
      throw TafsirProviderException(
        '${source.name} is unavailable because no authorized API resource was returned.',
      );
    }

    final cacheKey = '${source.slug}:$surah:$ayah';
    final cached = _entryCache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) <
            const Duration(minutes: 10)) {
      return cached.entry;
    }

    final payload = await _authorizedGet(
      '/content/api/v4/quran/tafsirs/${resource.id}',
      query: {'verse_key': '$surah:$ayah', 'per_page': '1'},
    );
    final rows = payload['tafsirs'];
    if (rows is! List || rows.isEmpty || rows.first is! Map) {
      throw TafsirProviderException(
        'No licensed ${source.name} entry was returned for $surah:$ayah.',
      );
    }
    final row = Map<String, dynamic>.from(rows.first as Map);
    final rawText = '${row['text'] ?? ''}'.trim();
    final text = _plainText(rawText);
    if (text.isEmpty) {
      throw TafsirProviderException(
        'The official API returned an empty ${source.name} entry for $surah:$ayah.',
      );
    }
    final meta = payload['meta'] is Map
        ? Map<String, dynamic>.from(payload['meta'] as Map)
        : const <String, dynamic>{};
    final sourceName =
        '${row['resource_name'] ?? meta['tafsir_name'] ?? resource.name}'.trim();
    final author =
        '${meta['author_name'] ?? resource.author ?? source.author}'.trim();
    final language = '${row['language_name'] ?? resource.language}'.trim();
    final verseKey = '${row['verse_key'] ?? '$surah:$ayah'}'.trim();
    final entry = TafsirEntry(
      sourceSlug: source.slug,
      sourceName: sourceName.isEmpty ? source.name : sourceName,
      author: author.isEmpty ? source.author : author,
      provider: displayName,
      language: language.isEmpty ? source.preferredLanguage : language,
      surah: surah,
      ayah: ayah,
      text: text,
      citation:
          '${sourceName.isEmpty ? source.name : sourceName} · Quran $verseKey · Quran Foundation resource ${resource.id}',
      referenceUrl:
          'https://quran.com/$surah:$ayah/tafsirs/${resource.slug}',
      resourceId: resource.id,
    );
    _entryCache[cacheKey] = _CachedEntry(entry, DateTime.now());
    return entry;
  }

  Future<List<TafsirApiResource>> _resources() {
    return _resourceRequest ??= _loadResources();
  }

  Future<List<TafsirApiResource>> _loadResources() async {
    final payload =
        await _authorizedGet('/content/api/v4/resources/tafsirs');
    final rows = payload['tafsirs'];
    if (rows is! List) {
      throw const TafsirProviderException(
        'The official Tafseer resource registry returned an invalid response.',
      );
    }
    return rows
        .whereType<Map>()
        .map((row) => TafsirApiResource.fromJson(
              Map<String, dynamic>.from(row),
            ))
        .toList();
  }

  Future<Map<String, dynamic>> _authorizedGet(
    String path, {
    Map<String, String> query = const {},
    bool retryAfterUnauthorized = true,
  }) async {
    final credentials = await _getCredentials();
    final uri = Uri.parse(_config.apiBaseUrl).replace(
      path: path,
      queryParameters: query.isEmpty ? null : query,
    );
    final response = await _transport.get(
      uri,
      headers: {
        'x-auth-token': credentials.accessToken,
        'x-client-id': credentials.clientId,
      },
    );
    if ((response.statusCode == 401 || response.statusCode == 403) &&
        retryAfterUnauthorized &&
        _config.tokenBrokerUrl.isNotEmpty) {
      _credentials = null;
      return _authorizedGet(
        path,
        query: query,
        retryAfterUnauthorized: false,
      );
    }
    if (response.statusCode == 429) {
      throw const TafsirProviderException(
        'The official Tafseer API rate limit was reached. Please retry later.',
        retryable: true,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TafsirProviderException(
        'The official Tafseer API request failed (${response.statusCode}).',
        retryable: response.statusCode >= 500,
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const TafsirProviderException(
        'The official Tafseer API returned invalid data.',
      );
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<_ApiCredentials> _getCredentials() async {
    final current = _credentials;
    if (current != null && current.isUsable) return current;

    if (_config.clientId.isNotEmpty && _config.accessToken.isNotEmpty) {
      return _credentials = _ApiCredentials(
        clientId: _config.clientId,
        accessToken: _config.accessToken,
        expiresAt: DateTime.now().add(const Duration(minutes: 55)),
      );
    }

    if (_config.tokenBrokerUrl.isEmpty) {
      throw const TafsirProviderException(
        'Quran Foundation API credentials are not configured.',
      );
    }
    final response = await _transport.get(Uri.parse(_config.tokenBrokerUrl));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TafsirProviderException(
        'The secure Quran Foundation token broker is unavailable (${response.statusCode}).',
        retryable: true,
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const TafsirProviderException(
        'The secure token broker returned invalid data.',
      );
    }
    final token = '${decoded['access_token'] ?? ''}'.trim();
    final clientId = '${decoded['client_id'] ?? ''}'.trim();
    final expiresIn = decoded['expires_in'] is num
        ? (decoded['expires_in'] as num).toInt()
        : 3600;
    final next = _ApiCredentials(
      clientId: clientId,
      accessToken: token,
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
    );
    if (!next.isUsable) {
      throw const TafsirProviderException(
        'The secure token broker did not return usable short-lived credentials.',
      );
    }
    return _credentials = next;
  }

  static String _plainText(String html) {
    var text = html
        .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
        .replaceAll(
          RegExp(r'</\s*(p|h[1-6]|li|div)\s*>', caseSensitive: false),
          '\n',
        )
        .replaceAll(RegExp(r'<[^>]+>'), '');
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAllMapped(
          RegExp(r'&#(\d+);'),
          (match) => String.fromCharCode(int.parse(match.group(1)!)),
        )
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }
}
