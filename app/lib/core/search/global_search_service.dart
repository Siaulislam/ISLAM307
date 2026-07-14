import '../database/user_database.dart';
import '../datasets/dataset_license_registry.dart';
import '../repositories/quran_repository.dart';
import '../repositories/quran_word_repository.dart';

class GlobalSearchHit {
  GlobalSearchHit({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final String kind;
  final String title;
  final String subtitle;
  final String route;
}

class GlobalSearchService {
  GlobalSearchService({
    QuranRepository? quran,
    QuranWordRepository? words,
    UserDatabase? userDatabase,
  })  : _quran = quran ?? QuranRepository(),
        _words = words ?? QuranWordRepository(),
        _userDatabase = userDatabase ?? UserDatabase.instance;

  final QuranRepository _quran;
  final QuranWordRepository _words;
  final UserDatabase _userDatabase;

  Future<List<GlobalSearchHit>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final hits = <GlobalSearchHit>[];

    for (final feature in await DatasetLicenseRegistry.instance.features()) {
      if (feature.title.toLowerCase().contains(q.toLowerCase())) {
        hits.add(GlobalSearchHit(
          kind: 'Feature',
          title: feature.title,
          subtitle: 'Offline module · license-gated',
          route: feature.route,
        ));
      }
    }

    final ayahs = await _quran.search(q, limit: 20);
    for (final a in ayahs) {
      hits.add(GlobalSearchHit(
        kind: 'Quran',
        title: '${a['name_en']} ${a['surah_number']}:${a['ayah_number']}',
        subtitle: '${a['text_uthmani']}',
        route: '/quran/read/${a['surah_number']}/${a['ayah_number']}',
      ));
    }

    final words = await _words.search(q, limit: 20);
    for (final w in words) {
      hits.add(GlobalSearchHit(
        kind: 'Word',
        title: '${w.textAr} · ${w.surah}:${w.ayah}:${w.wordNumber}',
        subtitle: [
          if (w.meaningUr.isNotEmpty) w.meaningUr,
          if (w.meaningEn.isNotEmpty) w.meaningEn,
          if (w.root.isNotEmpty) 'Root ${w.root}',
          if (w.grammarSummary.isNotEmpty) w.grammarSummary,
        ].join(' · '),
        route: '/quran/read/${w.surah}/${w.ayah}',
      ));
    }

    final userRows = await _userDatabase.searchUserData(q, limit: 20);
    for (final row in userRows) {
      hits.add(GlobalSearchHit(
        kind: 'Personal',
        title: '${row['title'] ?? 'Personal note'}',
        subtitle: '${row['body'] ?? ''}',
        route: _routeForUri('${row['target_uri'] ?? ''}'),
      ));
    }

    return hits;
  }

  String _routeForUri(String uri) {
    final quran = RegExp(r'^quran://(\d+)/(\d+)$').firstMatch(uri);
    if (quran != null) {
      return '/quran/read/${quran.group(1)}/${quran.group(2)}';
    }
    return '/library/notes';
  }
}
