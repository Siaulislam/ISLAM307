import 'dart:convert';
import 'package:flutter/services.dart';

/// Manifest-driven kitab icons — no hardcoded book list in UI.
class KitabIconRegistry {
  KitabIconRegistry._();
  static final KitabIconRegistry instance = KitabIconRegistry._();

  static const _manifestPath = 'assets/branding/hadith/kitab_icons.json';
  List<KitabIconSpec>? _cache;

  Future<List<KitabIconSpec>> load() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString(_manifestPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    _cache = (json['books'] as List)
        .map((e) => KitabIconSpec.fromJson(e as Map<String, dynamic>))
        .toList();
    return _cache!;
  }

  Future<KitabIconSpec?> bySlug(String slug) async {
    final all = await load();
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
    required this.shortAr,
  });

  factory KitabIconSpec.fromJson(Map<String, dynamic> j) => KitabIconSpec(
        slug: j['slug'] as String,
        nameEn: j['name_en'] as String,
        nameAr: j['name_ar'] as String,
        assetPath: 'assets/branding/hadith/${j['icon_file']}',
        accent: j['accent'] as String,
        accentSoft: j['accent_soft'] as String,
        badge: j['badge'] as String,
        shortAr: j['short_ar'] as String,
      );

  final String slug;
  final String nameEn;
  final String nameAr;
  final String assetPath;
  final String accent;
  final String accentSoft;
  final String badge;
  final String shortAr;
}
