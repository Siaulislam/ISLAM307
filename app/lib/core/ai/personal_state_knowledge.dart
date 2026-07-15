import 'package:shared_preferences/shared_preferences.dart';

import '../user/user_library_store.dart';
import 'query_language.dart';

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
    required QueryLanguage language,
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
      final completedLabels =
          completed.map((name) => _prayerLabel(name, language)).toList();
      hits.add(PersonalKnowledgeHit(
        title: switch (language) {
          QueryLanguage.urdu => 'آج کی نماز',
          QueryLanguage.arabic => 'صلوات اليوم',
          QueryLanguage.english => 'Today’s Namaz tracker',
        },
        excerpt: switch (language) {
          QueryLanguage.urdu =>
            '${completed.length}/5 مکمل${completed.isEmpty ? '' : ': ${completedLabels.join(', ')}'}',
          QueryLanguage.arabic =>
            '${completed.length}/5 مكتملة${completed.isEmpty ? '' : ': ${completedLabels.join(', ')}'}',
          QueryLanguage.english =>
            '${completed.length}/5 completed${completed.isEmpty ? '' : ': ${completed.join(', ')}'}',
        },
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
        excerpt: switch (language) {
          QueryLanguage.urdu => 'تعداد $count · ہدف $target',
          QueryLanguage.arabic => 'العدد $count · الهدف $target',
          QueryLanguage.english => 'Count $count · Target $target',
        },
        reference: 'Personal app state · Tasbeeh',
      ));
    }

    try {
      for (final row in await UserLibraryStore.instance.knowledgeRecords()) {
        if (hits.length >= limit) break;
        final searchable =
            '${row['title']} ${row['body']} ${row['reference']}'.toLowerCase();
        if (!searchable.contains(normalized)) continue;
        hits.add(PersonalKnowledgeHit(
          title: row['title'] ?? 'Personal record',
          excerpt: row['body'] ?? '',
          reference: row['reference'] ?? 'Personal library',
        ));
      }
    } catch (_) {
      // Personal file may not exist yet; preference-backed state still works.
    }
    return hits.take(limit).toList();
  }

  String _prayerLabel(String name, QueryLanguage language) {
    const urdu = {
      'Fajr': 'فجر',
      'Dhuhr': 'ظہر',
      'Asr': 'عصر',
      'Maghrib': 'مغرب',
      'Isha': 'عشاء',
    };
    const arabic = {
      'Fajr': 'الفجر',
      'Dhuhr': 'الظهر',
      'Asr': 'العصر',
      'Maghrib': 'المغرب',
      'Isha': 'العشاء',
    };
    return switch (language) {
      QueryLanguage.urdu => urdu[name] ?? name,
      QueryLanguage.arabic => arabic[name] ?? name,
      QueryLanguage.english => name,
    };
  }
}
