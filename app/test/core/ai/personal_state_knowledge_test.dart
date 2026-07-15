import 'package:flutter_test/flutter_test.dart';
import 'package:islam307/core/ai/personal_state_knowledge.dart';
import 'package:islam307/core/ai/query_language.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('returns localized Urdu Namaz state from local preferences', () async {
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    SharedPreferences.setMockInitialValues({
      'namaz_${date}_Fajr': true,
      'namaz_${date}_Dhuhr': true,
    });
    final hits = await PersonalStateKnowledge().search(
      'نماز',
      language: QueryLanguage.urdu,
    );
    expect(hits, isNotEmpty);
    expect(hits.first.title, contains('نماز'));
    expect(hits.first.excerpt, contains('2/5'));
    expect(hits.first.excerpt, contains('فجر'));
  });

  test('returns English Tasbeeh state without network data', () async {
    SharedPreferences.setMockInitialValues({
      'tasbeeh_count': 12,
      'tasbeeh_target': 33,
      'tasbeeh_label': 'Morning counter',
    });
    final hits = await PersonalStateKnowledge().search(
      'tasbeeh',
      language: QueryLanguage.english,
    );
    expect(hits.first.excerpt, 'Count 12 · Target 33');
  });
}
