import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/database/database_registry.dart';
import '../../core/repositories/tafsir_repository.dart';
import '../../core/theme/islam307_theme.dart';

class TafsirScreen extends StatefulWidget {
  const TafsirScreen({super.key});

  @override
  State<TafsirScreen> createState() => _TafsirScreenState();
}

class _TafsirScreenState extends State<TafsirScreen> {
  final _repo = TafsirRepository(DatabaseRegistry.instance);
  List<Map<String, dynamic>> _sources = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final sources = await _repo.sources();
      if (!mounted) return;
      setState(() {
        _sources = sources;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Islam307Theme.white,
      appBar: AppBar(
        title: const Text('Tafsir', style: TextStyle(fontWeight: FontWeight.w800)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => context.pop()),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Islam307Theme.emerald))
          : _error != null
              ? Center(child: Text(_error!))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _sources.length,
                  itemBuilder: (_, i) {
                    final s = _sources[i];
                    return Card(
                      child: ListTile(
                        title: Text('${s['name_en']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text('${s['name_ar'] ?? s['author'] ?? ''} · ${s['language'] ?? 'en'} · Offline'),
                        onTap: () => context.push('/tafsir/${s['slug']}/1/1'),
                      ),
                    );
                  },
                ),
    );
  }
}
