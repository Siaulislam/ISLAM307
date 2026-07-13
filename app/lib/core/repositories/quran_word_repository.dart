import '../database/quran_database.dart';
import '../models/quran_word.dart';

class QuranWordRepository {
  QuranWordRepository({QuranDatabase? db}) : _db = db ?? QuranDatabase.instance;
  final QuranDatabase _db;

  Future<bool> isAvailable() => _db.hasWordKnowledge();

  Future<List<QuranWord>> wordsForAyah(int surah, int ayah) async {
    final rows = await _db.wordsForAyah(surah, ayah);
    return rows.map(QuranWord.fromMap).toList();
  }

  Future<QuranWord?> wordById(int id) async {
    final row = await _db.wordById(id);
    if (row == null) return null;
    final parts = await _db.wordParts(id);
    return QuranWord.fromMap(row, parts: parts.map(QuranWordPart.fromMap).toList());
  }

  Future<QuranWord?> wordAt(int surah, int ayah, int wordNumber) async {
    final row = await _db.wordAt(surah, ayah, wordNumber);
    if (row == null) return null;
    final parts = await _db.wordParts(row['id'] as int);
    return QuranWord.fromMap(row, parts: parts.map(QuranWordPart.fromMap).toList());
  }

  Future<List<QuranWord>> relatedByRoot(String root, {int limit = 12, int? excludeId}) async {
    if (root.trim().isEmpty) return [];
    final rows = await _db.wordsByRoot(root, limit: limit, excludeId: excludeId);
    return rows.map(QuranWord.fromMap).toList();
  }

  Future<List<QuranWord>> search(String query, {int limit = 40}) async {
    final rows = await _db.searchWords(query, limit: limit);
    return rows.map(QuranWord.fromMap).toList();
  }
}
