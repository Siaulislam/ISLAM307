import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/user_database.dart';

/// Offline per-user data backed by writable SQLite, never religious content.
class UserLibraryStore {
  UserLibraryStore._();
  static final UserLibraryStore instance = UserLibraryStore._();

  static const _userIdKey = 'islam307_user_id';
  String? _userId;
  Future<void>? _migration;

  Future<String> userId() async {
    if (_userId != null) return _userId!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_userIdKey);
    if (id == null || id.isEmpty) {
      id = 'user_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString(_userIdKey, id);
    }
    return _userId = id;
  }

  String _ayahUri(int surah, int ayah) => 'quran://$surah/$ayah';

  Future<List<String>> bookmarks() async {
    final rows = await UserDatabase.instance.items('bookmark');
    return rows
        .map((row) => '${row['target_uri']}')
        .where((uri) => uri.startsWith('quran://'))
        .map((uri) => uri.replaceFirst('quran://', '').replaceAll('/', ':'))
        .toList();
  }

  Future<bool> isBookmarked(int surah, int ayah) {
    return UserDatabase.instance.hasItem('bookmark', _ayahUri(surah, ayah));
  }

  Future<void> migrateLegacyJson() {
    return _migration ??= _migrateLegacyJson();
  }

  Future<void> _migrateLegacyJson() async {
    final id = await userId();
    final documents = await getApplicationDocumentsDirectory();
    final file = File(p.join(documents.path, 'users', id, 'library.json'));
    if (!await file.exists()) return;
    try {
      final data =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      for (final raw in (data['bookmarks'] as List?) ?? const []) {
        final parts = '$raw'.split(':');
        if (parts.length != 2) continue;
        final surah = int.tryParse(parts[0]);
        final ayah = int.tryParse(parts[1]);
        if (surah == null || ayah == null) continue;
        if (!await isBookmarked(surah, ayah)) {
          await toggleBookmark(surah, ayah);
        }
      }
      for (final entry
          in Map<String, dynamic>.from(data['notes'] as Map? ?? const {})
              .entries) {
        final parts = entry.key.split(':');
        if (parts.length != 2) continue;
        final surah = int.tryParse(parts[0]);
        final ayah = int.tryParse(parts[1]);
        if (surah != null && ayah != null) {
          await setNote(surah, ayah, '${entry.value}');
        }
      }
      for (final entry
          in Map<String, dynamic>.from(
            data['highlights'] as Map? ?? const {},
          ).entries) {
        final parts = entry.key.split(':');
        if (parts.length != 2) continue;
        final surah = int.tryParse(parts[0]);
        final ayah = int.tryParse(parts[1]);
        if (surah != null && ayah != null) {
          final target = _ayahUri(surah, ayah);
          final color = '${entry.value}';
          if (await UserDatabase.instance.highlight(target) != color) {
            await UserDatabase.instance.toggleHighlight(
              target,
              color: color,
            );
          }
        }
      }
      await file.delete();
    } catch (_) {
      // Keep the original user file untouched when migration cannot complete.
    }
  }

  Future<bool> toggleBookmark(int surah, int ayah) {
    return UserDatabase.instance.toggleItem(
      'bookmark',
      _ayahUri(surah, ayah),
      title: 'Quran $surah:$ayah',
      metadata: {'surah': surah, 'ayah': ayah},
    );
  }

  Future<bool> toggleFavorite(
    String targetUri, {
    String? title,
    String? subtitle,
  }) {
    return UserDatabase.instance.toggleItem(
      'favorite',
      targetUri,
      title: title,
      subtitle: subtitle,
    );
  }

  Future<bool> isFavorite(String targetUri) {
    return UserDatabase.instance.hasItem('favorite', targetUri);
  }

  Future<String?> highlight(int surah, int ayah) {
    return UserDatabase.instance.highlight(_ayahUri(surah, ayah));
  }

  Future<String?> toggleHighlight(
    int surah,
    int ayah, {
    String color = 'gold',
  }) {
    return UserDatabase.instance.toggleHighlight(
      _ayahUri(surah, ayah),
      color: color,
    );
  }

  Future<String?> note(int surah, int ayah) {
    return UserDatabase.instance.note(_ayahUri(surah, ayah));
  }

  Future<void> setNote(int surah, int ayah, String text) {
    return UserDatabase.instance.setNote(_ayahUri(surah, ayah), text);
  }

  Future<void> recordQuranHistory(int surah, int ayah, {String? title}) {
    return UserDatabase.instance.recordHistory(
      targetUri: _ayahUri(surah, ayah),
      contentType: 'quran',
      title: title ?? 'Quran $surah:$ayah',
      position: {'surah': surah, 'ayah': ayah},
    );
  }

  Future<String> exportPath() async {
    final documents = await getApplicationDocumentsDirectory();
    return p.join(documents.path, 'user.db');
  }
}
