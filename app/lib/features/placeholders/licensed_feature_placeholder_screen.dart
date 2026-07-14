import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/datasets/dataset_license_registry.dart';
import '../../core/theme/islam307_theme.dart';

class LicensedFeaturePlaceholderScreen extends StatefulWidget {
  const LicensedFeaturePlaceholderScreen({
    super.key,
    required this.featureId,
  });

  final String featureId;

  @override
  State<LicensedFeaturePlaceholderScreen> createState() =>
      _LicensedFeaturePlaceholderScreenState();
}

class _LicensedFeaturePlaceholderScreenState
    extends State<LicensedFeaturePlaceholderScreen> {
  LicensedFeatureDefinition? _feature;
  DatasetLicenseRecord? _dataset;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final registry = DatasetLicenseRegistry.instance;
    final feature = await registry.feature(widget.featureId);
    final dataset =
        feature == null ? null : await registry.dataset(feature.datasetId);
    if (!mounted) return;
    setState(() {
      _feature = feature;
      _dataset = dataset;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = _feature?.title ?? widget.featureId;
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Islam307Theme.emerald),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  size: 52,
                  color: Islam307Theme.gold,
                ),
                const SizedBox(height: 16),
                Text(
                  _dataset?.statusLabel ?? 'License record unavailable',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Islam307Theme.emeraldDeep,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'The feature UI and offline architecture are ready, but religious content will not be imported until official evidence explicitly permits offline and commercial redistribution.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Islam307Theme.textMuted,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 20),
                _row('Dataset', _dataset?.title ?? '—'),
                _row('Official source', _dataset?.originalSource ?? '—'),
                _row('License', _dataset?.license ?? '—'),
                _row('Copyright owner', _dataset?.copyrightOwner ?? '—'),
                _row('Contact', _dataset?.contact ?? '—'),
                _row('Version', _dataset?.version ?? '—'),
                _row('Checksum', _dataset?.checksumSha256 ?? 'Not installed'),
                _row(
                  'Offline redistribution',
                  _dataset?.offlineRedistribution == true
                      ? 'Allowed'
                      : 'Not approved',
                ),
                _row(
                  'Commercial distribution',
                  _dataset?.commercialDistribution == true
                      ? 'Allowed'
                      : 'Not approved',
                ),
                _row('License evidence', _dataset?.evidence ?? '—'),
                const SizedBox(height: 16),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'TODO: obtain written permission or replace this dataset with an official source whose license explicitly allows permanent offline commercial redistribution.',
                      style: TextStyle(
                        color: Color(0xFF92400E),
                        height: 1.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Islam307Theme.emerald,
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(height: 1.4)),
        ],
      ),
    );
  }
}
