import '../database/database_registry.dart';
import 'hadith_repository.dart';
import 'quran_repository.dart';
import 'tafsir_repository.dart';

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
    HadithRepository? hadith,
    TafsirRepository? tafsir,
  })  : _quran = quran ?? QuranRepository(),
        _hadith = hadith ?? HadithRepository(DatabaseRegistry.instance),
        _tafsir = tafsir ?? TafsirRepository(DatabaseRegistry.instance);

  final QuranRepository _quran;
  final HadithRepository _hadith;
  final TafsirRepository _tafsir;

  Future<List<GlobalSearchHit>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final hits = <GlobalSearchHit>[];

    final ayahs = await _quran.search(q, limit: 20);
    for (final a in ayahs) {
      hits.add(GlobalSearchHit(
        kind: 'Quran',
        title: '${a['name_en']} ${a['surah_number']}:${a['ayah_number']}',
        subtitle: '${a['text_uthmani']}',
        route: '/quran/read/${a['surah_number']}/${a['ayah_number']}',
      ));
    }

    final hadiths = await _hadith.search(q, limit: 20);
    for (final h in hadiths) {
      hits.add(GlobalSearchHit(
        kind: 'Hadith',
        title: '${h['book_name']} · ${h['hadith_number']}',
        subtitle: '${h['text_en'] ?? h['text_ar'] ?? ''}',
        route: '/hadith/read/${h['book_id']}/${h['hadith_number']}',
      ));
    }

    final tafsirs = await _tafsir.search(q, limit: 10);
    for (final t in tafsirs) {
      hits.add(GlobalSearchHit(
        kind: 'Tafsir',
        title: '${t['source_name']} · ${t['surah_number']}:${t['ayah_number']}',
        subtitle: '${t['text']}',
        route: '/tafsir/${t['source_slug']}/${t['surah_number']}/${t['ayah_number']}',
      ));
    }

    return hits;
  }
}
