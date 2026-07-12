import 'dart:convert';
import 'package:flutter/services.dart';

/// Loads modular catalogs so translations, tafsirs, hadith books, and reciters
/// can be extended without hardcoding feature screens.
class ModuleCatalog {
  ModuleCatalog._();
  static final ModuleCatalog instance = ModuleCatalog._();

  Map<String, dynamic>? _translations;
  Map<String, dynamic>? _tafsirs;
  Map<String, dynamic>? _hadith;
  Map<String, dynamic>? _audio;
  Map<String, dynamic>? _narrators;

  Future<Map<String, dynamic>> quranTranslations() async {
    _translations ??= jsonDecode(await rootBundle.loadString('assets/modules/quran_translations.json')) as Map<String, dynamic>;
    return _translations!;
  }

  Future<Map<String, dynamic>> tafsirSources() async {
    _tafsirs ??= jsonDecode(await rootBundle.loadString('assets/modules/tafsir_sources.json')) as Map<String, dynamic>;
    return _tafsirs!;
  }

  Future<Map<String, dynamic>> hadithCollections() async {
    _hadith ??= jsonDecode(await rootBundle.loadString('assets/modules/hadith_collections.json')) as Map<String, dynamic>;
    return _hadith!;
  }

  Future<Map<String, dynamic>> audioReciters() async {
    _audio ??= jsonDecode(await rootBundle.loadString('assets/modules/audio_reciters.json')) as Map<String, dynamic>;
    return _audio!;
  }

  Future<Map<String, dynamic>> narratorSources() async {
    _narrators ??= jsonDecode(await rootBundle.loadString('assets/modules/narrators_sources.json')) as Map<String, dynamic>;
    return _narrators!;
  }

  Future<List<String>> enabledHadithSlugs() async {
    final m = await hadithCollections();
    return (m['enabled_slugs'] as List).cast<String>();
  }

  Future<List<Map<String, dynamic>>> installedTafsirs() async {
    final m = await tafsirSources();
    return (m['sources'] as List)
        .cast<Map<String, dynamic>>()
        .where((s) => s['installed'] == true)
        .toList();
  }

  Future<List<Map<String, dynamic>>> allTafsirs() async {
    final m = await tafsirSources();
    return (m['sources'] as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> allNarratorSources() async {
    final m = await narratorSources();
    return (m['sources'] as List).cast<Map<String, dynamic>>();
  }
}
