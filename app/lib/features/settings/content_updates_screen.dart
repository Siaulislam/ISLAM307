import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/datasets/dataset_license_registry.dart';
import '../../core/datasets/licensed_content_update_service.dart';
import '../../core/theme/islam307_theme.dart';

class ContentUpdatesScreen extends StatefulWidget {
  const ContentUpdatesScreen({super.key});

  @override
  State<ContentUpdatesScreen> createState() => _ContentUpdatesScreenState();
}

class _ContentUpdatesScreenState extends State<ContentUpdatesScreen> {
  List<DatasetLicenseRecord> _datasets = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final datasets = await DatasetLicenseRegistry.instance.datasets();
    if (!mounted) return;
    setState(() => _datasets = datasets);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Optional Content Updates',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _datasets.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'No background update checks occur. A network request may be added only for an approved, signed official endpoint and only after you tap Check.',
                style: TextStyle(color: Islam307Theme.textMuted, height: 1.5),
              ),
            );
          }
          final dataset = _datasets[index - 1];
          return Card(
            child: ListTile(
              title: Text(
                dataset.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(dataset.statusLabel),
              trailing: OutlinedButton(
                onPressed: () => _check(dataset.id),
                child: const Text('Check'),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _check(String datasetId) async {
    final result =
        await LicensedContentUpdateService.instance.checkForUpdate(datasetId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
  }
}
