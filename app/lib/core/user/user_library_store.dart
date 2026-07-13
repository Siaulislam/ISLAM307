import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Per-user personal library file (bookmarks, highlights, notes).
/// One JSON file per user under app documents — never AI content.
class UserLibraryStore {
  UserLibraryStore._();
  static final UserLibraryStore instance = UserLibraryStore._();

  static const _userIdKey = 'islam307_user_id';
  String? _userId;
  Map<String, dynamic>? _cache;

  Future<String> userId() async {
    if (_userId != null) return _userId!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_userIdKey);
    if (id == null || id.isEmpty) {
      id = 'user_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString(_userIdKey, id);
    }
    _userId = id;
    return id;
  }

  Future<File> _file() async {
    final id = await userId();
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(dir.path, 'users', id));
    if (!await folder.exists()) await folder.create(recursive: true);
    return File(p.join(folder.path, 'library.json'));
  }

  Future<Map<String, dynamic>> _load() async {
    if (_cache != null) return _cache!;
    final file = await _file();
    if (!await file.exists()) {
      _cache = {
        'user_id': await userId(),
        'bookmarks': <String>[],
        'highlights': <String, dynamic>{},
        'notes': <String, dynamic>{},
        'updated_at': DateTime.now().toIso8601String(),
      };
      await _persist();
      return _cache!;
    }
    _cache = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    _cache!.putIfAbsent('bookmarks', () => <dynamic>[]);
    _cache!.putIfAbsent('highlights', () => <String, dynamic>{});
    _cache!.putIfAbsent('notes', () => <String, dynamic>{});
    return _cache!;
  }

  Future<void> _persist() async {
    final data = await _load();
    data['updated_at'] = DateTime.now().toIso8601String();
    data['user_id'] = await userId();
    final file = await _file();
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  }

  String _ayahKey(int surah, int ayah) => '$surah:$ayah';

  Future<List<String>> bookmarks() async {
    final data = await _load();
    return (data['bookmarks'] as List).map((e) => '$e').toList();
  }

  Future<bool> isBookmarked(int surah, int ayah) async {
    final key = _ayahKey(surah, ayah);
    return (await bookmarks()).contains(key);
  }

  Future<bool> toggleBookmark(int surah, int ayah) async {
    final data = await _load();
    final key = _ayahKey(surah, ayah);
    final list = (data['bookmarks'] as List).map((e) => '$e').toList();
    final nowOn = !list.contains(key);
    if (nowOn) {
      list.add(key);
    } else {
      list.remove(key);
    }
    data['bookmarks'] = list;
    await _persist();
    return nowOn;
  }

  Future<String?> highlight(int surah, int ayah) async {
    final data = await _load();
    final map = Map<String, dynamic>.from(data['highlights'] as Map);
    return map[_ayahKey(surah, ayah)] as String?;
  }

  Future<String?> toggleHighlight(int surah, int ayah, {String color = 'gold'}) async {
    final data = await _load();
    final map = Map<String, dynamic>.from(data['highlights'] as Map);
    final key = _ayahKey(surah, ayah);
    if (map[key] == color) {
      map.remove(key);
    } else {
      map[key] = color;
    }
    data['highlights'] = map;
    await _persist();
    return map[key] as String?;
  }

  Future<String?> note(int surah, int ayah) async {
    final data = await _load();
    final map = Map<String, dynamic>.from(data['notes'] as Map);
    return map[_ayahKey(surah, ayah)] as String?;
  }

  Future<void> setNote(int surah, int ayah, String text) async {
    final data = await _load();
    final map = Map<String, dynamic>.from(data['notes'] as Map);
    final key = _ayahKey(surah, ayah);
    final clean = text.trim();
    if (clean.isEmpty) {
      map.remove(key);
    } else {
      map[key] = clean;
    }
    data['notes'] = map;
    await _persist();
  }

  Future<String> exportPath() async => (await _file()).path;
}
