import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/user_database.dart';
import '../../core/theme/islam307_theme.dart';

class UserLibraryScreen extends StatefulWidget {
  const UserLibraryScreen({super.key, required this.section});

  final String section;

  @override
  State<UserLibraryScreen> createState() => _UserLibraryScreenState();
}

class _UserLibraryScreenState extends State<UserLibraryScreen> {
  List<Map<String, dynamic>> _rows = const [];
  bool _loading = true;

  String get _title => switch (widget.section) {
        'bookmarks' => 'Bookmarks',
        'favorites' => 'Favorites',
        'history' => 'Reading History',
        'notes' => 'Notes',
        _ => 'Personal Library',
      };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = UserDatabase.instance;
    final rows = switch (widget.section) {
      'bookmarks' => await db.items('bookmark'),
      'favorites' => await db.items('favorite'),
      'history' => await db.history(),
      'notes' => await db.notes(),
      _ => <Map<String, dynamic>>[],
    };
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title, style: const TextStyle(fontWeight: FontWeight.w800)),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Islam307Theme.emerald),
            )
          : _rows.isEmpty
              ? Center(
                  child: Text(
                    'No ${_title.toLowerCase()} yet.',
                    style: const TextStyle(color: Islam307Theme.textMuted),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final row = _rows[index];
                    final uri = '${row['target_uri'] ?? ''}';
                    final title = '${row['title'] ?? uri}';
                    final body =
                        '${row['body'] ?? row['subtitle'] ?? row['content_type'] ?? ''}';
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          _icon,
                          color: Islam307Theme.emerald,
                        ),
                        title: Text(
                          title.isEmpty ? uri : title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: body.isEmpty ? null : Text(body),
                        onTap: () => _openUri(uri),
                      ),
                    );
                  },
                ),
    );
  }

  IconData get _icon => switch (widget.section) {
        'bookmarks' => Icons.bookmark_rounded,
        'favorites' => Icons.favorite_rounded,
        'history' => Icons.history_rounded,
        'notes' => Icons.note_rounded,
        _ => Icons.folder_rounded,
      };

  void _openUri(String uri) {
    final quran = RegExp(r'^quran://(\d+)/(\d+)$').firstMatch(uri);
    if (quran != null) {
      context.push('/quran/read/${quran.group(1)}/${quran.group(2)}');
      return;
    }
    final hadith = RegExp(r'^hadith://(\d+)/(\d+)$').firstMatch(uri);
    if (hadith != null) {
      context.push('/hadith/read/${hadith.group(1)}/${hadith.group(2)}');
    }
  }
}
