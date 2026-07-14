import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/datasets/dataset_license_registry.dart';
import '../../core/theme/islam307_theme.dart';

class FeatureLibraryScreen extends StatefulWidget {
  const FeatureLibraryScreen({super.key});

  @override
  State<FeatureLibraryScreen> createState() => _FeatureLibraryScreenState();
}

class _FeatureLibraryScreenState extends State<FeatureLibraryScreen> {
  List<LicensedFeatureDefinition> _features = const [];
  Map<String, DatasetLicenseRecord> _datasets = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final registry = DatasetLicenseRegistry.instance;
    final features = await registry.features();
    final datasets = {
      for (final dataset in await registry.datasets()) dataset.id: dataset,
    };
    if (!mounted) return;
    setState(() {
      _features = features;
      _datasets = datasets;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Islamic Library & Tools',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        ),
      ),
      body: _features.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: Islam307Theme.emerald),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: _features.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final feature = _features[index];
                final dataset = _datasets[feature.datasetId];
                final available = dataset?.mayBundle == true;
                return Card(
                  child: ListTile(
                    leading: Icon(
                      available
                          ? Icons.check_circle_rounded
                          : Icons.pending_actions_rounded,
                      color: available
                          ? Islam307Theme.emerald
                          : Islam307Theme.gold,
                    ),
                    title: Text(
                      feature.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      dataset?.statusLabel ?? 'License record unavailable',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(feature.route),
                  ),
                );
              },
            ),
    );
  }
}
