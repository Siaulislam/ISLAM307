import 'quran_database.dart';

class QuranRepository {
  QuranRepository({QuranDatabase? db}) : _db = db ?? QuranDatabase.instance;
  final QuranDatabase _db;

  Future<List<Map<String, dynamic>>> surahs() => _db.surahs();

  Future<List<Map<String, dynamic>>> rukus() => _db.rukus();

  Future<List<Map<String, dynamic>>> ayahsForSurah(int surah) => _db.ayahsForSurah(surah);

  Future<List<Map<String, dynamic>>> ayahsForRuku(int rukuNumber) => _db.ayahsForRuku(rukuNumber);

  Future<Map<String, dynamic>?> ayah(int surah, int ayah) => _db.ayah(surah, ayah);

  Future<List<Map<String, dynamic>>> search(String query, {int limit = 50}) => _db.search(query, limit: limit);

  Future<Map<String, dynamic>?> surah(int number) async {
    final all = await surahs();
    for (final s in all) {
      if (s['number'] == number) return s;
    }
    return null;
  }
}
