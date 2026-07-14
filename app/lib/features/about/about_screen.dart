import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/branding/islam307_logo.dart';
import '../../core/theme/islam307_theme.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw = await rootBundle.loadString('assets/modules/data_sources.json');
    if (!mounted) return;
    setState(() => _data = jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Widget build(BuildContext context) {
    final app = _data?['app'] as Map<String, dynamic>?;
    final policy = (app?['policy'] as List?)?.cast<String>() ?? const <String>[];
    return Scaffold(
      appBar: AppBar(
        title: const Text('About ISLAM 307', style: TextStyle(fontWeight: FontWeight.w800)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => context.pop()),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const Islam307BrandBar(showTagline: true, alignment: MainAxisAlignment.center),
          const SizedBox(height: 16),
          Text(
            app?['tagline'] as String? ?? '100% FREE · Sadaqah Jariyah · Offline-first',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700, color: Islam307Theme.emeraldDeep),
          ),
          const SizedBox(height: 20),
          ...policy.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle_rounded, color: Islam307Theme.emerald, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(line, style: const TextStyle(height: 1.45))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.balance_rounded, color: Islam307Theme.gold),
            title: const Text('Data Sources & Licenses', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: const Text('Tanzil, Quranic Arabic Corpus, and other acknowledgements'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/about/licenses'),
          ),
          const Divider(),
          const Text(
            'AI searches authenticated local Quran and Hadith databases. Verse-specific Tafseer is retrieved at runtime from the authorized Quran Foundation Content API and is not bundled locally. '
            'Narrator biographies are never invented — only approved classical Sunni sources with license/permission. '
            'If nothing matches: “No authentic reference found.” '
            'If a narrator profile is not in narrators.db yet: “This narrator profile has not been imported into the local database yet.”',
            style: TextStyle(color: Islam307Theme.textMuted, height: 1.5, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class DataSourcesLicensesScreen extends StatefulWidget {
  const DataSourcesLicensesScreen({super.key});

  @override
  State<DataSourcesLicensesScreen> createState() => _DataSourcesLicensesScreenState();
}

class _DataSourcesLicensesScreenState extends State<DataSourcesLicensesScreen> {
  List<Map<String, dynamic>> _sources = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw = await rootBundle.loadString('assets/modules/data_sources.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final list = (data['sources'] as List).cast<Map<String, dynamic>>();
    if (!mounted) return;
    setState(() => _sources = list);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Sources & Licenses', style: TextStyle(fontWeight: FontWeight.w800)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => context.pop()),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        itemCount: _sources.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          if (i == 0) {
            return const Text(
              'Settings → About → Data Sources. Required acknowledgements for each offline dataset used by ISLAM 307.',
              style: TextStyle(color: Islam307Theme.textMuted, height: 1.5),
            );
          }
          final s = _sources[i - 1];
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Islam307Theme.cardBorder),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${s['title']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Islam307Theme.emeraldDeep)),
                const SizedBox(height: 8),
                Text('Purpose: ${s['purpose']}', style: const TextStyle(height: 1.45)),
                const SizedBox(height: 6),
                Text('License: ${s['license']}', style: const TextStyle(height: 1.45, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('${s['attribution']}', style: const TextStyle(height: 1.45, color: Islam307Theme.textMuted)),
                if ((s['notes'] as String?)?.isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  Text('Note: ${s['notes']}', style: const TextStyle(height: 1.45, fontSize: 13)),
                ],
                const SizedBox(height: 8),
                Text('${s['url']}', style: const TextStyle(color: Islam307Theme.emerald, fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
          );
        },
      ),
    );
  }
}
