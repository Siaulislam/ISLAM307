import 'package:shared_preferences/shared_preferences.dart';

import '../user/user_library_store.dart';

class PersonalKnowledgeHit {
  const PersonalKnowledgeHit({
    required this.title,
    required this.excerpt,
    required this.reference,
  });

  final String title;
  final String excerpt;
  final String reference;
}

class PersonalStateKnowledge {
  Future<List<PersonalKnowledgeHit>> search(
    String query, {
    int limit = 10,
  }) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return const [];
    final hits = <PersonalKnowledgeHit>[];
    final prefs = await SharedPreferences.getInstance();
    final prayerNames = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    final asksPrayer = [
      'namaz',
      'prayer',
      'salah',
      'نماز',
      'صلاة',
    ].any(normalized.contains);
    if (asksPrayer) {
      final today = DateTime.now();
      final date =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final completed = prayerNames
          .where((name) => prefs.getBool('namaz_${date}_$name') == true)
          .toList();
      hits.add(PersonalKnowledgeHit(
        title: 'Today’s Namaz tracker',
        excerpt:
            '${completed.length}/5 completed${completed.isEmpty ? '' : ': ${completed.join(', ')}'}',
        reference: 'Personal app state · Namaz · $date',
      ));
    }
    final asksTasbeeh = [
      'tasbeeh',
      'tasbih',
      'تسبیح',
      'تسبيح',
      'counter',
    ].any(normalized.contains);
    if (asksTasbeeh) {
      final count = prefs.getInt('tasbeeh_count') ?? 0;
      final target = prefs.getInt('tasbeeh_target') ?? 33;
      final label = prefs.getString('tasbeeh_label') ?? 'My Tasbeeh';
      hits.add(PersonalKnowledgeHit(
        title: label,
        excerpt: 'Count $count · Target $target',
        reference: 'Personal app state · Tasbeeh',
      ));
    }

    for (final row in await UserLibraryStore.instance.knowledgeRecords()) {
      if (hits.length >= limit) break;
      final searchable = '${row['title']} ${row['body']} ${row['reference']}'
          .toLowerCase();
      if (!searchable.contains(normalized)) continue;
      hits.add(PersonalKnowledgeHit(
        title: row['title'] ?? 'Personal record',
        excerpt: row['body'] ?? '',
        reference: row['reference'] ?? 'Personal library',
      ));
    }
    return hits.take(limit).toList();
  }
}
