import 'dart:convert';

import 'package:flutter/services.dart';

class AssetKnowledgeHit {
  const AssetKnowledgeHit({
    required this.title,
    required this.excerpt,
    required this.reference,
  });

  final String title;
  final String excerpt;
  final String reference;
}

/// Searches every bundled module JSON listed by Flutter's runtime asset
/// manifest. Newly added module records become searchable without AI changes.
class LocalAssetKnowledgeSearch {
  Future<List<AssetKnowledgeHit>> search(
    String query, {
    int limit = 12,
  }) async {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return const [];
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest
        .listAssets()
        .where(
          (asset) =>
              asset.startsWith('assets/modules/') &&
              asset.endsWith('.json'),
        )
        .toList()
      ..sort();
    final hits = <AssetKnowledgeHit>[];
    for (final asset in assets) {
      try {
        final decoded = jsonDecode(await rootBundle.loadString(asset));
        final values = <(String, String)>[];
        _flatten(decoded, r'$', values);
        for (final entry in values) {
          if (!entry.$2.toLowerCase().contains(clean)) continue;
          hits.add(AssetKnowledgeHit(
            title: asset.split('/').last.replaceAll('.json', ''),
            excerpt: entry.$2,
            reference: '$asset · ${entry.$1}',
          ));
          if (hits.length >= limit) return hits;
        }
      } catch (_) {
        // Invalid optional metadata is ignored, never guessed.
      }
    }
    return hits;
  }

  void _flatten(
    dynamic value,
    String path,
    List<(String, String)> output,
  ) {
    if (value is Map) {
      for (final entry in value.entries) {
        _flatten(entry.value, '$path.${entry.key}', output);
      }
    } else if (value is List) {
      for (var i = 0; i < value.length; i++) {
        _flatten(value[i], '$path[$i]', output);
      }
    } else if (value is String && value.trim().isNotEmpty) {
      output.add((path, value.trim()));
    }
  }
}
