import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/database/database_registry.dart';
import '../../core/repositories/tafsir_repository.dart';
import '../../core/theme/islam307_theme.dart';

class TafsirReaderScreen extends StatefulWidget {
  const TafsirReaderScreen({
    super.key,
    required this.sourceSlug,
    required this.surah,
    required this.ayah,
  });

  final String sourceSlug;
  final int surah;
  final int ayah;

  @override
  State<TafsirReaderScreen> createState() => _TafsirReaderScreenState();
}

class _TafsirReaderScreenState extends State<TafsirReaderScreen> {
  final _repo = TafsirRepository(DatabaseRegistry.instance);
  Map<String, dynamic>? _entry;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant TafsirReaderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.surah != widget.surah || oldWidget.ayah != widget.ayah || oldWidget.sourceSlug != widget.sourceSlug) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entry = await _repo.entry(widget.sourceSlug, widget.surah, widget.ayah);
    if (!mounted) return;
    setState(() {
      _entry = entry;
      _loading = false;
    });
  }

  void _go(int surah, int ayah) => context.go('/tafsir/${widget.sourceSlug}/$surah/$ayah');

  @override
  Widget build(BuildContext context) {
    final unavailable = _entry == null || _entry!['unavailable'] == true;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.sourceSlug} · ${widget.surah}:${widget.ayah}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => context.pop()),
        actions: [
          IconButton(
            onPressed: widget.ayah > 1 ? () => _go(widget.surah, widget.ayah - 1) : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          IconButton(
            onPressed: () => _go(widget.surah, widget.ayah + 1),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Islam307Theme.emerald))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (unavailable) ...[
                  Text(_entry?['message'] as String? ?? TafsirRepository.unavailableMessage,
                      style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.orange)),
                  const SizedBox(height: 8),
                  Text('${_entry?['notes'] ?? ''}', style: const TextStyle(color: Islam307Theme.textMuted)),
                ] else ...[
                  Text('${_entry!['source_name']}', style: const TextStyle(fontWeight: FontWeight.w800, color: Islam307Theme.emeraldDeep)),
                  const SizedBox(height: 8),
                  Text('Surah ${_entry!['surah_number']} · Ayah ${_entry!['ayah_number']}',
                      style: const TextStyle(color: Islam307Theme.textMuted, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  Text('${_entry!['text']}', style: const TextStyle(height: 1.7, fontSize: 15)),
                ],
              ],
            ),
    );
  }
}
