import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LegacyTafsirCleanup {
  static Future<void>? _request;

  static Future<void> run() {
    return _request ??= _deleteLegacyFiles();
  }

  static Future<void> _deleteLegacyFiles() async {
    final documents = await getApplicationDocumentsDirectory();
    for (final name in const [
      'tafsir.db',
      'tafsir.db-wal',
      'tafsir.db-shm',
    ]) {
      final file = File(p.join(documents.path, name));
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}
