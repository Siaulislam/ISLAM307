import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LegacyTafsirCleanup {
  static Future<void>? _request;

  static Future<void> run() async {
    final existing = _request;
    if (existing != null) {
      await existing;
      return;
    }
    final request = _deleteLegacyFiles();
    _request = request;
    try {
      await request;
    } catch (_) {
      if (identical(_request, request)) {
        _request = null;
      }
      rethrow;
    }
  }

  static Future<void> _deleteLegacyFiles() async {
    final documents = await getApplicationDocumentsDirectory();
    for (final name in const [
      'tafsir.db',
      'tafsir.db-wal',
      'tafsir.db-shm',
      'tafsir.db-journal',
      'hadith.db',
      'hadith.db-wal',
      'hadith.db-shm',
      'hadith.db-journal',
      'narrators.db',
      'narrators.db-wal',
      'narrators.db-shm',
      'narrators.db-journal',
    ]) {
      final file = File(p.join(documents.path, name));
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}
