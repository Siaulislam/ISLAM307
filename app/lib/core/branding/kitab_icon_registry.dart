import 'dart:convert';
import 'package:flutter/services.dart';

/// Manifest-driven book icons — no hardcoded list in UI.
class KitabIconRegistry {
  KitabIconRegistry._();
  static final KitabIconRegistry instance = KitabIconRegistry._();

  static const _manifestPath = 'assets/branding/books/books_manifest.json';
  static const _hadithManifestPath = 'assets/branding/hadith/kitab_icons.json';
  List<KitabIconSpec>? _allCache;
  List<KitabIconSpec>? _hadithCache;

  Future<List<KitabIconSpec>> load({bool hadithOnly = false}) async {
    if (hadithOnly) {
      if (_hadithCache != null) return _hadithCache!;
      _hadithCache = await _loadManifest(_hadithManifestPath);
      return _hadithCache!;
    }
    if (_allCache != null) return _allCache!;
    _allCache = await _loadManifest(_manifestPath);
    return _allCache!;
  }

  Future<List<KitabIconSpec>> _loadManifest(String path) async {
    final raw = await rootBundle.loadString(path);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final base = json['icon_base_path'] as String? ?? 'books';
    return (json['books'] as List)
        .map((e) => KitabIconSpec.fromJson(e as Map<String, dynamic>, base: base))
        .toList();
  }

  Future<KitabIconSpec?> bySlug(String slug, {bool hadithOnly = false}) async {
    final all = await load(hadithOnly: hadithOnly);
    for (final b in all) {
      if (b.slug == slug) return b;
    }
    return null;
  }
}

class KitabIconSpec {
  const KitabIconSpec({
    required this.slug,
    required this.nameEn,
    required this.nameAr,
    required this.assetPath,
    required this.accent,
    required this.accentSoft,
    required this.badge,
  });

  factory KitabIconSpec.fromJson(Map<String, dynamic> j, {String base = 'books'}) =>
      KitabIconSpec(
        slug: j['slug'] as String,
        nameEn: j['name_en'] as String,
        nameAr: j['name_ar'] as String,
        assetPath: 'assets/branding/$base/${j['icon_file']}',
        accent: (j['accent'] as String?) ?? '#0F8B5F',
        accentSoft: (j['accent_soft'] as String?) ?? '#ecfdf5',
        badge: (j['badge'] as String?) ?? '',
      );

  final String slug;
  final String nameEn;
  final String nameAr;
  final String assetPath;
  final String accent;
  final String accentSoft;
  final String badge;
}
